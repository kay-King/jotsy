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

Future<void> _pumpPreview(WidgetTester tester, Node table) => tester.pumpWidget(
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
    test('插入后文档里有 3x3 的 table 节点，表格后补一个空段落', () async {
      final editorState = await _editorState(text: 'hello');
      await insertDiaryTableBlock(editorState);

      final children = editorState.document.root.children;
      // 正文段落 + 表格 + 表格后补的空段落（v0.11.0 #125：表格后总留可写段落）。
      expect(children.length, 3);
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
      // 补的空段落是普通段落、在表格后面。
      expect(children[2].type, ParagraphBlockKeys.type);
      expect(children[2].delta?.isEmpty, isTrue);
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
      final transaction = editorState.transaction..insertNode([1], table);
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: const [1, 0, 0], offset: 1),
      );

      await insertDiaryTableBlock(editorState);

      final children = editorState.document.root.children;
      // 空段落 + 旧表格 + 新表格 + 新表格后补的空段落。
      expect(children.length, 4);
      expect(children[1].type, TableBlockKeys.type);
      expect(children[1].attributes[TableBlockKeys.rowsLen], 1);
      expect(children[2].type, TableBlockKeys.type);
      expect(children[2].attributes[TableBlockKeys.rowsLen], 3);
      expect(children[3].type, ParagraphBlockKeys.type);
      expect(children[3].delta?.isEmpty, isTrue);
      expect(editorState.selection?.end.path, [2, 0, 0]);
    });

    test('没有选区时插到文档末尾，表格后补一个空段落', () async {
      // 空文档（没有子块）：表格落在 [0]，光标进第一格。
      final editorState = EditorState(document: Document.blank());
      await insertDiaryTableBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 2);
      expect(children.first.type, TableBlockKeys.type);
      expect(children.last.type, ParagraphBlockKeys.type);
      expect(children.last.delta?.isEmpty, isTrue);
      expect(editorState.selection?.end.path, [0, 0, 0]);
    });

    test('表格后面已有正文段落时不补空段落', () async {
      final editorState = await _editorState(text: 'hello');
      // 在文末再加一个正文段落：表格插在第一段后面、第二段前面。
      final transaction = editorState.transaction
        ..insertNode([1], paragraphNode(text: 'after'));
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: [0], offset: 5),
      );

      await insertDiaryTableBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 3);
      expect(children[0].type, ParagraphBlockKeys.type);
      expect(children[1].type, TableBlockKeys.type);
      // 紧跟的是原有正文段落，不补。
      expect(children[2].type, ParagraphBlockKeys.type);
      expect(children[2].delta?.toPlainText(), 'after');
    });
  });

  group('handleDiaryTableExitEnter', () {
    Future<EditorState> editorWithTable({
      required List<List<String>> rows,
      required List<int> caretPath,
      int caretOffset = 0,
    }) async {
      final editorState = await _editorState();
      final table = _tableNode(rows);
      final transaction = editorState.transaction..insertNode([1], table);
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: caretPath, offset: caretOffset),
      );
      return editorState;
    }

    test('最后一行格子末尾的空段落上回车：删掉空行、光标到表格后', () async {
      // 2 行 1 列：第二行格子追加一个空段落，光标落在它上面。
      final editorState = await editorWithTable(
        rows: [
          ['a'],
          ['b'],
        ],
        caretPath: const [1, 1, 0],
      );
      final table = editorState.document.root.children[1];
      final lastCell = table.children[1];
      final transaction = editorState.transaction
        ..insertNode([1, 1, 1], paragraphNode());
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: [1, 1, 1], offset: 0),
      );
      expect(lastCell.children.length, 2);

      final handled = await handleDiaryTableExitEnter(editorState);

      expect(handled, isTrue);
      final children = editorState.document.root.children;
      // 空段落 + 表格 + 表格后补的空段落（回车退出时没有则补）。
      expect(children.length, 3);
      expect(children[1], same(table));
      expect(children[2].type, ParagraphBlockKeys.type);
      expect(children[2].delta?.isEmpty, isTrue);
      // 格子里那个空段落已被删掉。
      expect(lastCell.children.length, 1);
      expect(editorState.selection?.end.path, [2]);
      expect(editorState.selection?.end.offset, 0);
    });

    test('最后一行格子末尾的空段落上回车：表格后已有段落时直接过去', () async {
      final editorState = await editorWithTable(
        rows: [
          ['a'],
          ['b'],
        ],
        caretPath: const [1, 1, 0],
      );
      final transaction = editorState.transaction
        ..insertNode([1, 1, 1], paragraphNode())
        ..insertNode([2], paragraphNode(text: 'after'));
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: [1, 1, 1], offset: 0),
      );

      final handled = await handleDiaryTableExitEnter(editorState);

      expect(handled, isTrue);
      final children = editorState.document.root.children;
      expect(children.length, 3);
      expect(children[2].delta?.toPlainText(), 'after');
      expect(editorState.selection?.end.path, [2]);
    });

    test('非最后一行格子的空段落上回车不接管', () async {
      final editorState = await editorWithTable(
        rows: [
          ['a'],
          ['b'],
        ],
        caretPath: const [1, 0, 0],
      );
      final table = editorState.document.root.children[1];
      final firstCell = table.children[0];
      final transaction = editorState.transaction
        ..insertNode([1, 0, 1], paragraphNode());
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: [1, 0, 1], offset: 0),
      );

      final handled = await handleDiaryTableExitEnter(editorState);

      expect(handled, isFalse);
      expect(firstCell.children.length, 2);
    });

    test('格子第一段上回车不接管', () async {
      final editorState = await editorWithTable(
        rows: [
          ['a'],
          ['b'],
        ],
        caretPath: const [1, 1, 0],
      );

      // 光标在最后一行格子的第一段（有文字）：不接管。
      editorState.selection = Selection.collapsed(
        Position(path: [1, 1, 0], offset: 1),
      );

      final handled = await handleDiaryTableExitEnter(editorState);

      expect(handled, isFalse);
    });

    test('格子末尾段落非空时回车不接管', () async {
      final editorState = await editorWithTable(
        rows: [
          ['a'],
          ['b'],
        ],
        caretPath: const [1, 1, 0],
      );
      final table = editorState.document.root.children[1];
      final lastCell = table.children[1];
      final transaction = editorState.transaction
        ..insertNode([1, 1, 1], paragraphNode(text: 'x'));
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: [1, 1, 1], offset: 1),
      );

      final handled = await handleDiaryTableExitEnter(editorState);

      expect(handled, isFalse);
      expect(lastCell.children.length, 2);
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
      await _pumpPreview(tester, Node(type: TableBlockKeys.type));

      expect(find.byType(Table), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('结构无效的表格不占位、不抛异常', (tester) async {
      // 位置重复：同一位置两格。
      final broken = Node(
        type: TableBlockKeys.type,
        attributes: {TableBlockKeys.rowsLen: 1, TableBlockKeys.colsLen: 1},
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
