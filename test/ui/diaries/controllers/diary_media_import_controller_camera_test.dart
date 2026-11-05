import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_appflowy.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_media_import_controller.dart';
import 'package:path/path.dart' as p;

/// 系统相机拍摄插入：与选文件同一条链路（复制进日记私有目录、失败回滚、
/// 暂存清理），只是文件来源换成相机通道。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const cameraChannel = MethodChannel('com.jotsy.diary/camera_capture');
  late Directory root;
  late EditorState editorState;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_camera_import_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    editorState = EditorState(document: Document.blank());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cameraChannel, null);
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  /// 模拟系统相机：把拍到的文件写进 `cache/diary_camera/<批次>/`（与原生
  /// 一致；path_provider 的 mock 让临时目录与文档目录都为 root），返回它。
  Future<File> stageCapture(String name) async {
    final file = File(p.join(root.path, 'diary_camera', 'batch', name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([7, 7, 7]);
    return file;
  }

  List<Node> mediaNodes(String type) {
    final found = <Node>[];
    void walk(Node node) {
      if (node.type == type) found.add(node);
      for (final child in node.children) {
        walk(child);
      }
    }

    for (final child in editorState.document.root.children) {
      walk(child);
    }
    return found;
  }

  group('captureAndInsert (camera)', () {
    for (final (kind, type, name) in [
      (DiaryMediaKind.image, 'image', 'IMG_20261103_101500.jpg'),
      (DiaryMediaKind.video, 'video', 'VID_20261103_101500.mp4'),
    ]) {
      test('a captured ${kind.name} is copied into the diary, inserted and '
          'its camera copy discarded', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final captured = await stageCapture(name);
        MethodCall? request;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(cameraChannel, (call) async {
              request = call;
              return [
                {'name': name, 'path': captured.path, 'size': 3},
              ];
            });
        var pickerOpened = false;
        final importer = DiaryMediaImportController(
          picker: (_) async {
            pickerOpened = true;
            return null;
          },
        );
        addTearDown(importer.dispose);

        expect(
          await importer.captureAndInsert(
            editorState: editorState,
            kind: kind,
            isCurrent: () => true,
          ),
          DiaryMediaImportOutcome.inserted,
        );
        expect(pickerOpened, isFalse);
        expect(request?.method, 'capture');
        expect(request?.arguments, {'kind': type});
        final nodes = mediaNodes(type);
        expect(nodes, hasLength(1));
        final stored = nodes.single.attributes['url'] as String;
        expect(p.basename(stored), name);
        expect(await File(stored).readAsBytes(), [7, 7, 7]);
        // 暂存在相机目录里的那一份用完即删，批次目录一起移除，根目录保留。
        expect(await captured.exists(), isFalse);
        expect(await captured.parent.exists(), isFalse);
        expect(
          await Directory(p.join(root.path, 'diary_camera')).exists(),
          isTrue,
        );
      });
    }

    test(
      'closing the camera without a shot leaves the document as is',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(cameraChannel, (_) async => null);
        final importer = DiaryMediaImportController();
        addTearDown(importer.dispose);
        final original = diaryDocumentToStoredJson(editorState.document);
        expect(
          await importer.captureAndInsert(
            editorState: editorState,
            kind: DiaryMediaKind.image,
            isCurrent: () => true,
          ),
          DiaryMediaImportOutcome.cancelled,
        );
        expect(diaryDocumentToStoredJson(editorState.document), original);
        expect(importer.isBusy, isFalse);
      },
    );

    for (final (code, expected) in [
      (
        'camera_permission_denied',
        DiaryMediaImportOutcome.cameraPermissionDenied,
      ),
      ('camera_unavailable', DiaryMediaImportOutcome.cameraUnavailable),
      ('capture_failed', DiaryMediaImportOutcome.failed),
    ]) {
      test(
        'camera $code is reported and the next capture still works',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final captured = await stageCapture('IMG_retry.jpg');
          var attempts = 0;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(cameraChannel, (_) async {
                if (attempts++ == 0) throw PlatformException(code: code);
                return [
                  {'name': 'IMG_retry.jpg', 'path': captured.path, 'size': 3},
                ];
              });
          final importer = DiaryMediaImportController();
          addTearDown(importer.dispose);
          final original = diaryDocumentToStoredJson(editorState.document);
          expect(
            await importer.captureAndInsert(
              editorState: editorState,
              kind: DiaryMediaKind.image,
              isCurrent: () => true,
            ),
            expected,
          );
          expect(diaryDocumentToStoredJson(editorState.document), original);
          expect(importer.isBusy, isFalse);
          expect(
            await importer.captureAndInsert(
              editorState: editorState,
              kind: DiaryMediaKind.image,
              isCurrent: () => true,
            ),
            DiaryMediaImportOutcome.inserted,
          );
        },
      );
    }

    test('platforms without camera capture never reach the camera', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      var calls = 0;
      final importer = DiaryMediaImportController(
        capturer: (_) async {
          calls++;
          return null;
        },
      );
      addTearDown(importer.dispose);
      for (final kind in DiaryMediaKind.values) {
        expect(
          await importer.captureAndInsert(
            editorState: editorState,
            kind: kind,
            isCurrent: () => true,
          ),
          DiaryMediaImportOutcome.unsupported,
        );
      }
      expect(calls, 0);
      expect(importer.isBusy, isFalse);
    });

    test('attachments have no capture entry even on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var calls = 0;
      final importer = DiaryMediaImportController(
        capturer: (_) async {
          calls++;
          return null;
        },
      );
      addTearDown(importer.dispose);
      expect(
        await importer.captureAndInsert(
          editorState: editorState,
          kind: DiaryMediaKind.attachment,
          isCurrent: () => true,
        ),
        DiaryMediaImportOutcome.unsupported,
      );
      expect(calls, 0);
    });
  });
}
