import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';

/// 正文附件的 AppFlowy 块组件：注册到 `attachment` 类型节点的渲染器。
/// 旧数据里的 `file` 类型节点同样用它渲染（注册时把同一实例挂到两个类型）。
///
/// 数据解析与 UI 与 Quill 时代一致：节点 attributes 即
/// [DiaryFileAttachment] 的字段（`path` / `name` / `sizeBytes`），解析后
/// 交给 [DiaryAttachmentTile] 渲染，点击经 [FileOpenService] 打开。
class DiaryAttachmentEmbedBuilder extends BlockComponentBuilder {
  DiaryAttachmentEmbedBuilder({this.openService = const FileOpenService()});

  final FileOpenService openService;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryAttachmentBlockWidget(
      key: node.key,
      node: node,
      openService: openService,
    );
  }
}

class _DiaryAttachmentBlockWidget extends BlockComponentStatelessWidget {
  const _DiaryAttachmentBlockWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
    this.openService = const FileOpenService(),
  });

  final FileOpenService openService;

  @override
  Widget build(BuildContext context) {
    final file = DiaryFileAttachment.tryDecode(node.attributes);
    if (file == null) {
      return Text(
        context.l10n.attachmentFileMissing,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryAttachmentTile(
      key: ValueKey(file.path),
      attachment: file,
      openService: openService,
    );
  }
}
