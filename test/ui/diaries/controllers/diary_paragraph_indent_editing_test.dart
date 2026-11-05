import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/controllers/diary_paragraph_indent_editing.dart';

/// 工具栏「缩进」作用在正文段落上时只缩进首行（v0.11.0 #122）：
/// 全是正文段落时写 `firstLineIndent` 标记，不嵌套；列表、待办、表格格子
/// 里的段落仍走嵌套缩进。

EditorState _editorState(List<Node> children) {
  final document = Document(
    root: Node(type: 'page', children: children),
  );
  return EditorState(document: document);
}

Node _paragraph(String text, {Map<String, dynamic>? attributes}) {
  return paragraphNode(text: text, attributes: attributes);
}

Node _bulleted(String text) => bulletedListNode(text: text);

void main() {
  group('diaryFirstLineIndentTargets', () {
    test('全是正文段落时返回这些段落', () {
      final editorState = _editorState([_paragraph('第一段'), _paragraph('第二段')]);
      editorState.selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [1], offset: 3),
      );

      final targets = diaryFirstLineIndentTargets(editorState);

      expect(targets, isNotNull);
      expect(targets!.length, 2);
    });

    test('选区里有列表时返回 null（走嵌套缩进）', () {
      final editorState = _editorState([_paragraph('第一段'), _bulleted('列表项')]);
      editorState.selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [1], offset: 3),
      );

      expect(diaryFirstLineIndentTargets(editorState), isNull);
    });

    test('段落在表格格子里时返回 null', () {
      final table = Node(
        type: TableBlockKeys.type,
        attributes: {TableBlockKeys.rowsLen: 1, TableBlockKeys.colsLen: 1},
        children: [
          Node(
            type: TableCellBlockKeys.type,
            attributes: {
              TableCellBlockKeys.rowPosition: 0,
              TableCellBlockKeys.colPosition: 0,
            },
            children: [_paragraph('格子')],
          ),
        ],
      );
      final editorState = _editorState([table]);
      editorState.selection = Selection.collapsed(
        Position(path: [0, 0, 0], offset: 1),
      );

      expect(diaryFirstLineIndentTargets(editorState), isNull);
    });

    test('没有选区时返回 null', () {
      final editorState = _editorState([_paragraph('第一段')]);
      expect(diaryFirstLineIndentTargets(editorState), isNull);
    });
  });

  group('diaryNodeInTableCell', () {
    test('格子里的段落为 true，顶层段落为 false', () {
      final editorState = _editorState([
        _paragraph('顶层'),
        Node(
          type: TableBlockKeys.type,
          attributes: {TableBlockKeys.rowsLen: 1, TableBlockKeys.colsLen: 1},
          children: [
            Node(
              type: TableCellBlockKeys.type,
              attributes: {
                TableCellBlockKeys.rowPosition: 0,
                TableCellBlockKeys.colPosition: 0,
              },
              children: [_paragraph('格子')],
            ),
          ],
        ),
      ]);
      final root = editorState.document.root;
      expect(diaryNodeInTableCell(root.children[0]), isFalse);
      expect(
        diaryNodeInTableCell(root.children[1].children[0].children[0]),
        isTrue,
      );
    });
  });

  group('indentDiaryFirstLine / outdentDiaryFirstLine', () {
    test('缩进给段落写标记，已标记的不重复写', () async {
      final editorState = _editorState([
        _paragraph('第一段'),
        _paragraph('第二段', attributes: {kDiaryParagraphIndentKey: true}),
      ]);
      editorState.selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [1], offset: 3),
      );
      final targets = diaryFirstLineIndentTargets(editorState)!;

      expect(canIndentDiaryFirstLine(targets), isTrue);
      await indentDiaryFirstLine(editorState, targets);

      final children = editorState.document.root.children;
      expect(diaryParagraphHasFirstLineIndent(children[0]), isTrue);
      expect(diaryParagraphHasFirstLineIndent(children[1]), isTrue);
      expect(canIndentDiaryFirstLine(targets), isFalse);
    });

    test('取消缩进清掉标记', () async {
      final editorState = _editorState([
        _paragraph('第一段', attributes: {kDiaryParagraphIndentKey: true}),
        _paragraph('第二段', attributes: {kDiaryParagraphIndentKey: true}),
      ]);
      editorState.selection = Selection(
        start: Position(path: [0], offset: 0),
        end: Position(path: [1], offset: 3),
      );
      final targets = diaryFirstLineIndentTargets(editorState)!;

      expect(canOutdentDiaryFirstLine(editorState, targets), isTrue);
      await outdentDiaryFirstLine(editorState, targets);

      final children = editorState.document.root.children;
      expect(diaryParagraphHasFirstLineIndent(children[0]), isFalse);
      expect(diaryParagraphHasFirstLineIndent(children[1]), isFalse);
      // 标记已清掉，attributes 里不再留这个键。
      expect(
        children[0].attributes.containsKey(kDiaryParagraphIndentKey),
        isFalse,
      );
    });

    test('没有标记的嵌套段落取消缩进时提回上一层', () async {
      final parent = _paragraph('父段');
      final child = _paragraph('子段');
      final editorState = _editorState([parent]);
      // 把子段挂成父段的子块（旧版嵌套缩进的样子）。
      final transaction = editorState.transaction..insertNode([0, 0], child);
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: [0, 0], offset: 0),
      );
      // 选区在子段上：它是段落但不在顶层，targets 仍认（不在表格里）。
      final targets = diaryFirstLineIndentTargets(editorState)!;
      expect(targets.length, 1);

      await outdentDiaryFirstLine(editorState, targets);

      // 子段被提回顶层，成为根的第二个孩子。
      final children = editorState.document.root.children;
      expect(children.length, 2);
      expect(children[1].delta?.toPlainText(), '子段');
    });
  });
}
