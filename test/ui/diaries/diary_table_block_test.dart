import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_table_block.dart';

import '../../support/expressive_test_theme.dart';

/// v0.10.0 表格：插入与预览只读渲染。
Future<EditorState> _editorState({String? text}) async {
  final document = Document.blank(withInitialText: true);
  final editorState = EditorState(document: document);
  editorState.selection = Selection.collapsed(
    Position(path: [0], offset: text == null ? 0 : text.length),
  );
  if (text != null) {
    final transaction = editorState.transaction;
    transaction.insertText(document.root.children.first, 0, text);
    await editorState.apply(transaction);
  }
  return editorState;
}

/// 表格节点：指定行列数与每个格子的文字。
Node _tableNode(List<List<String>> rows) {
  return Node(
    type: TableBlockKeys.type,
    attributes: {
      TableBlockKeys.rowsLen: rows.length,
      TableBlockKeys.colsLen: rows.first.length,
    },
    children: [
      for (var r = 0; r < rows.length; r++)
        for (var c = 0; c < rows[r].length; c++)
          Node(
            type: TableCellBlockKeys.type,
            attributes: {
              TableCellBlockKeys.rowPosition: r,
              TableCellBlockKeys.colPosition: c,
            },
            children: [paragraphNode(text: rows[r][c])],
          ),
    ],
  );
}

Future<void> _pumpPreview(WidgetTester tester, Node table) =>
    tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: Scaffold(
          body: DiaryTableBlockPreview(
            node: table,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );

void main() {
  group('insertDiaryTableBlock', () {
    test('插入后文档里有 3x3 的 table 节点', () async {
      final editorState = await _editorState(text: 'hello');
      await insertDiaryTableBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 2);
      final table = children[1];
      expect(table.type, TableBlockKeys.type);
      expect(table.attributes[TableBlockKeys.rowsLen], 3);
      expect(table.attributes[TableBlockKeys.colsLen], 3);
      expect(table.children.length, 9);
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          final cell = table.children[row * 3 + col];
          expect(cell.type, TableCellBlockKeys.type);
          expect(cell.attributes[TableCellBlockKeys.rowPosition], row);
          expect(cell.attributes[TableCellBlockKeys.colPosition], col);
          // 每格一个空段落。
          expect(cell.children.length, 1);
          expect(cell.children.single.type, ParagraphBlockKeys.type);
          expect(cell.children.single.delta?.isEmpty, isTrue);
        }
      }
    });

    test('插入后光标进第一个 cell 的段落开头', () async {
      final editorState = await _editorState(text: 'hello');
      await insertDiaryTableBlock(editorState);

      final selection = editorState.selection;
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, isTrue);
      expect(selection.end.path, [1, 0, 0]);
      expect(selection.end.offset, 0);
    });

    test('光标在已有表格里时插到该表格后面', () async {
      final editorState = await _editorState();
      final table = _tableNode([
        ['a'],
      ]);
      final transaction = editorState.transaction
        ..insertNode([1], table);
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: const [1, 0, 0], offset: 1),
      );

      await insertDiaryTableBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 3);
      expect(children[1].type, TableBlockKeys.type);
      expect(children[1].attributes[TableBlockKeys.rowsLen], 1);
      expect(children[2].type, TableBlockKeys.type);
      expect(children[2].attributes[TableBlockKeys.rowsLen], 3);
      expect(editorState.selection?.end.path, [2, 0, 0]);
    });

    test('没有选区时插到文档末尾', () async {
      // 空文档（没有子块）：表格落在 [0]，光标进第一格。
      final editorState = EditorState(document: Document.blank());
      await insertDiaryTableBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 1);
      expect(children.last.type, TableBlockKeys.type);
      expect(editorState.selection?.end.path, [0, 0, 0]);
    });
  });

  group('DiaryTableBlockPreview', () {
    testWidgets('渲染格子文字与网格，不抛异常', (tester) async {
      await _pumpPreview(
        tester,
        _tableNode([
          ['r1c1', 'r1c2'],
          ['r2c1', 'r2c2'],
        ]),
      );

      expect(find.text('r1c1', findRichText: true), findsOneWidget);
      expect(find.text('r1c2', findRichText: true), findsOneWidget);
      expect(find.text('r2c1', findRichText: true), findsOneWidget);
      expect(find.text('r2c2', findRichText: true), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('空表格节点不占位、不抛异常', (tester) async {
      await _pumpPreview(
        tester,
        Node(type: TableBlockKeys.type),
      );

      expect(find.byType(Table), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('结构无效的表格不占位、不抛异常', (tester) async {
      // 位置重复：同一位置两格。
      final broken = Node(
        type: TableBlockKeys.type,
        attributes: {
          TableBlockKeys.rowsLen: 1,
          TableBlockKeys.colsLen: 1,
        },
        children: [
          Node(
            type: TableCellBlockKeys.type,
            attributes: {
              TableCellBlockKeys.rowPosition: 0,
              TableCellBlockKeys.colPosition: 0,
            },
            children: [paragraphNode(text: 'a')],
          ),
          Node(
            type: TableCellBlockKeys.type,
            attributes: {
              TableCellBlockKeys.rowPosition: 0,
              TableCellBlockKeys.colPosition: 0,
            },
            children: [paragraphNode(text: 'b')],
          ),
        ],
      );
      await _pumpPreview(tester, broken);

      expect(find.byType(Table), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('网格线用 outlineVariant、格内留白 8', (tester) async {
      await _pumpPreview(
        tester,
        _tableNode([
          ['x'],
        ]),
      );

      final table = tester.widget<Table>(find.byType(Table));
      final border = table.border as TableBorder;
      final outlineVariant = Theme.of(
        tester.element(find.byType(Table)),
      ).colorScheme.outlineVariant;
      expect(border.top.color, outlineVariant);
      expect(border.left.color, outlineVariant);

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('x', findRichText: true),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(8));
      expect(tester.takeException(), isNull);
    });
  });
}
