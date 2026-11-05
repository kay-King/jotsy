import 'package:appflowy_editor/appflowy_editor.dart';

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// 正文分隔线（`divider` 块）：一条 1dp 细线，不带文字。
///
/// 渲染走 DiaryDividerEmbedBuilder；存储与导出沿用 Quill 水平线的约定
/// `{"divider": "hr"}`，见 `diary_blocks_embed.dart`。

/// 在光标所在块后面插入一条分隔线，光标落到它后面新补的空段落开头。
///
/// 分隔线本身没有文字、放不下光标，所以后面总跟一个空段落（用户插完直接
/// 接着往下写）；无选区时插到文档末尾（与表格、折叠块插入同口径）。两个
/// 节点一次插入、一次事务完成，单步可撤销。
Future<void> insertDiaryDividerBlock(EditorState editorState) async {
  final transaction = editorState.transaction;
  final selection = editorState.selection?.normalized;

  final Path insertPath;
  if (selection == null) {
    insertPath = [editorState.document.root.children.length];
  } else {
    final anchor = editorState.getNodeAtPath(selection.end.path);
    insertPath = anchor == null
        ? [editorState.document.root.children.length]
        : anchor.path.next;
  }

  transaction
    ..insertNodes(insertPath, <Node>[
      Node(type: kDiaryBlockDivider),
      paragraphNode(),
    ])
    ..afterSelection = Selection.collapsed(Position(path: insertPath.next));
  await editorState.apply(transaction);
}
