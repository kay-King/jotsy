import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_appflowy.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_appflowy_preview.dart';

import '../../../support/expressive_test_theme.dart';

const _documentJson = '''
{
  "document": {
    "type": "page",
    "children": [
      {
        "type": "paragraph",
        "data": {
          "delta": [
            {"insert": "Hello "},
            {"insert": "world", "attributes": {"bold": true}}
          ]
        }
      },
      {
        "type": "heading",
        "data": {
          "level": 2,
          "delta": [{"insert": "Title"}]
        }
      },
      {
        "type": "bulleted_list",
        "data": {"delta": [{"insert": "item one"}]}
      },
      {
        "type": "numbered_list",
        "data": {"delta": [{"insert": "first"}]}
      },
      {
        "type": "numbered_list",
        "data": {"delta": [{"insert": "second"}]}
      },
      {
        "type": "todo_list",
        "data": {
          "checked": false,
          "delta": [{"insert": "buy milk"}]
        }
      },
      {
        "type": "quote",
        "data": {"delta": [{"insert": "quoted"}]}
      },
      {
        "type": "code",
        "data": {
          "language": "dart",
          "delta": [{"insert": "void main() {}"}]
        }
      },
      {"type": "divider", "data": {}}
    ]
  }
}
''';

void main() {
  Document document() =>
      diaryDocumentFromStoredJson(jsonEncode(jsonDecode(_documentJson)));

  Future<void> pumpPreview(
    WidgetTester tester, {
    required Document doc,
    void Function(Node node, bool checked)? onToggleTodo,
  }) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiaryAppFlowyPreview(
              document: doc,
              appearance: const DiaryTextAppearance(
                typography: DiaryTypography(),
              ),
              onToggleTodo: onToggleTodo,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('renders text blocks, lists and code', (tester) async {
    await pumpPreview(tester, doc: document());
    expect(find.text('Hello world', findRichText: true), findsOneWidget);
    expect(find.text('Title', findRichText: true), findsOneWidget);
    expect(find.text('item one', findRichText: true), findsOneWidget);
    expect(find.text('first', findRichText: true), findsOneWidget);
    expect(find.text('second', findRichText: true), findsOneWidget);
    expect(find.text('buy milk', findRichText: true), findsOneWidget);
    expect(find.text('quoted', findRichText: true), findsOneWidget);
    // 列表标记：项目符号与连续编号。
    expect(find.text('•', findRichText: true), findsOneWidget);
    expect(find.text('1.', findRichText: true), findsOneWidget);
    expect(find.text('2.', findRichText: true), findsOneWidget);
    // 代码块文字可渲染（含高亮拆分）。
    expect(
      find.textContaining('void main', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('todo toggle calls back with the node and new value', (
    tester,
  ) async {
    final doc = document();
    Node? toggledNode;
    bool? toggledValue;
    await pumpPreview(
      tester,
      doc: doc,
      onToggleTodo: (node, checked) {
        toggledNode = node;
        toggledValue = checked;
      },
    );
    // 未勾选时没有对勾图标；点按复选框触发回调。
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.byType(InkWell).first);
    expect(toggledValue, isTrue);
    expect(toggledNode, isNotNull);
    expect(toggledNode!.type, 'todo_list');
  });

  test('diaryAppFlowyDocumentHasVisibleContent matches quill semantics', () {
    // 空文档与纯空白段落：无可见内容。
    expect(
      diaryAppFlowyDocumentHasVisibleContent(diaryDocumentFromStoredJson('')),
      isFalse,
    );
    expect(
      diaryAppFlowyDocumentHasVisibleContent(
        diaryDocumentFromStoredJson(
          '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"  "}]}}]}}',
        ),
      ),
      isFalse,
    );
    // 纯图片正文：有可见内容（不能只看纯文本镜像）。
    expect(
      diaryAppFlowyDocumentHasVisibleContent(
        diaryDocumentFromStoredJson(
          '{"document":{"type":"page","children":[{"type":"image","data":{"url":"/tmp/a.jpg"}}]}}',
        ),
      ),
      isTrue,
    );
    // 普通文字：有可见内容。
    expect(diaryAppFlowyDocumentHasVisibleContent(document()), isTrue);
  });
}
