import 'dart:math' show min;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';

// 代码块里按回车的改写计划，以及读取代码块的公共工具（纯函数，不碰控件）。
//
// 输入：代码块节点、块内偏移、编辑器发来的替换（len / data）。
// 输出：要在 [node] 上执行的一次 [Transaction] 与执行后的选区；不该接管时
// 返回 null，交还编辑器的默认链路。
// 副作用：无（Transaction 只是操作描述，执行由调用方负责）。
//
// AppFlowy 迁移说明：原来代码块由多个 Line 子节点组成，本计划按行扫描；
// 块文档里代码块是单个节点（type 为 'code'），整块代码以 '\n' 分隔记在
// data.delta 里，因此“行”只是 delta 文本按 '\n' 切出的片段，规则本身不变：
// - 空白行（只有空格 / Tab 或为空）允许出现在代码中间；
// - 退出：光标所在行是本块最后一行、是空白行，且上一行（同块）也是空白行
//   时，把块尾连续的空白行全部收掉，在块后新起一个普通段落，光标落在行首；
//   整块都是空白行时代码块直接换成一个普通空段落；
// - 其余回车留在块内并自动缩进：沿用当前行的行首空白，光标在缩进中间时
//   只取光标之前的部分。
// 只接管“插入单个换行、没有选区”的情况；替换选区、粘贴多行与嵌入一律交还
// 默认链路，保持与正文其他位置一致的行为。

/// 回车改写计划：在代码块节点上执行 [transaction]，执行后选区为
/// [afterSelection]。调用方直接 `await editorState.apply(plan.transaction)`
/// 即可（apply 会按 transaction 的 afterSelection 更新选区）。
typedef DiaryCodeNewlinePlan = ({
  Transaction transaction,
  Selection afterSelection,
});

final RegExp _leadingWhitespace = RegExp(r'^[ \t]*');
final RegExp _blankLine = RegExp(r'^[ \t]*$');

/// [node] 是否为代码块（块文档 `type` 为 'code'）。
bool isDiaryCodeBlock(Node? node) =>
    node != null && node.type == kDiaryBlockCode;

/// [path] 处的节点；是代码块时返回它，否则返回 null。
///
/// 代码块是单个节点，不存在原来“行 → 父块”的查找。
Node? diaryCodeBlockAt(Document document, Path path) {
  final node = document.nodeAtPath(path);
  return isDiaryCodeBlock(node) ? node : null;
}

/// 选区 [selection] 触及的全部代码块，按文档顺序、去重。
///
/// 折叠选区只取光标所在节点的代码块。代码块不画子块（见
/// [kDiaryContainerBlockTypes]），只扫顶层节点即可。
List<Node> diaryCodeBlocksInRange(Document document, Selection selection) {
  final normalized = selection.normalized;
  final start = normalized.start.path;
  final end = normalized.end.path;
  final blocks = <Node>[];
  for (final node in document.root.children) {
    if (!isDiaryCodeBlock(node)) {
      continue;
    }
    final path = node.path;
    if (path >= start && path <= end) {
      blocks.add(node);
    }
  }
  return blocks;
}

/// 代码块的纯文本（各行以 '\n' 相连，不含末尾多余的换行）。
String diaryCodeBlockText(Node node) {
  final text = node.delta?.toPlainText() ?? '';
  return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
}

/// 计算代码块内回车的改写；不该接管时返回 null（走编辑器默认链路）。
///
/// 只处理 [node] 为代码块、[len] 为 0、[data] 恰为 `'\n'` 的插入；[offset]
/// 为块内 delta 偏移。[document] 用于构造返回的 [Transaction]。
DiaryCodeNewlinePlan? planDiaryCodeBlockNewline(
  Document document,
  Node node,
  int offset,
  int len,
  Object? data,
) {
  if (!isDiaryCodeBlock(node) || len != 0 || data is! String || data != '\n') {
    return null;
  }
  final delta = node.delta;
  if (delta == null) {
    return null;
  }
  final text = delta.toPlainText();
  if (offset < 0 || offset > text.length) {
    return null;
  }
  final lines = text.split('\n');
  // 各行在块内的起始偏移。
  final lineStarts = <int>[];
  var cursor = 0;
  for (final line in lines) {
    lineStarts.add(cursor);
    cursor += line.length + 1;
  }
  // offset 所在行：offset == 行尾时算在该行（光标在行尾、换行符之前）。
  var lineIndex = lines.length - 1;
  for (var i = 0; i < lines.length; i++) {
    if (offset <= lineStarts[i] + lines[i].length) {
      lineIndex = i;
      break;
    }
  }

  final transaction = Transaction(document: document);
  if (lineIndex == lines.length - 1 &&
      _blankLine.hasMatch(lines[lineIndex]) &&
      lineIndex > 0 &&
      _blankLine.hasMatch(lines[lineIndex - 1])) {
    // 退出：向上找到块尾连续空白行的第一行，收掉它们。
    var first = lineIndex - 1;
    while (first > 0 && _blankLine.hasMatch(lines[first - 1])) {
      first--;
    }
    if (first == 0) {
      // 整块都是空白行：代码块直接换成一个普通空段落。
      final path = node.path;
      transaction.deleteNode(node);
      transaction.insertNode(path, paragraphNode());
      final afterSelection = Selection.collapsed(
        Position(path: path, offset: 0),
      );
      transaction.afterSelection = afterSelection;
      return (transaction: transaction, afterSelection: afterSelection);
    }
    final blankStart = lineStarts[first];
    transaction.deleteText(node, blankStart, text.length - blankStart);
    final paragraphPath = node.path.next;
    transaction.insertNode(paragraphPath, paragraphNode());
    final afterSelection = Selection.collapsed(
      Position(path: paragraphPath, offset: 0),
    );
    transaction.afterSelection = afterSelection;
    return (transaction: transaction, afterSelection: afterSelection);
  }

  // 留在块内并自动缩进。语言记在节点属性上，文本插入不影响它；
  // 原来“新换行带上行属性”在块文档里没有对应物，不需要。
  final line = lines[lineIndex];
  final leading = _leadingWhitespace.stringMatch(line) ?? '';
  final column = offset - lineStarts[lineIndex];
  final indent = leading.substring(0, min(column, leading.length));
  final inserted = '\n$indent';
  transaction.insertText(node, offset, inserted);
  final afterSelection = Selection.collapsed(
    Position(path: node.path, offset: offset + inserted.length),
  );
  transaction.afterSelection = afterSelection;
  return (transaction: transaction, afterSelection: afterSelection);
}
