import 'package:appflowy_editor/appflowy_editor.dart';

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// 工具栏「缩进 / 取消缩进」作用在正文段落上时的首行缩进（v0.11.0 #122）。
///
/// 为什么不用上游的嵌套缩进：嵌套是把段落挂成上一块的子块，子块整块向内
/// 缩进一个标记列宽，多行段落的每一行都跟着右移——用户按「缩进」想要的
/// 是中文排版的首行缩进（只有第一行空出两个字）。所以：
/// - 选区触及的文字块全是正文段落（且不在表格格子里）时，「缩进」只给这些
///   段落写 `data.firstLineIndent = true`（[kDiaryParagraphIndentKey]），由
///   预览页把首行缩进两个字，折行后的各行仍顶格；
/// - 「取消缩进」先清掉这个标记；段落没有标记但已是子块（旧版嵌套缩进过的，
///   或拖动进去的）时，交还上游的嵌套提回上一层；
/// - 选区里有列表、待办、折叠块等其他块时不走这里，仍是真实的父子嵌套
///   （列表层级是结构，不是排版）。
///
/// 每次写入一个事务、一步撤销；没有要改的段落时不写。
///
/// 注意：这个标记与全局首行缩进的 `first_line_indent`（保存时按全局设置
/// 整篇盖戳，见 `diary_first_line_indent.dart`）是两个不同的键，互不覆盖；
/// 预览时两者取较大者。

/// [node] 是否在表格格子里（沿父链找 `table/cell`）。
bool diaryNodeInTableCell(Node node) {
  for (var current = node.parent; current != null; current = current.parent) {
    if (current.type == TableCellBlockKeys.type) return true;
  }
  return false;
}

/// 「缩进」按钮作用于首行缩进的段落：选区里的文字块全是正文段落、且都不在
/// 表格格子里时为这些段落，否则为 null（交给嵌套缩进）。
List<Node>? diaryFirstLineIndentTargets(EditorState editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null) return null;
  final nodes = [
    for (final node in editorState.getNodesInSelection(selection))
      if (node.delta != null) node,
  ];
  if (nodes.isEmpty) return null;
  for (final node in nodes) {
    if (node.type != ParagraphBlockKeys.type || diaryNodeInTableCell(node)) {
      return null;
    }
  }
  return nodes;
}

/// [node] 是否带首行缩进标记。
bool diaryParagraphHasFirstLineIndent(Node node) =>
    node.attributes[kDiaryParagraphIndentKey] == true;

/// 「缩进」是否可按：还有段落没缩进首行。
bool canIndentDiaryFirstLine(List<Node> targets) =>
    targets.any((node) => !diaryParagraphHasFirstLineIndent(node));

/// 「取消缩进」是否可按：有段落缩进了首行，或（都没有时）能提回上一层。
bool canOutdentDiaryFirstLine(EditorState editorState, List<Node> targets) =>
    targets.any(diaryParagraphHasFirstLineIndent) || isOutdentable(editorState);

/// 给 [targets] 里还没缩进的段落写上首行缩进。
Future<void> indentDiaryFirstLine(
  EditorState editorState,
  List<Node> targets,
) async {
  final nodes = [
    for (final node in targets)
      if (!diaryParagraphHasFirstLineIndent(node)) node,
  ];
  if (nodes.isEmpty) return;
  final transaction = editorState.transaction;
  for (final node in nodes) {
    transaction.updateNode(node, {kDiaryParagraphIndentKey: true});
  }
  transaction.afterSelection = editorState.selection;
  await editorState.apply(transaction);
}

/// 清掉 [targets] 的首行缩进（删键）；都没有标记时按上游提回上一层。
Future<void> outdentDiaryFirstLine(
  EditorState editorState,
  List<Node> targets,
) async {
  final nodes = targets.where(diaryParagraphHasFirstLineIndent).toList();
  if (nodes.isEmpty) {
    outdentCommand.handler(editorState);
    return;
  }
  final transaction = editorState.transaction;
  for (final node in nodes) {
    transaction.updateNode(node, {kDiaryParagraphIndentKey: null});
  }
  transaction.afterSelection = editorState.selection;
  await editorState.apply(transaction);
}
