import 'dart:async';
import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/cupertino.dart' show showCupertinoModalPopup;
import 'package:flutter/material.dart';
// 复用上游的宽高滑条，保持与原菜单一致的调整方式；上游未导出该组件。
// ignore: implementation_imports
import 'package:flutter_quill_extensions/src/editor/image/widgets/image_resizer.dart'
    show ImageResizer;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_image_embed_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_image_embed_data.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

/// 点按正文图片弹出的菜单：查看、调整大小、复制、保存到相册、删除。
///
/// 取代上游 `ImageOptionsMenu`：上游的“缩放”打开它自带的 PhotoView 页面，
/// 长图在那里只是一条细线，也绕开了看图页的统一入口；这里的“查看”经
/// [openImageViewer] 打开（长图按屏宽竖向滚动）。调整大小沿用上游的宽高滑条，
/// 复制把图片写进系统剪贴板（一份 PNG），保存与看图页同一条链路，提示经
/// [HomeHintVisibilityScope.showTrackedSnackBar]。
///
/// AppFlowy 迁移说明：图片是独立块节点，直接以 [Node] 定位（原来按文档字符
/// 偏移）；动作实现见 [DiaryImageEmbedActions]（EditorState 版）。
///
/// [readOnly]（发布页预览等只读正文）时只有查看、复制、保存。图片块在点按时
/// 传入 [node]，菜单期间正文不会被改动。
///
/// [onDescribeImage] 给出时多一项「AI 描述图片」：回调返回的描述以一次事务
/// 插在图片块后面（一步撤销）。回调由调用方接 AI 流程；图片点按菜单本身在
/// fork 里尚未接线（见 diary_image_embed_builder.dart），此项随菜单一起
/// 待接线。
Future<void> showDiaryImageOptions(
  BuildContext context, {
  required EditorState editorState,
  required Node node,
  required String source,
  required bool readOnly,
  Future<String?> Function(String source)? onDescribeImage,
}) async {
  final l10n = context.l10n;
  final style = diaryImageStyleOf(node);
  final action = await showDialog<_ImageAction>(
    context: context,
    builder: (BuildContext dialogContext) => _DiaryImageOptionsDialog(
      readOnly: readOnly,
      describeAvailable: onDescribeImage != null,
    ),
  );
  if (action == null || !context.mounted) {
    return;
  }
  switch (action) {
    case _ImageAction.view:
      unawaited(
        openImageViewer(
          context,
          items: <ImageViewerItem>[ImageViewerItem(source: source)],
          initialIndex: 0,
        ),
      );
    case _ImageAction.resize:
      _showResizer(context, editorState, node: node, style: style);
    case _ImageAction.copy:
      await DiaryImageEmbedActions.copy(source: source);
    case _ImageAction.save:
      final hint = await DiaryImageEmbedActions.saveToGallery(source, l10n);
      if (hint != null && context.mounted) {
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(
            content: Text(hint),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    case _ImageAction.describe:
      final describe = onDescribeImage;
      if (describe == null) return;
      final description = await describe(source);
      if (description == null || description.trim().isEmpty) return;
      final transaction = editorState.transaction
        ..insertNodes(node.path.next, [paragraphNode(text: description.trim())])
        ..afterSelection = Selection.collapsed(
          Position(path: node.path.next, offset: description.trim().length),
        );
      await editorState.apply(
        transaction,
        skipHistoryDebounce: true,
        withUpdateSelection: true,
      );
    case _ImageAction.delete:
      await DiaryImageEmbedActions.remove(editorState, node: node);
  }
}

/// 宽高滑条（上游 [ImageResizer]）：拖动时逐帧写回图片块的样式。初始值取已有
/// 上限并夹到滑条范围内（导入的图片可能写着比屏幕还大的宽度，滑条会断言越界）；
/// 没有上限时取最大值，与上游一致。每次写入都只替换宽高两项，所以始终基于
/// 打开时的 [style] 计算即可，样式里的其他声明原样保留。
void _showResizer(
  BuildContext context,
  EditorState editorState, {
  required Node node,
  required String? style,
}) {
  final bounds = diaryImageEmbedBounds(node);
  showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext modalContext) {
      final screen = MediaQuery.sizeOf(modalContext);
      double? initial(double bound, double max) =>
          bound.isFinite ? math.min(bound, max) : null;
      return ImageResizer(
        imageWidth: initial(bounds.maxWidth, screen.width),
        imageHeight: initial(bounds.maxHeight, screen.height),
        maxWidth: screen.width,
        maxHeight: screen.height,
        onImageResize: (double width, double height) {
          unawaited(
            DiaryImageEmbedActions.resize(
              editorState,
              node: node,
              style: style,
              width: width,
              height: height,
            ),
          );
        },
      );
    },
  );
}

enum _ImageAction { view, resize, copy, save, describe, delete }

class _DiaryImageOptionsDialog extends StatelessWidget {
  const _DiaryImageOptionsDialog({
    required this.readOnly,
    this.describeAvailable = false,
  });

  final bool readOnly;
  final bool describeAvailable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    Widget item(
      _ImageAction action,
      FaIconData icon,
      String label, {
      Color? color,
    }) {
      return ListTile(
        leading: SizedBox(
          width: 24,
          child: Center(child: FaIcon(icon, size: 18, color: color)),
        ),
        title: Text(
          label,
          style: color == null ? null : TextStyle(color: color),
        ),
        onTap: () => Navigator.of(context).pop(action),
      );
    }

    return SimpleDialog(
      title: Text(l10n.diaryImageMenuTitle),
      children: <Widget>[
        item(
          _ImageAction.view,
          FontAwesomeIcons.expand,
          l10n.diaryImageMenuView,
        ),
        if (!readOnly)
          item(
            _ImageAction.resize,
            FontAwesomeIcons.upRightAndDownLeftFromCenter,
            l10n.diaryImageMenuResize,
          ),
        item(_ImageAction.copy, FontAwesomeIcons.copy, l10n.diaryImageMenuCopy),
        item(
          _ImageAction.save,
          FontAwesomeIcons.download,
          l10n.imageViewerSaveToGallery,
        ),
        if (!readOnly && describeAvailable)
          item(
            _ImageAction.describe,
            FontAwesomeIcons.wandMagicSparkles,
            l10n.aiImageDescribe,
          ),
        if (!readOnly)
          item(
            _ImageAction.delete,
            FontAwesomeIcons.trashCan,
            l10n.commonDelete,
            color: colorScheme.error,
          ),
      ],
    );
  }
}
