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
Future<void> insertDiaryTableBlock(EditorState editorState) async {
  final table = _tableNode(
    rows: _kDiaryTableDefaultRows,
    cols: _kDiaryTableDefaultCols,
  );
  final transaction = editorState.transaction;
  final selection = editorState.selection?.normalized;

  final Path insertPath;
  if (selection == null) {
    insertPath = [editorState.document.root.children.length];
  } else {
    final anchor = editorState.getNodeAtPath(selection.end.path);
    Node? enclosingTable;
    for (var current = anchor;
        current != null;
        current = current.parent) {
      if (current.type == TableBlockKeys.type) {
        enclosingTable = current;
        break;
      }
    }
    insertPath =
        enclosingTable?.path.next ??
        (anchor == null
            ? [editorState.document.root.children.length]
            : anchor.path.next);
  }

  transaction
    ..insertNode(insertPath, table)
    // 表格 → 第一个格子（行优先，第 0 行第 0 列）→ 格内段落的开头。
    ..afterSelection = Selection.collapsed(
      Position(path: [...insertPath, 0, 0]),
    );
  await editorState.apply(transaction);
}

/// 新表格节点：[rows]×[cols] 个空格子，每格一个空段落。
Node _tableNode({required int rows, required int cols}) => Node(
  type: TableBlockKeys.type,
  attributes: {
    TableBlockKeys.rowsLen: rows,
    TableBlockKeys.colsLen: cols,
  },
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
