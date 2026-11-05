import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// v0.10.0 表格：AppFlowy 原生 `table` / `table/cell` 结构。
///
/// 插入只负责建 3×3 表格节点并把光标送进第一格；编辑期的可视与编辑走
/// standard map 的原生表格组件；预览页的只读渲染是 [DiaryTableBlockPreview]。
///
/// 表格节点（[TableBlockKeys.type]）的属性带 `colsLen` / `rowsLen`；每个格子
/// 是 [TableCellBlockKeys.type] 节点，属性带 `rowPosition` / `colPosition`
///（0 起），格子按行优先排列，格内是段落。

/// 新表格的默认行列数。
const int _kDiaryTableDefaultRows = 3;

/// 新表格的默认列数。
const int _kDiaryTableDefaultCols = 3;

/// 在光标所在块后面插入一个 3×3 表格，光标进第一格的段落开头。
///
/// 光标已在某个表格里时插到该表格后面（不把原表格拆开）；没有选区时插到
/// 文档末尾。一次事务完成，单步可撤销。
///
/// 表格后面总留一个能打字的块（v0.11.0 #125）：表格是一整块，光标出不了
/// 格子就写不了表格下面的内容。所以后面没有块、或紧跟的是媒体 / 分隔线
/// 这类没有文字的块时，在表格后面补一个空段落；手机上没有方向键，表格在
/// 文末时否则无法继续写。
Future<void> insertDiaryTableBlock(EditorState editorState) async {
  final table = _tableNode(
    rows: _kDiaryTableDefaultRows,
    cols: _kDiaryTableDefaultCols,
  );
  final transaction = editorState.transaction;
  final selection = editorState.selection?.normalized;

  final Path insertPath;
  Node? afterTable;
  if (selection == null) {
    insertPath = [editorState.document.root.children.length];
  } else {
    final anchor = editorState.getNodeAtPath(selection.end.path);
    Node? enclosingTable;
    for (var current = anchor; current != null; current = current.parent) {
      if (current.type == TableBlockKeys.type) {
        enclosingTable = current;
        break;
      }
    }
    final anchorNode = enclosingTable ?? anchor;
    insertPath = anchorNode == null
        ? [editorState.document.root.children.length]
        : anchorNode.path.next;
    // 插入位置之后的块：表格插进去后它就是表格的下一块。
    afterTable = anchorNode?.next;
  }

  transaction
    ..insertNode(insertPath, table)
    // 表格 → 第一个格子（行优先，第 0 行第 0 列）→ 格内段落的开头。
    ..afterSelection = Selection.collapsed(
      Position(path: [...insertPath, 0, 0]),
    );
  // 表格后面没有能直接打字的块时补一个空段落（与表格同一次事务）。
  if (!_isDiaryTextBlock(afterTable)) {
    transaction.insertNode(insertPath.next, paragraphNode());
  }
  await editorState.apply(transaction);
}

/// [node] 是能直接打字的块（带 delta 的文字块）。
bool _isDiaryTextBlock(Node? node) => node != null && node.delta != null;

/// 光标离开 [table] 到它后面的块开头：后面没有能打字的块时先补一个空
/// 段落（老数据里文末的表格）。[removing] 给出时在同一事务里删掉它
/// （格子最后一段的空行回车退出时，那个空行不留在格子里）。一步撤销。
Future<void> leaveDiaryTableBelow(
  EditorState editorState,
  Node table, {
  Node? removing,
}) async {
  final next = table.next;
  final transaction = editorState.transaction;
  if (_isDiaryTextBlock(next)) {
    if (removing == null) {
      await editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: next!.path)),
      );
      return;
    }
  } else {
    transaction.insertNode(table.path.next, paragraphNode());
  }
  if (removing != null) transaction.deleteNode(removing);
  // 删掉的是表格里的段落，表格自身的路径不变，紧跟它的块仍在 path.next。
  transaction.afterSelection = Selection.collapsed(
    Position(path: table.path.next),
  );
  await editorState.apply(transaction);
}

/// 表格最后一行格子末尾的空段落上回车：离开表格（v0.11.0 #125）。
///
/// 接管条件：折叠选区落在某格的段落上，该段是格子的最后一段、不是第一段、
/// 为空且没有子块，且格子在表格的最后一行。满足时删掉这个空段落，光标到
/// 表格后面的块（没有能打字的块时补一个空段落），与代码块“块尾空行回车
/// 退出”同理。接管成功返回 true，编辑器不再走默认换行；其余情况返回
/// false，继续走标准的格内换行。
Future<bool> handleDiaryTableExitEnter(EditorState editorState) async {
  final selection = editorState.selection?.normalized;
  if (selection == null || !selection.isCollapsed) return false;
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.type != ParagraphBlockKeys.type) return false;
  // 空段落：光标在段首段尾无所谓，空段的 offset 只能是 0。
  if (!(node.delta?.isEmpty ?? false) || node.children.isNotEmpty) {
    return false;
  }
  final cell = node.parent;
  if (cell == null || cell.type != TableCellBlockKeys.type) return false;
  // 不是格子的第一段、且是最后一段。
  if (identical(cell.children.first, node)) return false;
  if (!identical(cell.children.last, node)) return false;
  final table = cell.parent;
  if (table == null || table.type != TableBlockKeys.type) return false;
  final rows = table.attributes[TableBlockKeys.rowsLen];
  final row = cell.attributes[TableCellBlockKeys.rowPosition];
  if (rows is! num || row is! num) return false;
  // 只在最后一行的格子上退出。
  if (row.toInt() != rows.toInt() - 1) return false;
  await leaveDiaryTableBelow(editorState, table, removing: node);
  return true;
}

/// 新表格节点：[rows]×[cols] 个空格子，每格一个空段落。
Node _tableNode({required int rows, required int cols}) => Node(
  type: TableBlockKeys.type,
  attributes: {TableBlockKeys.rowsLen: rows, TableBlockKeys.colsLen: cols},
  children: [
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++)
        Node(
          type: TableCellBlockKeys.type,
          attributes: {
            TableCellBlockKeys.rowPosition: row,
            TableCellBlockKeys.colPosition: col,
          },
          children: [paragraphNode()],
        ),
  ],
);

/// 预览页用的表格渲染（只读）。
///
/// 表格铺满整行、各列等宽、不横向滚动（与上游 v0.10.0 一致）；网格线用
/// [ColorScheme.outlineVariant]，格内留白 8。
class DiaryTableBlockPreview extends StatelessWidget {
  const DiaryTableBlockPreview({
    super.key,
    required this.node,
    required this.textStyle,
  });

  final Node node;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final grid = _TableGrid.of(node);
    if (grid == null) return const SizedBox.shrink();
    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder.all(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      children: [
        for (var row = 0; row < grid.rows; row++)
          TableRow(
            children: [
              for (var col = 0; col < grid.cols; col++)
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text.rich(_cellSpan(grid.cells[row][col])),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// 一格的文字：格内所有段落的 delta 按纯文本拼成一个 TextSpan。
  TextSpan _cellSpan(Node cell) {
    final buffer = StringBuffer();
    for (final child in cell.children) {
      final delta = child.delta;
      if (delta == null) continue;
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(delta.toPlainText());
    }
    final text = buffer.toString();
    // 空格子也要占一行高度，否则该行会被压掉。
    return TextSpan(text: text.isEmpty ? ' ' : text, style: textStyle);
  }
}

/// 表格的网格视图：`cells[行][列]`。
///
/// 只认结构有效的表格（每个位置恰好一格、行列数与格数相符）；读不出时为
/// null，预览直接不占位，避免画出半截表格。
class _TableGrid {
  const _TableGrid._({
    required this.rows,
    required this.cols,
    required this.cells,
  });

  final int rows;
  final int cols;
  final List<List<Node>> cells;

  static int? _index(Object? value) =>
      value is num && value.isFinite && value >= 0 && value == value.truncate()
      ? value.toInt()
      : null;

  static _TableGrid? of(Node node) {
    if (node.type != TableBlockKeys.type) return null;
    final positioned = <_PositionedCell>[];
    for (final child in node.children) {
      if (child.type != TableCellBlockKeys.type) return null;
      final row = _index(child.attributes[TableCellBlockKeys.rowPosition]);
      final col = _index(child.attributes[TableCellBlockKeys.colPosition]);
      if (row == null || col == null) return null;
      positioned.add(_PositionedCell(row: row, col: col, cell: child));
    }
    if (positioned.isEmpty) return null;
    var rows = _index(node.attributes[TableBlockKeys.rowsLen]) ?? 0;
    var cols = _index(node.attributes[TableBlockKeys.colsLen]) ?? 0;
    if (rows <= 0 || cols <= 0) {
      // 属性缺失或非法时按格子位置推导行列数。
      rows = positioned.map((p) => p.row).reduce(math.max) + 1;
      cols = positioned.map((p) => p.col).reduce(math.max) + 1;
    }
    final cells = List.generate(rows, (_) => List<Node?>.filled(cols, null));
    for (final p in positioned) {
      if (p.row >= rows || p.col >= cols || cells[p.row][p.col] != null) {
        return null;
      }
      cells[p.row][p.col] = p.cell;
    }
    return _TableGrid._(
      rows: rows,
      cols: cols,
      cells: [
        for (final rowCells in cells) [for (final cell in rowCells) cell!],
      ],
    );
  }
}

class _PositionedCell {
  const _PositionedCell({
    required this.row,
    required this.col,
    required this.cell,
  });

  final int row;
  final int col;
  final Node cell;
}
