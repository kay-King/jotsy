import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_first_line_indent.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';

import '../../../support/expressive_test_theme.dart';

/// 普通段落、标题、列表、居中段、已手动空过格的段、代码块各一行。
quill.Document _document() {
  return quill.Document.fromJson(<Map<String, Object?>>[
    <String, Object?>{'insert': '第一段文字\n'},
    <String, Object?>{'insert': '标题'},
    <String, Object?>{
      'insert': '\n',
      'attributes': <String, Object?>{'header': 1},
    },
    <String, Object?>{'insert': '列表项'},
    <String, Object?>{
      'insert': '\n',
      'attributes': <String, Object?>{'list': 'bullet'},
    },
    <String, Object?>{'insert': '居中段'},
    <String, Object?>{
      'insert': '\n',
      'attributes': <String, Object?>{'align': 'center'},
    },
    <String, Object?>{'insert': '  已空段\n'},
    <String, Object?>{'insert': 'print(1)'},
    <String, Object?>{
      'insert': '\n',
      'attributes': <String, Object?>{'code-block': true},
    },
    <String, Object?>{'insert': '第二段文字\n'},
  ]);
}

Future<void> _pump(
  WidgetTester tester,
  quill.QuillController controller,
  DiaryTypography typography,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: DiaryQuillStylesBuilder(
            appearance: DiaryTextAppearance(typography: typography),
            controller: controller,
            codeBlockStyle: DiaryCodeBlockStyle.defaults,
            builder: (BuildContext context, DiaryQuillLook look) {
              return quill.QuillEditor.basic(
                controller: controller,
                config: look.configure(
                  const quill.QuillEditorConfig(
                    autoFocus: false,
                    scrollable: false,
                    showCursor: false,
                  ),
                  firstLineIndentWidth: diaryFirstLineIndentWidth(typography),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// 渲染出的 span 里，某段文字前面垫的占位宽度；没垫时为 null。
/// WidgetSpan 在 toPlainText 里占一个 U+FFFC，先去掉再比对段文字。
/// 不能用 visitChildren：包装 span 的 text 为 null，visitChildren 不会
/// 把它交给 visitor，这里手动递归子 span。
double? _indentBefore(WidgetTester tester, String lineText) {
  double? found;
  void walk(InlineSpan span) {
    if (span is TextSpan) {
      if (span.toPlainText().replaceAll('\uFFFC', '') == lineText &&
          span.children != null) {
        for (final child in span.children!) {
          if (child is WidgetSpan && child.child is SizedBox) {
            found = (child.child as SizedBox).width;
          }
        }
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    walk(rich.text);
  }
  return found;
}

void main() {
  testWidgets('only plain paragraphs get a first-line spacer in the '
      'read-only render', (tester) async {
    final controller = quill.QuillController(
      document: _document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);
    const typography = DiaryTypography(firstLineIndent: 2);
    await _pump(tester, controller, typography);
    // 2 字 × 16px 字号 = 32px，只出现在两个普通段落前。
    expect(_indentBefore(tester, '第一段文字'), 32);
    expect(_indentBefore(tester, '第二段文字'), 32);
    expect(_indentBefore(tester, '标题'), isNull);
    expect(_indentBefore(tester, '列表项'), isNull);
    expect(_indentBefore(tester, '居中段'), isNull);
    expect(_indentBefore(tester, '  已空段'), isNull);
    expect(_indentBefore(tester, 'print(1)'), isNull);
    // 原文没被改写：占位不是文字，Delta 里没有多出来的空格。
    expect(controller.document.toPlainText(), contains('第一段文字\n'));
    expect(controller.document.toPlainText(), isNot(contains('  第一段')));
  });

  testWidgets('zero indent renders no spacer', (tester) async {
    final controller = quill.QuillController(
      document: _document(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    addTearDown(controller.dispose);
    await _pump(tester, controller, const DiaryTypography());
    expect(_indentBefore(tester, '第一段文字'), isNull);
    expect(_indentBefore(tester, '第二段文字'), isNull);
  });

  testWidgets('editable editor shows indent and typing does not pollute delta',
      (tester) async {
    final controller = quill.QuillController(
      document: quill.Document.fromJson(<Map<String, Object?>>[
        <String, Object?>{'insert': 'hello\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(controller.dispose);
    const typography = DiaryTypography(firstLineIndent: 2);
    await _pump(tester, controller, typography);
    // 编辑器里也能看到缩进占位。
    expect(_indentBefore(tester, 'hello'), 32);
    // 在行首打字：Delta 里不应多出空格，占位是纯视觉的。
    controller.document.insert(0, 'X');
    await tester.pump();
    expect(controller.document.toPlainText(), startsWith('Xhello'));
    expect(controller.document.toPlainText(), isNot(contains('  Xhello')));
    expect(_indentBefore(tester, 'Xhello'), 32);
  });

  testWidgets('newline in editor keeps indent on the new line', (tester) async {
    final controller = quill.QuillController(
      document: quill.Document.fromJson(<Map<String, Object?>>[
        <String, Object?>{'insert': 'ab\n'},
      ]),
      selection: const TextSelection.collapsed(offset: 2),
    );
    addTearDown(controller.dispose);
    const typography = DiaryTypography(firstLineIndent: 2);
    await _pump(tester, controller, typography);
    // 在 "ab" 后回车：新起一行，缩进占位应出现在新行。
    controller.document.insert(2, '\n');
    await tester.pump();
    expect(_indentBefore(tester, 'ab'), 32);
    // 新行是空行（只有换行符），占位只垫在有文字的行首，不崩即可。
    expect(controller.document.toPlainText(), 'ab\n\n');
  });

  testWidgets('selection across indented lines does not crash', (tester) async {
    final controller = quill.QuillController(
      document: _document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(controller.dispose);
    const typography = DiaryTypography(firstLineIndent: 2);
    await _pump(tester, controller, typography);
    // 全选再取消，不崩、Delta 不变。
    controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 20),
      quill.ChangeSource.local,
    );
    await tester.pump();
    controller.updateSelection(
      const TextSelection.collapsed(offset: 5),
      quill.ChangeSource.local,
    );
    await tester.pump();
    expect(controller.document.toPlainText(), contains('第一段文字\n'));
  });
}
