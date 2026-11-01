import 'package:appflowy_editor/appflowy_editor.dart';

/// 视频/附件按独立块插入，保留选中的正文并把光标放到最后一个块后的空行。
///
/// [embeds] 为调用方构造好的媒体块节点（如视频 / 附件块）。
///
/// AppFlowy 迁移说明：媒体是独立块节点，插入即独占一行，不会与前后正文合并；
/// 原来为“视频自动补换行”做的多余空行扣除、以及 `skipRequestKeyboard`（那是
/// QuillController 的专有行为）都不再需要。原来在光标处断行插入，这里改为
/// 插在光标所在节点之后——正文不被删除（“保留选中的正文”不变），整段不断开。
Future<void> insertDiaryMediaBlocks({
  required EditorState editorState,
  required List<Node> embeds,
  required Selection selection,
}) async {
  if (embeds.isEmpty) return;
  final transaction = editorState.transaction;
  final normalized = selection.normalized;
  // 保留选中的正文：锚定在选区末端所在节点之后插入，不删除选区内容。
  final anchor = editorState.getNodeAtPath(normalized.end.path);
  var insertPath = anchor == null
      ? [editorState.document.root.children.length]
      : anchor.path.next;
  for (final embed in embeds) {
    transaction.insertNode(insertPath, embed);
    insertPath = insertPath.next;
  }
  // 最后一个块后跟一个可编辑的空行，光标落到行首。
  transaction.insertNode(insertPath, paragraphNode());
  transaction.afterSelection = Selection.collapsed(
    Position(path: insertPath, offset: 0),
  );
  await editorState.apply(transaction);
}
