// 写作助手对正文的读取与写回（AI 助手唯一的正文写入出口）。
//
// - 读取：按作用范围取出要发给 AI 的文字与它在文档里的选区
//   （[diaryAiTarget]）：选区、当前段落、光标前的内容或全文；
// - 写回：把 AI 输出的 Markdown 转成块（fork 没有上游的
//   `diaryMarkdownPasteNodes` 粘贴转换链，这里用本文件末尾的
//   [_diaryMarkdownToNodes] 做同等的小转换：标题、列表、待办、引用、
//   代码围栏与行内标记），用**一次事务**替换目标范围或插在它下方，
//   整个操作一步撤销；
// - 代码块与表格格子里的文字是原文：结果按纯文本写回同一块，不拆块；
// - 目标在生成期间失效（块被删）时退回到在正文末尾插入，不丢结果。

import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;

import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../ai/models/ai_preference_parts.dart';
import '../widgets/diary_callout_block/diary_callout_block.dart';
import 'diary_editor_controller.dart';

/// 写作指令作用的范围。
enum DiaryAiScope {
  /// 选中的文字（没有选区时退回当前段落）。
  selection,

  /// 光标所在的段落。
  paragraph,

  /// 光标前的全部内容（续写）。
  beforeCaret,

  /// 全文。
  document,
}

/// 一次写作指令的目标：要发送的文字，以及结果写回的位置。
class DiaryAiTarget {
  const DiaryAiTarget({
    required this.scope,
    required this.selection,
    required this.text,
  });

  final DiaryAiScope scope;

  /// 文档里的范围（已规整为正向）；续写时为光标处的折叠选区。
  final af.Selection selection;

  /// 发给 AI 的文字（纯文本，一块一行）。
  final String text;

  bool get isEmpty => text.trim().isEmpty;
}

/// 按 [scope] 取出目标；文档为空、选区不存在时返回 null。
DiaryAiTarget? diaryAiTarget(
  DiaryEditorController controller,
  DiaryAiScope scope, {
  af.Selection? selection,
}) {
  final document = controller.document;
  final textNodes = [
    for (final node in walkDiaryEditorNodes(document))
      if (node.delta != null) node,
  ];
  if (textNodes.isEmpty) return null;
  final current = (selection ?? controller.selection)?.normalized;
  switch (scope) {
    case DiaryAiScope.document:
      final first = textNodes.first;
      final last = textNodes.last;
      final range = af.Selection(
        start: af.Position(path: first.path, offset: 0),
        end: af.Position(path: last.path, offset: last.delta!.length),
      );
      return DiaryAiTarget(
        scope: scope,
        selection: range,
        text: controller.plainText,
      );
    case DiaryAiScope.beforeCaret:
      final caret =
          current?.end ??
          af.Position(
            path: textNodes.last.path,
            offset: textNodes.last.delta!.length,
          );
      final range = af.Selection(
        start: af.Position(path: textNodes.first.path, offset: 0),
        end: caret,
      );
      return DiaryAiTarget(
        scope: scope,
        selection: af.Selection.collapsed(caret),
        text: diaryEditorSelectionText(controller, range),
      );
    case DiaryAiScope.selection:
      if (current != null && !current.isCollapsed) {
        return DiaryAiTarget(
          scope: scope,
          selection: current,
          text: diaryEditorSelectionText(controller, current),
        );
      }
      return diaryAiTarget(
        controller,
        DiaryAiScope.paragraph,
        selection: current,
      );
    case DiaryAiScope.paragraph:
      final node = current == null
          ? textNodes.last
          : document.nodeAtPath(current.end.path);
      final delta = node?.delta;
      if (node == null || delta == null) return null;
      final range = af.Selection(
        start: af.Position(path: node.path, offset: 0),
        end: af.Position(path: node.path, offset: delta.length),
      );
      return DiaryAiTarget(
        scope: DiaryAiScope.paragraph,
        selection: range,
        text: delta.toPlainText(),
      );
  }
}

/// 选区里的纯文本（与复制同一取法：表格格子只取段落，一块一行）。
String diaryEditorSelectionText(
  DiaryEditorController controller,
  af.Selection selection,
) {
  final normalized = selection.normalized;
  final nodes = [
    for (final node in controller.state.getSelectedNodes(selection: normalized))
      if (node.type == af.TableCellBlockKeys.type) ...node.children else node,
  ];
  return diaryBlocksPlainText({
    'document': {
      'type': 'page',
      'children': [for (final node in nodes) node.toJson()],
    },
  });
}

/// AI 输出的 Markdown 转成编辑器块（不在任何文档里，可直接插入）。
List<af.Node> diaryAiMarkdownNodes(String markdown) {
  final text = markdown.trim();
  if (text.isEmpty) return const <af.Node>[];
  final data = looksLikeDiaryMarkdown(text)
      ? _diaryMarkdownToNodes(text)
      // 纯文字：一行一段，空行只是段落之间的分隔，不另成空段落。
      : <Map<String, dynamic>>[
          for (final line in text.split('\n'))
            if (line.trim().isNotEmpty) af.paragraphNode(text: line).toJson(),
        ];
  final document = diaryEditorDocument(
    jsonEncode({
      'document': {'type': 'page', 'children': data},
    }),
  );
  return [for (final node in document.root.children) node.deepCopy()];
}

/// 目标所在的块是否只能按原文写（代码块、表格格子）。
bool _rawTextBlock(af.Node? node) =>
    node != null &&
    (node.type == kDiaryBlockCode || diaryTableCellOf(node) != null);

/// 用 [markdown] 替换 [target] 的范围。一次事务、一步撤销；目标已失效时
/// 退回到正文末尾插入。
void replaceDiaryAiTarget(
  DiaryEditorController controller,
  DiaryAiTarget target,
  String markdown,
) {
  if (controller.readOnly) return;
  final document = controller.document;
  final selection = target.selection.normalized;
  final first = document.nodeAtPath(selection.start.path);
  final last = document.nodeAtPath(selection.end.path);
  final firstDelta = first?.delta;
  final lastDelta = last?.delta;
  if (first == null ||
      last == null ||
      firstDelta == null ||
      lastDelta == null ||
      selection.start.offset > firstDelta.length ||
      selection.end.offset > lastDelta.length) {
    appendDiaryAiResult(controller, markdown);
    return;
  }
  final before = firstDelta.slice(0, selection.start.offset);
  final after = lastDelta.slice(selection.end.offset);
  final transaction = controller.state.transaction;

  // 起止之间（不含起点块）的块一并删掉；起点块的子块不在选区里时保留。
  if (!selection.isSingle) {
    final middle = [
      for (final node in controller.state.getNodesInSelection(selection))
        if (!identical(node, first) && !_isAncestorOf(node, first)) node,
    ];
    transaction.deleteNodes(_topMost(middle));
  }

  final nodes = _rawTextBlock(first)
      ? <af.Node>[af.paragraphNode(text: markdown.trim())]
      : diaryAiMarkdownNodes(markdown);
  if (nodes.isEmpty) {
    transaction.updateNode(first, {'delta': (before + after).toJson()});
    transaction.afterSelection = af.Selection.collapsed(
      af.Position(path: first.path, offset: before.length),
    );
    controller.apply(transaction);
    return;
  }

  // 结果只有一段文字：并进起点块，保留它的块类型（列表项、引用、标题…）。
  final single =
      nodes.length == 1 &&
      nodes.single.delta != null &&
      nodes.single.type == 'paragraph';
  if (single || _rawTextBlock(first)) {
    final inserted = single
        ? nodes.single.delta!
        : (af.Delta()..insert(markdown.trim()));
    transaction.updateNode(first, {
      'delta': (before + inserted + after).toJson(),
    });
    transaction.afterSelection = af.Selection.collapsed(
      af.Position(path: first.path, offset: before.length + inserted.length),
    );
    controller.apply(transaction);
    return;
  }

  // 多块结果：起点块留下前半段（为空的普通段落整块换掉），新块接在后面，
  // 末段的后半段作为同类型的块接在最后。
  final replaceFirst =
      before.isEmpty && first.type == 'paragraph' && first.children.isEmpty;
  final insertPath = replaceFirst ? first.path : first.path.next;
  final tail = after.isEmpty
      ? null
      : last.copyWith(
          attributes: {...last.attributes, 'delta': after.toJson()},
          children: <af.Node>[],
        );
  if (!replaceFirst) {
    transaction.updateNode(first, {'delta': before.toJson()});
  }
  transaction.insertNodes(insertPath, [...nodes, ?tail]);
  if (replaceFirst) transaction.deleteNode(first);
  final lastInserted = nodes.last;
  transaction.afterSelection = af.Selection.collapsed(
    af.Position(
      path: insertPath.nextNPath(nodes.length - 1),
      offset: lastInserted.delta?.length ?? 0,
    ),
  );
  controller.apply(transaction);
}

/// 把 [markdown] 插在 [target] 所在块的后面（续写时为光标所在块）。一次
/// 事务、一步撤销。
void insertDiaryAiBelow(
  DiaryEditorController controller,
  DiaryAiTarget target,
  String markdown,
) {
  if (controller.readOnly) return;
  final anchor = controller.document.nodeAtPath(
    target.selection.normalized.end.path,
  );
  if (anchor == null) {
    appendDiaryAiResult(controller, markdown);
    return;
  }
  // 代码块与格子里：作为原文接在块尾，另起一行。
  if (_rawTextBlock(anchor) && anchor.delta != null) {
    final transaction = controller.state.transaction;
    final delta = anchor.delta!;
    final addition = '\n${markdown.trim()}';
    transaction.insertText(anchor, delta.length, addition);
    transaction.afterSelection = af.Selection.collapsed(
      af.Position(path: anchor.path, offset: delta.length + addition.length),
    );
    controller.apply(transaction);
    return;
  }
  final nodes = diaryAiMarkdownNodes(markdown);
  if (nodes.isEmpty) return;
  // 插在顶层祖先之后：目标在表格里时插到表格后面。
  final table = diaryTableOf(anchor);
  final path = (table ?? anchor).path.next;
  final transaction = controller.state.transaction
    ..insertNodes(path, nodes)
    ..afterSelection = af.Selection.collapsed(
      af.Position(
        path: path.nextNPath(nodes.length - 1),
        offset: nodes.last.delta?.length ?? 0,
      ),
    );
  controller.apply(transaction);
}

/// 把一个写作灵感问题插到光标处（新建空白日记时即正文开头）：按设置写成
/// 提示块、引用或小标题，后面接一个空段落、光标落在那里，可以直接回答。
/// 一次事务、一步撤销。
void insertDiaryAiPrompt(
  DiaryEditorController controller,
  String question,
  AiPromptInsertStyle style,
) {
  if (controller.readOnly || question.trim().isEmpty) return;
  final text = question.trim();
  final node = switch (style) {
    // fork 的提示块是 `diaryCalloutBlock`（不是上游的 `callout`）：
    // 文字走 `blockComponentDelta`（常量值即 `'delta'`），背景与图标取
    // 默认第一项。
    AiPromptInsertStyle.callout => af.Node(
      type: kDiaryCalloutBlockType,
      attributes: <String, dynamic>{
        af.blockComponentDelta: (af.Delta()..insert(text)).toJson(),
        kDiaryCalloutBackgroundKey: kDiaryCalloutColors.first,
        kDiaryCalloutIconKey: '💡',
      },
    ),
    AiPromptInsertStyle.quote => af.quoteNode(delta: af.Delta()..insert(text)),
    AiPromptInsertStyle.heading => af.headingNode(
      level: 3,
      delta: af.Delta()..insert(text),
    ),
  };
  // 光标处：空段落上替换，否则插在光标所在顶层块之后、后面补一个空段落，
  // 光标落在空段落上；一次事务、一步撤销。
  final transaction = controller.state.transaction;
  final selection = controller.selection?.normalized;
  final anchor = selection == null
      ? null
      : controller.document.nodeAtPath(selection.end.path);
  final emptyParagraph =
      anchor != null &&
      anchor.type == kDiaryBlockParagraph &&
      anchor.delta != null &&
      anchor.delta!.toPlainText().trim().isEmpty &&
      anchor.children.isEmpty;
  final insertPath = anchor == null
      ? <int>[controller.document.root.children.length]
      : emptyParagraph
      ? anchor.path
      : anchor.path.next;
  final after = af.paragraphNode();
  // 先插后删：AppFlowy 会把“先删同一路径、再插”的路径变换成 -1，空文档
  // 中会反转节点顺序（见上游 insertDiaryEditorNodes 的同一处理）。原节点
  // 的删除路径由前面的插入自动向后平移；选区最后定（deleteNode 会动它）。
  transaction.insertNodes(insertPath, [node, after]);
  if (emptyParagraph) {
    transaction.deleteNode(anchor);
  }
  transaction.afterSelection = af.Selection.collapsed(
    af.Position(path: insertPath.next, offset: 0),
  );
  controller.apply(transaction);
}

/// 插在正文末尾（目标失效时的退路）。
void appendDiaryAiResult(DiaryEditorController controller, String markdown) {
  if (controller.readOnly) return;
  final nodes = diaryAiMarkdownNodes(markdown);
  if (nodes.isEmpty) return;
  final path = <int>[controller.document.root.children.length];
  final transaction = controller.state.transaction
    ..insertNodes(path, nodes)
    ..afterSelection = af.Selection.collapsed(
      af.Position(
        path: path.nextNPath(nodes.length - 1),
        offset: nodes.last.delta?.length ?? 0,
      ),
    );
  controller.apply(transaction);
}

bool _isAncestorOf(af.Node node, af.Node other) {
  var parent = other.parent;
  while (parent != null) {
    if (identical(parent, node)) return true;
    parent = parent.parent;
  }
  return false;
}

/// 去掉已被祖先包含的节点：祖先删掉后子块随之删除，再删一次会出错。
List<af.Node> _topMost(List<af.Node> nodes) => [
  for (final node in nodes)
    if (!nodes.any(
      (other) => !identical(other, node) && _isAncestorOf(other, node),
    ))
      node,
];

// ---- fork 本地实现（上游的 diary_table_editing.dart / diary_markdown_paste.dart
// 在 fork 里不存在；表格按 AppFlowy 原生 `table` / `table/cell` 找）----

/// 沿父链找节点所在的表格（顶层表格节点），不在表格里时返回 null。
af.Node? diaryTableOf(af.Node node) {
  for (var current = node.parent; current != null; current = current.parent) {
    if (current.type == af.TableBlockKeys.type) return current;
  }
  return null;
}

/// 沿父链找节点所在的表格格子，不在表格里时返回 null。
af.Node? diaryTableCellOf(af.Node node) {
  for (af.Node? current = node; current != null; current = current.parent) {
    if (current.type == af.TableCellBlockKeys.type) return current;
  }
  return null;
}

/// 保守地判断一段文字是不是 Markdown：只有出现标题行、代码围栏、引用、
/// 至少两行列表项或成对的行内标记时才按 Markdown 转，否则按纯文字一行一段。
bool looksLikeDiaryMarkdown(String text) {
  final lines = text.split('\n');
  var listLines = 0;
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#') && _kDiaryHeading.hasMatch(trimmed)) {
      return true;
    }
    if (trimmed.startsWith('```') || trimmed.startsWith('> ')) return true;
    if (_kDiaryListItem.hasMatch(trimmed)) {
      if (++listLines >= 2) return true;
    }
  }
  return _kDiaryInlineMark.hasMatch(text);
}

final _kDiaryHeading = RegExp(r'^(#{1,6})\s+\S');
final _kDiaryListItem = RegExp(r'^([-*+]\s+|\d+[.)]\s+|[-*]\s+\[[ xX]\]\s+)');
final _kDiaryInlineMark = RegExp(
  r'(\*\*[^*]+\*\*|\*[^*]+\*|~~[^~]+~~|`[^`]+`|\[[^\]]+\]\([^)]+\))',
);

/// Markdown → 块 JSON（与粘贴 Markdown 的转换同级，但只做 AI 输出需要的
/// 一小部分：标题、无序/有序/待办列表、引用、代码围栏、段落，行内粗体 /
/// 斜体 / 删除线 / 行内代码 / 链接）。未知结构按纯文字段落落下，不丢内容。
List<Map<String, dynamic>> _diaryMarkdownToNodes(String text) {
  final nodes = <Map<String, dynamic>>[];
  final lines = text.split('\n');
  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      index++;
      continue;
    }
    if (trimmed.startsWith('```')) {
      final buffer = <String>[];
      index++;
      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        buffer.add(lines[index]);
        index++;
      }
      index++; // 跳过结束围栏。
      nodes.add(<String, dynamic>{
        kDiaryBlockTypeKey: kDiaryBlockCode,
        kDiaryBlockDataKey: {
          kDiaryBlockDeltaKey: (af.Delta()..insert(buffer.join('\n'))).toJson(),
        },
      });
      continue;
    }
    final heading = _kDiaryHeading.firstMatch(trimmed);
    if (heading != null) {
      final level = heading.group(1)!.length;
      nodes.add(
        _diaryTextNode(
          kDiaryBlockHeading,
          trimmed.substring(level).trim(),
          extra: {kDiaryBlockLevelKey: level},
        ),
      );
      index++;
      continue;
    }
    if (trimmed.startsWith('>')) {
      nodes.add(_diaryTextNode(kDiaryBlockQuote, trimmed.substring(1).trim()));
      index++;
      continue;
    }
    final todo = RegExp(r'^[-*]\s+\[([ xX])\]\s+(.*)$').firstMatch(trimmed);
    if (todo != null) {
      nodes.add(
        _diaryTextNode(
          kDiaryBlockTodoList,
          todo.group(2) ?? '',
          extra: {kDiaryBlockCheckedKey: todo.group(1)?.toLowerCase() == 'x'},
        ),
      );
      index++;
      continue;
    }
    final unordered = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (unordered != null) {
      nodes.add(
        _diaryTextNode(kDiaryBlockBulletedList, unordered.group(1) ?? ''),
      );
      index++;
      continue;
    }
    final ordered = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(trimmed);
    if (ordered != null) {
      nodes.add(
        _diaryTextNode(kDiaryBlockNumberedList, ordered.group(1) ?? ''),
      );
      index++;
      continue;
    }
    nodes.add(_diaryTextNode(kDiaryBlockParagraph, trimmed));
    index++;
  }
  return nodes;
}

Map<String, dynamic> _diaryTextNode(
  String type,
  String text, {
  Map<String, dynamic>? extra,
}) {
  return <String, dynamic>{
    kDiaryBlockTypeKey: type,
    kDiaryBlockDataKey: {
      kDiaryBlockDeltaKey: _diaryInlineDelta(text).toJson(),
      ...?extra,
    },
  };
}

/// 行内标记 → Delta：`**粗体**`、`*斜体*`、`~~删除线~~`、`` `代码` ``、
// `[文字](链接)`；不识别的标记原样保留。
af.Delta _diaryInlineDelta(String text) {
  final delta = af.Delta();
  final pattern = RegExp(
    r'\*\*([^*]+)\*\*|\*([^*]+)\*|~~([^~]+)~~|`([^`]+)`|\[([^\]]+)\]\(([^)]+)\)',
  );
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      delta.insert(text.substring(cursor, match.start));
    }
    if (match.group(1) != null) {
      delta.insert(match.group(1)!, attributes: {'bold': true});
    } else if (match.group(2) != null) {
      delta.insert(match.group(2)!, attributes: {'italic': true});
    } else if (match.group(3) != null) {
      delta.insert(match.group(3)!, attributes: {'strikethrough': true});
    } else if (match.group(4) != null) {
      delta.insert(match.group(4)!, attributes: {'code': true});
    } else if (match.group(5) != null) {
      delta.insert(match.group(5)!, attributes: {'href': match.group(6)});
    }
    cursor = match.end;
  }
  if (cursor < text.length) delta.insert(text.substring(cursor));
  if (delta.isEmpty) delta.insert('');
  return delta;
}
