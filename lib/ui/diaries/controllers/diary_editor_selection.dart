import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';

/// 日记正文选区菜单的剪贴板操作，直接对 AppFlowy [EditorState] 做。
///
/// 本项目编辑页直接持有 `EditorState`（没有上游 `DiaryEditorController` 那层
/// 包装），所以这里只用 `EditorState` 自带的扩展：选区读写经
/// `getSelectedNodes` / `deleteSelection`，粘贴经 `pasteSingleLineNode` /
/// `pasteMultiLineNodes`（它们会先按需删掉选区）。
///
/// 剪贴板只在显式复制 / 粘贴时访问；复制的纯文本与分享、其他应用的文字处理
/// 共用同一口径（[diaryEditorSelectedPlainText]）。

/// 选中内容的纯文本，与 [copyDiaryEditorSelection] 写进系统剪贴板的文字同一
/// 口径；没有选区或只是光标时为 null。
String? diaryEditorSelectedPlainText(EditorState editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) return null;
  final nodes = <Node>[
    for (final node in editorState.getSelectedNodes(selection: selection))
      // 选区从格子里开始或结束时会带上零散的格子：只留它们的段落，
      // 分享 / 处理时不会出现没有表格的格子。
      if (node.type == TableCellBlockKeys.type) ...node.children else node,
  ];
  return diaryBlocksPlainText({
    'document': {
      'type': 'page',
      'children': [for (final node in nodes) node.toJson()],
    },
  });
}

/// 把选中内容以纯文本写进系统剪贴板；没有范围选区时什么也不做。
Future<void> copyDiaryEditorSelection(EditorState editorState) async {
  final text = diaryEditorSelectedPlainText(editorState);
  if (text == null) return;
  await Clipboard.setData(ClipboardData(text: text));
}

/// 剪切选中内容：先复制，再删掉选区；只读或没有范围选区时什么也不做。
Future<void> cutDiaryEditorSelection(
  EditorState editorState, {
  required bool editable,
}) async {
  if (!editable) return;
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) return;
  await copyDiaryEditorSelection(editorState);
  if (editorState.isDisposed) return;
  await editorState.deleteSelection(selection);
}

/// 以纯文本粘贴剪贴板内容：每行一段，不转换 Markdown。
/// 只读或剪贴板没有文字时什么也不做。
Future<void> pasteDiaryEditorPlainText(
  EditorState editorState, {
  required bool editable,
}) async {
  if (!editable || editorState.isDisposed) return;
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (text == null || text.isEmpty) return;
  await insertDiaryEditorPlainText(editorState, text, editable: editable);
}

/// 以纯文本 [text] 替换当前选区（粘贴原文与其他应用的文字处理回写共用）：
/// 每行一段，不转换 Markdown，一步撤销。
Future<void> insertDiaryEditorPlainText(
  EditorState editorState,
  String text, {
  required bool editable,
}) async {
  if (!editable || editorState.isDisposed) return;
  final nodes = <Node>[
    for (final line in text.replaceAll('\r\n', '\n').split('\n'))
      paragraphNode(text: line),
  ];
  if (nodes.length == 1) {
    await editorState.pasteSingleLineNode(nodes.single);
  } else {
    await editorState.pasteMultiLineNodes(nodes);
  }
}

/// 全选正文：从首块开头到末块末尾。
///
/// 不直接用上游 `selectAllCommand`：它的 handler 经 `getLastSelectable()` 取
/// 末尾可选中节点，需要编辑器已挂载的渲染服务，裸 `EditorState`（如测试里）
/// 跑不了。这里按文档顺序取最后一个带文字的块，行为与命令一致（末尾是嵌入
/// 块时选到最后一个文字块的末尾）。
void selectAllDiaryEditor(EditorState editorState) {
  if (editorState.selection == null) return;
  final root = editorState.document.root;
  if (root.children.isEmpty) return;
  final end =
      _lastTextEnd(root) ?? Position(path: root.children.last.path, offset: 0);
  editorState.updateSelectionWithReason(
    Selection(
      start: Position(path: <int>[0]),
      end: end,
    ),
    reason: SelectionUpdateReason.selectAll,
  );
}

/// 文档里最后一个带文字的块的末尾位置（深度优先、从后往前找）。
Position? _lastTextEnd(Node root) {
  Position? found;
  void visit(Node node) {
    final delta = node.delta;
    if (delta != null) {
      found = Position(path: node.path, offset: delta.length);
    }
    for (final child in node.children) {
      visit(child);
    }
  }

  for (final child in root.children) {
    visit(child);
  }
  return found;
}
