import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_appflowy.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/diary_camera_capture_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/diary_video_gallery_service.dart';
import 'package:node_diary/ui/diaries/models/image_insertion.dart';
import 'package:node_diary/ui/diaries/models/media_insertion.dart';

typedef DiaryMediaPicker = Future<List<PlatformFile>?> Function(DiaryMediaKind);
typedef DiaryMediaImporter =
    Future<DiaryFileAttachment> Function(PlatformFile, DiaryMediaKind);

enum DiaryMediaImportOutcome {
  inserted,
  cancelled,
  failed,
  busy,
  unsupported,

  /// 拍照 / 录像：没有相机权限（用户拒绝，或之前选了“不再询问”）。
  cameraPermissionDenied,

  /// 拍照 / 录像：设备没有相机或可用的相机应用。
  cameraUnavailable,
}

/// 编排系统选文件（或系统相机拍摄）→ 私有目录复制 → 正文插入；不构建 UI，
/// 不保存数据库。页面退出或正文编辑器状态更换会使当前操作失效，并清理尚未
/// 提交的文件。
///
/// AppFlowy 迁移说明：
/// - 插入经已迁移的 [insertDiaryImages] / [insertDiaryMediaBlocks]（以
///   EditorState 为入口），媒体块为独立块节点（图片 / 视频 / 附件）。
/// - 原来在选择器打开期间监听 `document.changes`、用 Delta 把捕获的选区锚点
///   变换到最新位置；AppFlowy 没有公开的选区变换 API，改为在提交那一刻直接
///   取编辑器的当前选区——永远不会是过时偏移，也符合“插在光标处”的预期。
/// - 失败回滚：原来整体换掉 `controller.document`；现在用插入前的块文档
///   快照删掉全部顶层节点后重建，再恢复选区。
class DiaryMediaImportController extends ChangeNotifier {
  DiaryMediaImportController({
    DiaryMediaPicker? picker,
    DiaryMediaPicker? capturer,
    DiaryMediaImporter? importer,
  }) : _picker = picker ?? _pickFiles,
       _capturer = capturer ?? DiaryCameraCaptureService.capture,
       _importer = importer ?? _importFile;

  final DiaryMediaPicker _picker;

  /// 拍照 / 录像的文件来源（默认交给系统相机，见 [captureAndInsert]）。
  final DiaryMediaPicker _capturer;
  final DiaryMediaImporter _importer;
  DiaryMediaKind? _activeKind;
  bool _disposed = false;
  bool _copying = false;
  int _generation = 0;

  bool get isBusy => _activeKind != null;
  bool get isCopying => _copying;
  DiaryMediaKind? get activeKind => _activeKind;

  void cancel() => _generation++;

  /// [picker] 替换本次的文件来源（如“这天拍的照片”已在页面里选好），
  /// 复制、插入、取消与失败回滚仍走同一条链路。
  Future<DiaryMediaImportOutcome> pickAndInsert({
    required EditorState editorState,
    required DiaryMediaKind kind,
    required bool Function() isCurrent,
    DiaryMediaPicker? picker,
  }) async {
    if (_disposed) return DiaryMediaImportOutcome.cancelled;
    if (isBusy) return DiaryMediaImportOutcome.busy;
    if (kIsWeb) return DiaryMediaImportOutcome.unsupported;
    final generation = ++_generation;
    final document = editorState.document;
    bool canCommit() =>
        !_disposed &&
        generation == _generation &&
        isCurrent() &&
        identical(editorState.document, document);

    final imported = <DiaryFileAttachment>[];
    List<PlatformFile>? files;
    String? previousContentJson;
    Selection? previousSelection;
    _activeKind = kind;
    notifyListeners();
    try {
      files = await (picker ?? _picker)(kind);
      if (!canCommit() || files == null || files.isEmpty) {
        return DiaryMediaImportOutcome.cancelled;
      }
      _copying = true;
      notifyListeners();
      for (final file in files) {
        imported.add(await _importer(file, kind));
        if (!canCommit()) return DiaryMediaImportOutcome.cancelled;
      }
      if (!canCommit()) return DiaryMediaImportOutcome.cancelled;
      previousContentJson = diaryDocumentToStoredJson(document);
      previousSelection = editorState.selection;
      // 提交时取当前选区：选择器与复制期间用户可能移动过光标，直接用最新的，
      // 不会拿到已过时的锚点。
      final selection = editorState.selection;
      if (kind == DiaryMediaKind.image) {
        await insertDiaryImages(
          editorState: editorState,
          imagePaths: imported.map((file) => file.path).toList(),
          selection: selection,
        );
      } else {
        await insertDiaryMediaBlocks(
          editorState: editorState,
          selection:
              selection ??
              Selection.collapsed(
                Position(path: [document.root.children.length], offset: 0),
              ),
          embeds: [
            for (final file in imported)
              if (kind == DiaryMediaKind.video)
                Node(
                  type: kDiaryBlockVideo,
                  attributes: <String, dynamic>{kDiaryBlockUrlKey: file.path},
                )
              else
                Node(
                  type: kDiaryBlockAttachment,
                  attributes: Map<String, dynamic>.from(
                    jsonDecode(file.encode()) as Map,
                  ),
                ),
          ],
        );
      }
      imported.clear(); // 正文取得文件所有权，取消/失败清理不得删除已提交文件。
      return DiaryMediaImportOutcome.inserted;
    } catch (error, stackTrace) {
      final current = canCommit();
      if (previousContentJson != null && current) {
        await _restoreDocument(
          editorState,
          previousContentJson,
          previousSelection,
        );
      }
      debugPrint('Diary media import failed: $error\n$stackTrace');
      if (!current) return DiaryMediaImportOutcome.cancelled;
      if (error is PlatformException) {
        if (error.code == 'camera_permission_denied') {
          return DiaryMediaImportOutcome.cameraPermissionDenied;
        }
        if (error.code == 'camera_unavailable') {
          return DiaryMediaImportOutcome.cameraUnavailable;
        }
      }
      return DiaryMediaImportOutcome.failed;
    } finally {
      for (final file in imported) {
        try {
          await DiaryMediaStorageService.deleteManagedDiaryFile(file.path);
        } catch (error) {
          debugPrint('Uncommitted diary file cleanup failed: $error');
        }
      }
      // 无论成功与否，选择器在缓存里的中转副本都已无用（视频可达数百 MB）。
      for (final file in files ?? const <PlatformFile>[]) {
        await DiaryMediaStorageService.discardPickerCopy(file.path);
      }
      if (!_disposed) {
        _copying = false;
        _activeKind = null;
        notifyListeners();
      }
    }
  }

  /// 用 [contentJson] 快照恢复文档：删掉全部顶层节点后按快照重建，再恢复
  /// [selection]。插入失败后的兜底路径，节点 id 会变化，但内容与选区一致。
  Future<void> _restoreDocument(
    EditorState editorState,
    String contentJson,
    Selection? selection,
  ) async {
    final document = editorState.document;
    final restored = diaryDocumentFromStoredJson(contentJson);
    final transaction = editorState.transaction;
    for (final node in document.root.children.toList()) {
      transaction.deleteNode(node);
    }
    for (final child in restored.root.children) {
      transaction.insertNode([document.root.children.length], child);
    }
    transaction.afterSelection = selection;
    await editorState.apply(transaction);
  }

  /// 用系统相机拍一张照片（[kind] 为图片）或一段视频（[kind] 为视频）插入
  /// 光标处：与选文件同一条链路（复制到私有目录、失败回滚、清理暂存），
  /// 只是文件来源换成相机。附件没有拍摄入口；不支持拍摄的平台返回
  /// unsupported（入口本应已隐藏）。
  Future<DiaryMediaImportOutcome> captureAndInsert({
    required EditorState editorState,
    required DiaryMediaKind kind,
    required bool Function() isCurrent,
  }) async {
    if (kind == DiaryMediaKind.attachment ||
        !AppPlatform.supportsCameraCapture) {
      return DiaryMediaImportOutcome.unsupported;
    }
    return pickAndInsert(
      editorState: editorState,
      kind: kind,
      isCurrent: isCurrent,
      picker: _capturer,
    );
  }

  static Future<List<PlatformFile>?> _pickFiles(DiaryMediaKind kind) async {
    // file_picker 的 Android 图片走相册，但视频走 SAF 文件管理器。
    // 视频改用同类相册入口；其他平台继续复用插件已有的系统媒体选择行为。
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        kind == DiaryMediaKind.video) {
      return DiaryVideoGalleryService.pickAndroidVideos();
    }
    final result = await FilePicker.platform.pickFiles(
      type: switch (kind) {
        DiaryMediaKind.image => FileType.image,
        DiaryMediaKind.video => FileType.video,
        DiaryMediaKind.attachment => FileType.any,
      },
      allowMultiple: true,
      withData: false,
      withReadStream: true,
    );
    return result?.files;
  }

  static Future<DiaryFileAttachment> _importFile(
    PlatformFile file,
    DiaryMediaKind kind,
  ) => DiaryMediaStorageService.importFile(
    kind: kind,
    fileName: file.name,
    sourcePath: file.path,
    readStream: file.readStream,
    bytes: file.bytes,
  );

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
