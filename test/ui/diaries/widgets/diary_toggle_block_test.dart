import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toggle_block/diary_toggle_block.dart';

import '../../../support/expressive_test_theme.dart';

/// v0.10.0 折叠块（toggle list）：插入、编辑器交互与只读预览。

Node _paragraph(String text) => Node(
  type: kDiaryBlockParagraph,
  attributes: <String, dynamic>{
    kDiaryBlockDeltaKey: (Delta()..insert(text)).toJson(),
  },
);

Node _toggleNode({
  String title = '',
  List<Node> children = const [],
  bool collapsed = false,
}) {
  final delta = Delta();
  if (title.isNotEmpty) {
    delta.insert(title);
  }
  return Node(
    type: kDiaryToggleBlockType,
    attributes: <String, dynamic>{
      kDiaryToggleCollapsedKey: collapsed,
      kDiaryBlockDeltaKey: delta.toJson(),
    },
    children: children,
  );
}

/// 光标落在 [text] 段落的行尾（blank 自带一个空段落）。
Future<EditorState> _editorState({String? text}) async {
  final editorState = EditorState.blank(withInitialText: true);
  addTearDown(editorState.dispose);
  editorState.selection = Selection.collapsed(
    Position(path: [0], offset: text == null ? 0 : text.length),
  );
  if (text != null) {
    final transaction = editorState.transaction;
    transaction.insertText(editorState.document.root.children.first, 0, text);
    await editorState.apply(transaction);
  }
  return editorState;
}

Future<void> _pumpEditor(WidgetTester tester, EditorState editorState) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: Scaffold(
        body: AppFlowyEditor(
          editorState: editorState,
          editorStyle: EditorStyle.mobile(),
          blockComponentBuilders: <String, BlockComponentBuilder>{
            ...standardBlockComponentBuilderMap,
            kDiaryToggleBlockType: DiaryToggleBlockComponentBuilder(),
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPreview(WidgetTester tester, Node node) => tester.pumpWidget(
  MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    home: Scaffold(
      body: DiaryToggleBlockPreview(
        node: node,
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
  ),
);

/// 箭头 FaIcon 带 `ValueKey<bool>(collapsed)`；按 key 找，不依赖图标数据比对
///（FaIcon.icon 返回的是内部 IconData，不是 FaIconData）。
Finder _arrowIcon(bool collapsed) => find.byKey(ValueKey<bool>(collapsed));

void main() {
  group('insertDiaryToggleBlock', () {
    test('插到光标段落后：类型/属性/空标题/无子块，光标进标题开头', () async {
      final editorState = await _editorState(text: 'hello');

      await insertDiaryToggleBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 2);
      final toggle = children[1];
      expect(toggle.type, kDiaryToggleBlockType);
      expect(toggle.attributes[kDiaryToggleCollapsedKey], false);
      expect(toggle.delta, isNotNull);
      expect(toggle.children, isEmpty);
      final selection = editorState.selection;
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, isTrue);
      expect(selection.end.path, [1]);
      expect(selection.end.offset, 0);
    });

    test('无选区时插到文档末尾', () async {
      final editorState = EditorState.blank(withInitialText: true);
      addTearDown(editorState.dispose);
      // 段落里有字但无选区。
      final transaction = editorState.transaction;
      transaction.insertText(
        editorState.document.root.children.first,
        0,
        'hello',
      );
      await editorState.apply(transaction);

      await insertDiaryToggleBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.last.type, kDiaryToggleBlockType);
      expect(editorState.selection?.end.path, [1]);
    });

    test('插入是可撤销的一步事务', () async {
      // 直接构造文档：避免 helper 里的 insertText 事务与插入事务在
      // undo 的防抖窗口内合并成一步。
      final editorState = EditorState(
        document: Document(
          root: Node(type: kDiaryBlockPage, children: [_paragraph('hello')]),
        ),
      );
      addTearDown(editorState.dispose);
      editorState.selection = Selection.collapsed(
        Position(path: [0], offset: 5),
      );

      await insertDiaryToggleBlock(editorState);
      expect(editorState.document.root.children.length, 2);
      editorState.undoManager.undo();
      expect(editorState.document.root.children.length, 1);
      expect(
        editorState.document.root.children.single.delta?.toPlainText(),
        'hello',
      );
    });
  });

  group('DiaryToggleBlockComponentBuilder.validate', () {
    test('无 delta 的节点非法', () {
      final builder = DiaryToggleBlockComponentBuilder();
      expect(builder.validate(Node(type: kDiaryToggleBlockType)), isFalse);
    });

    test('有 delta 的节点合法', () {
      final builder = DiaryToggleBlockComponentBuilder();
      expect(builder.validate(_toggleNode(title: 't')), isTrue);
    });
  });

  group('编辑器折叠块', () {
    testWidgets('渲染标题与子块，点箭头收起/展开', (tester) async {
      final editorState = EditorState(
        document: Document(
          root: Node(
            type: kDiaryBlockPage,
            children: <Node>[
              _toggleNode(title: '标题', children: [_paragraph('子内容')]),
              _paragraph('尾段'),
            ],
          ),
        ),
      );
      addTearDown(editorState.dispose);
      await _pumpEditor(tester, editorState);
      final toggle = editorState.document.root.children.first;

      expect(find.text('标题', findRichText: true), findsOneWidget);
      expect(find.text('子内容', findRichText: true), findsOneWidget);
      expect(_arrowIcon(false), findsOneWidget);

      // 点箭头收起：属性翻转，子块不进渲染树但保留在文档里。
      await tester.tap(_arrowIcon(false));
      await tester.pumpAndSettle();
      expect(toggle.attributes[kDiaryToggleCollapsedKey], isTrue);
      expect(find.text('子内容', findRichText: true), findsNothing);
      expect(find.text('标题', findRichText: true), findsOneWidget);
      expect(toggle.children.length, 1);

      // 再点展开：子块回来。
      await tester.tap(_arrowIcon(true));
      await tester.pumpAndSettle();
      expect(toggle.attributes[kDiaryToggleCollapsedKey], isFalse);
      expect(find.text('子内容', findRichText: true), findsOneWidget);
      // 推进时间：清掉 undoManager 的防抖 seal 计时器，避免 teardown 断言。
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('收起/展开可撤销', (tester) async {
      final editorState = EditorState(
        document: Document(
          root: Node(
            type: kDiaryBlockPage,
            children: <Node>[_toggleNode(title: '标题')],
          ),
        ),
      );
      addTearDown(editorState.dispose);
      await _pumpEditor(tester, editorState);
      final toggle = editorState.document.root.children.first;

      await tester.tap(_arrowIcon(false));
      await tester.pumpAndSettle();
      expect(toggle.attributes[kDiaryToggleCollapsedKey], isTrue);

      editorState.undoManager.undo();
      await tester.pump();
      expect(toggle.attributes[kDiaryToggleCollapsedKey], isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryToggleBlockPreview', () {
    testWidgets('渲染标题与子块文字', (tester) async {
      await _pumpPreview(
        tester,
        _toggleNode(title: '标题', children: [_paragraph('子内容')]),
      );

      expect(find.text('标题', findRichText: true), findsOneWidget);
      expect(find.text('子内容', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点箭头收起/展开只改本地状态、不改文档', (tester) async {
      final node = _toggleNode(title: '标题', children: [_paragraph('子内容')]);
      await _pumpPreview(tester, node);

      await tester.tap(_arrowIcon(false));
      await tester.pumpAndSettle();
      expect(find.text('子内容', findRichText: true), findsNothing);
      expect(find.text('标题', findRichText: true), findsOneWidget);
      // 文档属性没动。
      expect(node.attributes[kDiaryToggleCollapsedKey], isFalse);

      await tester.tap(_arrowIcon(true));
      await tester.pumpAndSettle();
      expect(find.text('子内容', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collapsed=true 的节点初始即收起', (tester) async {
      await _pumpPreview(
        tester,
        _toggleNode(
          title: '标题',
          children: [_paragraph('子内容')],
          collapsed: true,
        ),
      );

      expect(find.text('标题', findRichText: true), findsOneWidget);
      expect(find.text('子内容', findRichText: true), findsNothing);
      expect(_arrowIcon(true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('嵌套子块递归渲染、空标题不抛异常', (tester) async {
      await _pumpPreview(
        tester,
        _toggleNode(
          children: [
            _paragraph('一级'),
            _toggleNode(title: '嵌套折叠', children: [_paragraph('二级')]),
          ],
        ),
      );

      expect(find.text('一级', findRichText: true), findsOneWidget);
      expect(find.text('嵌套折叠', findRichText: true), findsOneWidget);
      expect(find.text('二级', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('行内格式（加粗/颜色/字号）生效', (tester) async {
      final delta = Delta()
        ..insert('粗', attributes: {kDiaryInlineBold: true})
        ..insert('色', attributes: {kDiaryInlineTextColor: '#FFFF0000'})
        ..insert('大', attributes: {kDiaryInlineSize: 'large'});
      final node = Node(
        type: kDiaryToggleBlockType,
        attributes: <String, dynamic>{
          kDiaryToggleCollapsedKey: false,
          kDiaryBlockDeltaKey: delta.toJson(),
        },
      );
      await _pumpPreview(tester, node);

      // FaIcon 内部也是 RichText，按标题文字精确定位。
      final richText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) =>
              w is RichText && (w.text as TextSpan).toPlainText().contains('粗'),
        ),
      );
      final span = richText.text as TextSpan;
      expect(span.children!.length, 3);
      final bold = span.children![0] as TextSpan;
      expect(bold.text, '粗');
      expect(bold.style?.fontWeight, FontWeight.bold);
      final colored = span.children![1] as TextSpan;
      expect(colored.style?.color, const Color(0xFFFF0000));
      final large = span.children![2] as TextSpan;
      expect(large.style?.fontSize, 16.0 * 1.25);
      expect(tester.takeException(), isNull);
    });
  });
}
