import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/painting.dart';
// 写系统剪贴板图片与上游图片菜单同一个入口（flutter_quill 标为实验性 API）。
// ignore: experimental_member_use
import 'package:flutter_quill/internal.dart' show ClipboardServiceProvider;
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/widgets/image_viewer_export_controller.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';

/// 正文图片菜单（`showDiaryImageOptions`）的动作：调整大小、删除、复制、保存。
///
/// 输入：正文编辑器状态与图片块节点（点按时取到的 Node，不依赖光标停在
/// 图片上）。副作用：改写正文（大小、删除）、写系统剪贴板、把原图存进相册。
/// 界面（菜单、滑条、提示）由调用方负责。
///
/// AppFlowy 迁移说明：图片是独立块节点，直接以 Node 定位（原来按文档字符
/// 偏移）；`skipRequestKeyboard` 是 QuillController 的专有行为，这里不需要。
/// 原来写 `controller.copiedImageUrl` 让编辑器内粘贴按来源与样式原样插回，
/// AppFlowy 没有这个机制，编辑器内粘贴的图片块插入由编辑器的粘贴处理负责，
/// 这里只保留系统剪贴板那一份 PNG。
abstract final class DiaryImageEmbedActions {
  /// 写入缩放菜单的宽高（只作显示上限）。拖动滑条时逐帧调用，一次调用即
  /// 一个 Transaction。
  static Future<void> resize(
    EditorState editorState, {
    required Node node,
    required String? style,
    required double width,
    required double height,
  }) {
    final transaction = editorState.transaction;
    transaction.updateNode(node, <String, dynamic>{
      'style': diaryImageStyleWithSize(style, width: width, height: height),
    });
    return editorState.apply(transaction);
  }

  /// 从正文移除图片（删掉图片块节点，光标留在原位置）。文件不在这里删：
  /// 撤销或放弃修改后原日记还要用它，未被引用的文件由
  /// DiaryMediaCleanupService 过了宽限期再回收。
  static Future<void> remove(EditorState editorState, {required Node node}) {
    final path = node.path;
    final transaction = editorState.transaction;
    transaction.deleteNode(node);
    transaction.afterSelection = Selection.collapsed(
      Position(path: path, offset: 0),
    );
    return editorState.apply(transaction);
  }

  /// 复制图片到系统剪贴板（一份 PNG 供其他应用粘贴）。
  ///
  /// 剪贴板图片按比例缩小解码（长边不超过安全上限），超长截图不会被压扁；
  /// 读不出来时什么也不做。
  static Future<void> copy({required String source}) async {
    final bytes = await _pngBytes(
      boundedImageProvider(resolveDiaryImageProvider(source)),
    );
    if (bytes != null) {
      // ignore: experimental_member_use
      await ClipboardServiceProvider.instance.copyImage(bytes);
    }
  }

  /// 把原图存进相册，返回给用户的提示（忙碌中被忽略时为 null）。与看图页的
  /// “保存到相册”同一条链路，原文件直接写入，不重新编码。
  static Future<String?> saveToGallery(
    String source,
    AppLocalizations l10n,
  ) async {
    final export = ImageViewerExportController();
    try {
      return await export.saveToGallery(source, l10n);
    } finally {
      export.dispose();
    }
  }

  static Future<Uint8List?> _pngBytes(ImageProvider provider) {
    final completer = Completer<Uint8List?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        final image = info.image;
        image
            .toByteData(format: ui.ImageByteFormat.png)
            .then(
              (data) => completer.complete(data?.buffer.asUint8List()),
              onError: (Object _) => completer.complete(null),
            )
            .whenComplete(info.dispose);
      },
      onError: (Object _, StackTrace? _) {
        stream.removeListener(listener);
        completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}
