import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/widgets/diary_callout_block/diary_callout_block.dart';

import '../../support/expressive_test_theme.dart';

/// v0.10.0 提示块：插入落点与属性、6 档底色只读渲染。

Node _paragraph(String text) => Node(
  type: kDiaryBlockParagraph,
  attributes: <String, dynamic>{
    kDiaryBlockDeltaKey: (Delta()..insert(text)).toJson(),
  },
);

Node _calloutNode(String color) => Node(
  type: kDiaryCalloutBlockType,
  attributes: <String, dynamic>{
    kDiaryBlockDeltaKey:
        (Delta()
              ..insert('hello ')
              ..insert('world', attributes: <String, dynamic>{'bold': true}))
            .toJson(),
    kDiaryCalloutBackgroundKey: color,
    kDiaryCalloutIconKey: '💡',
  },
);

EditorState _editorWithParagraph(String text, {int offset = 0}) {
  final editorState = EditorState(
    document: Document(
      root: Node(type: kDiaryBlockPage, children: <Node>[_paragraph(text)]),
    ),
  );
  editorState.selection = Selection.collapsed(
    Position(path: [0], offset: offset),
  );
  return editorState;
}

void main() {
  group('insertDiaryCalloutBlock', () {
    test('inserts a callout node after a non-empty paragraph', () async {
      final editorState = _editorWithParagraph('hello', offset: 5);
      await insertDiaryCalloutBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 2);
      final callout = children[1];
      expect(callout.type, kDiaryCalloutBlockType);
      expect(callout.attributes[kDiaryCalloutBackgroundKey], 'yellow');
      expect(callout.attributes[kDiaryCalloutIconKey], '💡');
      // 有 delta（正文文字）。
      expect(callout.delta, isNotNull);
    });

    test('replaces an empty paragraph instead of adding a new node', () async {
      final editorState = _editorWithParagraph('');
      await insertDiaryCalloutBlock(editorState);

      final children = editorState.document.root.children;
      expect(children.length, 1);
      expect(children.first.type, kDiaryCalloutBlockType);
      expect(children.first.attributes[kDiaryCalloutBackgroundKey], 'yellow');
    });

    test('moves the cursor into the inserted block', () async {
      final editorState = _editorWithParagraph('hello', offset: 5);
      await insertDiaryCalloutBlock(editorState);

      final selection = editorState.selection;
      expect(selection, isNotNull);
      expect(selection!.isCollapsed, isTrue);
      expect(selection.end.path, <int>[1]);
    });
  });

  group('DiaryCalloutBlockComponentBuilder', () {
    test('validate requires a delta', () {
      final builder = DiaryCalloutBlockComponentBuilder();
      expect(builder.validate(_calloutNode('yellow')), isTrue);
      expect(builder.validate(Node(type: kDiaryCalloutBlockType)), isFalse);
    });
  });

  group('DiaryCalloutBlockPreview', () {
    for (final brightness in Brightness.values) {
      for (final color in kDiaryCalloutColors) {
        testWidgets(
          'renders $color in ${brightness.name} mode without throwing',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                theme: expressiveTestTheme(brightness),
                home: Scaffold(
                  body: DiaryCalloutBlockPreview(
                    node: _calloutNode(color),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            );

            expect(find.text('💡'), findsOneWidget);
            expect(
              find.textContaining('hello', findRichText: true),
              findsOneWidget,
            );
            expect(
              find.textContaining('world', findRichText: true),
              findsOneWidget,
            );
          },
        );
      }
    }

    testWidgets('falls back to defaults on missing attributes', (tester) async {
      final node = Node(
        type: kDiaryCalloutBlockType,
        attributes: <String, dynamic>{
          kDiaryBlockDeltaKey: (Delta()..insert('text')).toJson(),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          home: Scaffold(
            body: DiaryCalloutBlockPreview(
              node: node,
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );

      // 默认图标 💡。
      expect(find.text('💡'), findsOneWidget);
      expect(find.textContaining('text', findRichText: true), findsOneWidget);
    });
  });
}
