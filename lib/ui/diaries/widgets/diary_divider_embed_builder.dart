import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// 正文分隔线（导入笔记的 `<hr>`、手机笔记的分隔线）的 AppFlowy 块组件：
/// 注册到 `divider` 类型节点的渲染器。
///
/// 独占一行的细线，用 `outlineVariant` 跟随亮暗主题；UI 与 Quill 时代一致。
class DiaryDividerEmbedBuilder extends BlockComponentBuilder {
  DiaryDividerEmbedBuilder();

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryDividerBlockWidget(key: node.key, node: node);
  }
}

class _DiaryDividerBlockWidget extends BlockComponentStatelessWidget {
  const _DiaryDividerBlockWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
