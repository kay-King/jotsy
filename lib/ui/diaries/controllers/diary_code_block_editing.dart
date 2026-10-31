import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';

import '../models/diary_code_block/diary_code_block_newline.dart';

// 代码块的编辑行为：回车（留在块内自动缩进 / 连续空行退出）与代码块操作
// （设语言、转为正文、跳出代码块、复制、把当前行设为代码块）。
//
// 输入：正文的 EditorState；输出：经 Transaction 改写文档与选区；副作用：
// 复制会写系统剪贴板。焦点由调用方负责，这里不打开任何路由或面板。
//
// AppFlowy 迁移说明：原来挂在 `QuillController.onReplaceText` 上，在规则
// 改写之前拦截回车（`onReplaceText` 返回 false 即放弃默认链路）；
// AppFlowy 的 EditorState 没有替换前钩子，改为由调用方在回车键处理入口
// 先调 [handleDiaryCodeBlockEnter]：返回 true 表示已按计划改写并移动光标，
// 调用方不再走默认链路，返回 false 则一律走默认链路。回车的语义（何时退出、
// 缩进取多少）不变，见 diary_code_block_newline.dart——它现在直接产出
// AppFlowy 的 Transaction，`editorState.apply` 会按
// `transaction.afterSelection` 更新选区，一次 apply 即撤销栈里的一步。
//
// 其余操作原来经 `document.compose` + `updateSelection` 一次组合；现在经
// Transaction 一次 apply，同样只占一步撤销、只通知一次。

/// 代码块回车接管：在编辑器处理回车键之前调用。
///
/// 只接管折叠选区落在代码块内、且 [planDiaryCodeBlockNewline] 给出改写计划
/// 的情况；其余（选区不在代码块内、有选区、计划为 null）返回 false，调用方
/// 走默认链路。不可编辑时（只读）apply 不会执行任何改写，同样返回 false。
Future<bool> handleDiaryCodeBlockEnter(EditorState editorState) async {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    return false;
  }
  final document = editorState.document;
  final node = diaryCodeBlockAt(document, selection.end.path);
  if (node == null) {
    return false;
  }
  final plan = planDiaryCodeBlockNewline(
    document,
    node,
    selection.end.offset,
    0,
    '\n',
  );
  if (plan == null) {
    return false;
  }
  await editorState.apply(plan.transaction);
  return true;
}

/// 把当前选区触及的每个代码块设为语言 [value]（true / 'plain' / 语言 id，
/// 调用方传入已规整的值）；选区不变。
///
/// 块文档里语言记在代码块节点的 `language` 键上（缺省为自动识别）：一次
/// Transaction 改完触及的全部块，只占一步撤销；只改块属性，不增删字符，
/// 原选区不受影响。
Future<void> setDiaryCodeBlockLanguage(
  EditorState editorState,
  Object value,
) async {
  final selection = editorState.selection;
  if (selection == null) {
    return;
  }
  final blocks = diaryCodeBlocksInRange(editorState.document, selection);
  if (blocks.isEmpty) {
    return;
  }
  final transaction = editorState.transaction;
  // 只改块属性：apply 默认会按 afterSelection 更新选区，这里把它指回改写前，
  // 否则选区会被清空（PropertyValueNotifier 每次赋值都通知），面板会误判为
  // “选区离开代码块”而收起。Quill 时代同样是“选区不变”。
  transaction.afterSelection = transaction.beforeSelection;
  for (final block in blocks) {
    // true 表示自动识别：删掉 language 键回到缺省（null 值即删除该键）。
    transaction.updateNode(block, <String, dynamic>{
      kDiaryBlockLanguageKey: value == true ? null : value,
    });
  }
  await editorState.apply(transaction);
}

/// 把当前选区触及的每个代码块转为正文（类型换回段落，文字原样保留）。
Future<void> convertDiaryCodeBlockToText(EditorState editorState) async {
  final selection = editorState.selection;
  if (selection == null) {
    return;
  }
  final blocks = diaryCodeBlocksInRange(editorState.document, selection);
  if (blocks.isEmpty) {
    return;
  }
  final transaction = editorState.transaction;
  // 选区指回改写前（见 setDiaryCodeBlockLanguage）：光标留在转成的段落里，
  // 工具栏靠“选区不再触及代码块”收起面板，而不是靠选区被清空。
  transaction.afterSelection = transaction.beforeSelection;
  for (final block in blocks) {
    final attributes = <String, dynamic>{};
    final delta = block.delta;
    if (delta != null) {
      // 存 JSON（Node.delta 只认 List）：直接存 Delta 对象会读出 null，
      // 转成的段落就没文字了。
      attributes[kDiaryBlockDeltaKey] = delta.toJson();
    }
    // 换类型但保留节点 id 与文字，一次 Transaction 只占一步撤销。
    transaction.updateNodeType(block, kDiaryBlockParagraph, attributes);
  }
  await editorState.apply(transaction);
}

/// 光标在代码块里时跳到块后的普通空行：块后紧跟一个没有块属性的空段落就
/// 直接移过去，否则在块后新插一个普通空段落再移过去。
Future<void> exitDiaryCodeBlock(EditorState editorState) async {
  final selection = editorState.selection;
  if (selection == null) {
    return;
  }
  final document = editorState.document;
  final block = diaryCodeBlockAt(document, selection.end.path);
  if (block == null) {
    return;
  }
  final transaction = editorState.transaction;
  final next = block.next;
  if (next != null && _isPlainEmptyParagraph(next)) {
    transaction.afterSelection = Selection.collapsed(
      Position(path: next.path, offset: 0),
    );
  } else {
    final paragraphPath = block.path.next;
    transaction.insertNode(paragraphPath, paragraphNode());
    transaction.afterSelection = Selection.collapsed(
      Position(path: paragraphPath, offset: 0),
    );
  }
  await editorState.apply(transaction);
}

/// 没有块属性的空段落（原来“没有块样式的空行”的对应）。
bool _isPlainEmptyParagraph(Node node) {
  if (node.type != kDiaryBlockParagraph) {
    return false;
  }
  if (!(node.delta?.isEmpty ?? true)) {
    return false;
  }
  return node.attributes.keys.every((key) => key == kDiaryBlockDeltaKey);
}

/// 把 [block] 的纯文本写入系统剪贴板。
Future<void> copyDiaryCodeBlock(Node block) =>
    Clipboard.setData(ClipboardData(text: diaryCodeBlockText(block)));

/// 把当前行（或选区覆盖的各行）设为未指定语言的代码块。
///
/// 调用方已保证选区没有碰到代码块（碰到时走面板逻辑）；这里只处理文字块，
/// 图片、分隔线等非文字块不动。语言缺省即自动识别。
Future<void> toggleDiaryCodeBlockOn(EditorState editorState) async {
  final selection = editorState.selection;
  if (selection == null) {
    return;
  }
  final document = editorState.document;
  final List<Node?> candidates = selection.isCollapsed
      ? <Node?>[document.nodeAtPath(selection.end.path)]
      : editorState.getNodesInSelection(selection);
  final transaction = editorState.transaction;
  // 选区指回改写前（见 setDiaryCodeBlockLanguage）：Quill 时代
  // `formatSelection` 同样不挪光标。
  transaction.afterSelection = transaction.beforeSelection;
  var changed = false;
  for (final node in candidates) {
    if (node == null || isDiaryCodeBlock(node)) {
      continue;
    }
    final delta = node.delta;
    if (delta == null) {
      continue;
    }
    transaction.updateNodeType(node, kDiaryBlockCode, <String, dynamic>{
      kDiaryBlockDeltaKey: delta,
    });
    changed = true;
  }
  if (changed) {
    await editorState.apply(transaction);
  }
}
