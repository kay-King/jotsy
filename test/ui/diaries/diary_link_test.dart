import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link_card/diary_link_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link_card/diary_link_card_view.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mention/diary_mention_trigger.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_backlinks.dart';

import '../../support/expressive_test_theme.dart';

/// v0.10.0 日记链接：@ 提及插入、卡片块、反向链接查询。

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

/// 带 `diary://targetId` 行内链接的正文 JSON。
Future<String> _contentWithDiaryLink(String targetId) async {
  final editorState = EditorState(
    document: Document.blank(withInitialText: true),
  );
  final node = editorState.document.root.children.first;
  // 同一事务里第二次 insertText 的下标按 apply 前的 delta 校验，分两次写。
  final first = editorState.transaction;
  first.insertText(node, 0, '读到');
  await editorState.apply(first);
  final second = editorState.transaction;
  second.insertText(
    node,
    2,
    '这篇',
    attributes: <String, dynamic>{
      kDiaryInlineHref: diaryLinkHrefForDiary(targetId),
    },
  );
  await editorState.apply(second);
  return jsonEncode(editorState.document.toJson());
}

/// 带指向 targetId 的日记卡片块的正文 JSON。
Future<String> _contentWithLinkCard(String targetId) async {
  final editorState = EditorState(
    document: Document.blank(withInitialText: true),
  );
  final transaction = editorState.transaction;
  transaction.insertNode(const [1], diaryLinkCardNode(targetId));
  await editorState.apply(transaction);
  return jsonEncode(editorState.document.toJson());
}

Diary _row(String diaryId, String content) => Diary(
  id: diaryId.hashCode,
  diaryId: diaryId,
  title: '标题 $diaryId',
  content: content,
  contentText: '',
  metadata: '{}',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 2),
  isArchived: false,
  isPinned: false,
  isDeleted: false,
);

void main() {
  group('parseMentionTrigger', () {
    test('行首 @ 触发，query 为 @ 之后文字', () {
      final trigger = parseMentionTrigger('@ab');
      expect(trigger, isNotNull);
      expect(trigger!.kind, MentionTriggerKind.mention);
      expect(trigger.query, 'ab');
      expect(trigger.triggerOffset, 0);
    });

    test('@ 前是空格时触发', () {
      final trigger = parseMentionTrigger('hello @ab');
      expect(trigger, isNotNull);
      expect(trigger!.query, 'ab');
      expect(trigger.triggerOffset, 6);
    });

    test('邮箱式的 a@b 不触发', () {
      expect(parseMentionTrigger('a@b'), isNull);
    });

    test('@ 后跟空格时不触发', () {
      expect(parseMentionTrigger('hello @ '), isNull);
    });

    test('普通文字不触发', () {
      expect(parseMentionTrigger('hello world'), isNull);
    });

    test('行首 / 触发块菜单', () {
      final trigger = parseMentionTrigger('/');
      expect(trigger, isNotNull);
      expect(trigger!.kind, MentionTriggerKind.slash);
      expect(trigger.query, '');
    });

    test('https:// 里的 / 不触发', () {
      expect(parseMentionTrigger('https://'), isNull);
    });

    test('a/b 不触发', () {
      expect(parseMentionTrigger('a/b'), isNull);
    });
  });

  group('diary link href', () {
    test('日记 href 编解码往返', () {
      final href = diaryLinkHrefForDiary('d1');
      expect(href, 'diary://d1');
      final parsed = parseDiaryLinkHref(href);
      expect(parsed?.diaryId, 'd1');
      expect(parsed?.notebookId, isNull);
    });

    test('日记本 href 编解码往返', () {
      final href = diaryLinkHrefForNotebook('n1');
      expect(href, 'notebook://n1');
      final parsed = parseDiaryLinkHref(href);
      expect(parsed?.notebookId, 'n1');
      expect(parsed?.diaryId, isNull);
    });

    test('普通链接返回 null', () {
      expect(parseDiaryLinkHref('https://example.com'), isNull);
    });
  });

  group('applyMentionPick', () {
    test('@ 选中后删掉 @query 并插入带 href 的标题', () async {
      final editorState = await _editorState(text: 'hello @ab');
      final node = editorState.document.root.children.first;
      final trigger = parseMentionTrigger('hello @ab')!;
      await applyMentionPick(
        editorState: editorState,
        node: node,
        trigger: trigger,
        displayText: 'AB日记',
        href: diaryLinkHrefForDiary('d1'),
      );
      expect(node.delta!.toPlainText(), 'hello AB日记');
      final linked = node.delta!.whereType<TextInsert>().firstWhere(
        (op) => op.text == 'AB日记',
      );
      expect(linked.attributes?[kDiaryInlineHref], 'diary://d1');
    });

    test('日记本提及插入 notebook:// 链接', () async {
      final editorState = await _editorState(text: '@');
      final node = editorState.document.root.children.first;
      final trigger = parseMentionTrigger('@')!;
      await applyMentionPick(
        editorState: editorState,
        node: node,
        trigger: trigger,
        displayText: '工作',
        href: diaryLinkHrefForNotebook('n1'),
      );
      expect(node.delta!.toPlainText(), '工作');
      final linked = node.delta!.whereType<TextInsert>().firstWhere(
        (op) => op.text == '工作',
      );
      expect(linked.attributes?[kDiaryInlineHref], 'notebook://n1');
    });
  });

  group('diary link card block', () {
    test('空段落被卡片替换，不留空行', () async {
      final editorState = await _editorState();
      await insertDiaryLinkCardBlock(editorState, diaryId: 'd1');
      final children = editorState.document.root.children;
      expect(children, hasLength(1));
      expect(children.first.type, kDiaryLinkCardBlockType);
      expect(diaryLinkCardDiaryId(children.first), 'd1');
    });

    test('非空段落后插入卡片', () async {
      final editorState = await _editorState(text: 'abc');
      await insertDiaryLinkCardBlock(editorState, diaryId: 'd2');
      final children = editorState.document.root.children;
      expect(children, hasLength(2));
      expect(children.first.delta!.toPlainText(), 'abc');
      expect(children[1].type, kDiaryLinkCardBlockType);
      expect(diaryLinkCardDiaryId(children[1]), 'd2');
    });

    test('类型不对或属性缺失时 diaryLinkCardDiaryId 返回 null', () {
      expect(diaryLinkCardDiaryId(paragraphNode(text: 'x')), isNull);
      expect(
        diaryLinkCardDiaryId(
          Node(type: kDiaryLinkCardBlockType, attributes: const {}),
        ),
        isNull,
      );
    });
  });

  group('findDiaryBacklinks', () {
    test('行内 diary:// 链接算提到', () async {
      final rows = [
        _row('target', await _contentWithDiaryLink('other')),
        _row('a', await _contentWithDiaryLink('target')),
        _row('b', await _contentWithDiaryLink('other')),
      ];
      final backlinks = findDiaryBacklinks(rows, 'target');
      expect(backlinks.map((e) => e.diaryId), ['a']);
    });

    test('日记卡片块指向也算提到', () async {
      final rows = [
        _row('target', await _contentWithDiaryLink('other')),
        _row('c', await _contentWithLinkCard('target')),
      ];
      final backlinks = findDiaryBacklinks(rows, 'target');
      expect(backlinks.map((e) => e.diaryId), ['c']);
    });

    test('坏正文不抛异常，直接跳过', () {
      final rows = [_row('target', '{}'), _row('d', 'not json at all{{{')];
      expect(() => findDiaryBacklinks(rows, 'target'), returnsNormally);
      expect(findDiaryBacklinks(rows, 'target'), isEmpty);
    });
  });

  group('DiaryLinkCardView', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      String? title,
      String? missingLabel,
      VoidCallback? onTap,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        home: Scaffold(
          body: DiaryLinkCardView(
            title: title,
            dateLabel: '2026年11月1日',
            summary: '摘要内容',
            missingLabel: missingLabel,
            onTap: onTap,
          ),
        ),
      ),
    );

    testWidgets('渲染标题日期摘要，点按回调', (WidgetTester tester) async {
      var tapped = false;
      await pumpCard(tester, title: '卡片标题', onTap: () => tapped = true);
      expect(find.text('卡片标题'), findsOneWidget);
      expect(find.text('2026年11月1日'), findsOneWidget);
      expect(find.text('摘要内容'), findsOneWidget);
      await tester.tap(find.byType(DiaryLinkCardView));
      expect(tapped, isTrue);
    });

    testWidgets('被链日记缺失时显示占位', (WidgetTester tester) async {
      await pumpCard(tester, missingLabel: '这篇日记不存在或已删除');
      expect(find.text('这篇日记不存在或已删除'), findsOneWidget);
    });
  });
}
