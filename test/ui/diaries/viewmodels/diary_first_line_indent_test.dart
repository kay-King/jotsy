import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_first_line_indent.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_appflowy_preview.dart';

import '../../../support/expressive_test_theme.dart';

/// AppFlowy 时代的首行缩进记在块属性上（`first_line_indent`），渲染层只读：
/// - 只读预览：普通段落在首个文字 span 前垫定宽 WidgetSpan，原文不动；
/// - 可编辑器：不垫 WidgetSpan（会干扰点按/框选的光标映射），缩进只在保存
///   时写进段落属性；
/// - 只缩进普通段落：标题、列表、引用、代码块、居中/右对齐、行首已有空白、
///   空段落不缩。

Node _node(String type, String text, {Map<String, dynamic>? attributes}) {
  return Node.fromJson(<String, Object>{
    'type': type,
    'data': <String, Object>{
      'delta': [
        {'insert': text},
      ],
      if (attributes != null) ...attributes,
    },
  });
}

void main() {
  const typography = DiaryTypography(firstLineIndent: 2, fontSize: 16);

  group('diaryFirstLineIndentWidth', () {
    test('2 字 × 16px 字号 = 32px', () {
      expect(diaryFirstLineIndentWidth(typography), 32);
    });

    test('关闭时为 0', () {
      expect(diaryFirstLineIndentWidth(const DiaryTypography()), 0);
    });
  });

  group('shouldApplyFirstLineIndent', () {
    test('普通段落缩进', () {
      expect(
        shouldApplyFirstLineIndent(
          _node(ParagraphBlockKeys.type, '第一段文字'),
          typography,
        ),
        isTrue,
      );
    });

    test('标题、列表、引用、代码块不缩', () {
      for (final type in [
        HeadingBlockKeys.type,
        BulletedListBlockKeys.type,
        NumberedListBlockKeys.type,
        TodoListBlockKeys.type,
        QuoteBlockKeys.type,
        kDiaryBlockCode,
      ]) {
        expect(
          shouldApplyFirstLineIndent(_node(type, '文字'), typography),
          isFalse,
          reason: type,
        );
      }
    });

    test('居中/右对齐不缩，两端对齐照常缩', () {
      expect(
        shouldApplyFirstLineIndent(
          _node(
            ParagraphBlockKeys.type,
            '居中段',
            attributes: {'align': 'center'},
          ),
          typography,
        ),
        isFalse,
      );
      expect(
        shouldApplyFirstLineIndent(
          _node(ParagraphBlockKeys.type, '右对齐', attributes: {'align': 'right'}),
          typography,
        ),
        isFalse,
      );
      expect(
        shouldApplyFirstLineIndent(
          _node(
            ParagraphBlockKeys.type,
            '两端对齐',
            attributes: {'align': 'justify'},
          ),
          typography,
        ),
        isTrue,
      );
    });

    test('行首已有空白、空段落不缩', () {
      expect(
        shouldApplyFirstLineIndent(
          _node(ParagraphBlockKeys.type, '  已空段'),
          typography,
        ),
        isFalse,
      );
      expect(
        shouldApplyFirstLineIndent(
          _node(ParagraphBlockKeys.type, ''),
          typography,
        ),
        isFalse,
      );
    });

    test('缩进开关关闭时都不缩', () {
      expect(
        shouldApplyFirstLineIndent(
          _node(ParagraphBlockKeys.type, '第一段文字'),
          const DiaryTypography(),
        ),
        isFalse,
      );
    });

    test('块属性显式关闭时不缩', () {
      expect(
        shouldApplyFirstLineIndent(
          _node(
            ParagraphBlockKeys.type,
            '第一段文字',
            attributes: {kFirstLineIndentAttribute: false},
          ),
          typography,
        ),
        isFalse,
      );
    });

    test('工具栏标记的段落：全局关闭时也缩进（v0.11.0 #122）', () {
      expect(
        shouldApplyFirstLineIndent(
          _node(
            ParagraphBlockKeys.type,
            '第一段文字',
            attributes: {kDiaryParagraphIndentKey: true},
          ),
          const DiaryTypography(),
        ),
        isTrue,
      );
    });

    test('工具栏标记的段落：居中/空段落仍不缩', () {
      expect(
        shouldApplyFirstLineIndent(
          _node(
            ParagraphBlockKeys.type,
            '居中段',
            attributes: {kDiaryParagraphIndentKey: true, 'align': 'center'},
          ),
          const DiaryTypography(),
        ),
        isFalse,
      );
      expect(
        shouldApplyFirstLineIndent(
          _node(
            ParagraphBlockKeys.type,
            '',
            attributes: {kDiaryParagraphIndentKey: true},
          ),
          const DiaryTypography(),
        ),
        isFalse,
      );
    });
  });

  group('diaryParagraphFirstLineIndentWidth', () {
    test('带标记的段落取两字与全局较大者', () {
      const fontSize = 16.0;
      // 全局 2 字 = 32px，标记两字 = 32px，取 32。
      expect(
        diaryParagraphFirstLineIndentWidth(
          _node(
            ParagraphBlockKeys.type,
            '文字',
            attributes: {kDiaryParagraphIndentKey: true},
          ),
          typography,
          fontSize,
        ),
        32,
      );
      // 全局 0 字时标记仍给两字 32px。
      expect(
        diaryParagraphFirstLineIndentWidth(
          _node(
            ParagraphBlockKeys.type,
            '文字',
            attributes: {kDiaryParagraphIndentKey: true},
          ),
          const DiaryTypography(),
          fontSize,
        ),
        32,
      );
      // 全局 3 字 = 48px 时标记段落取全局 48px。
      expect(
        diaryParagraphFirstLineIndentWidth(
          _node(
            ParagraphBlockKeys.type,
            '文字',
            attributes: {kDiaryParagraphIndentKey: true},
          ),
          const DiaryTypography(firstLineIndent: 3, fontSize: 16),
          fontSize,
        ),
        48,
      );
    });

    test('无标记的段落只取全局宽度', () {
      expect(
        diaryParagraphFirstLineIndentWidth(
          _node(ParagraphBlockKeys.type, '文字'),
          typography,
          16,
        ),
        32,
      );
      expect(
        diaryParagraphFirstLineIndentWidth(
          _node(ParagraphBlockKeys.type, '文字'),
          const DiaryTypography(),
          16,
        ),
        0,
      );
    });
  });

  group('withFirstLineIndentAttribute', () {
    test('宽度大于 0 时写入标记', () {
      expect(withFirstLineIndentAttribute(const {}, 32), {
        kFirstLineIndentAttribute: true,
      });
    });

    test('保留原有属性', () {
      expect(withFirstLineIndentAttribute(const {'align': 'center'}, 32), {
        'align': 'center',
        kFirstLineIndentAttribute: true,
      });
    });

    test('宽度为 0 时移除标记', () {
      expect(
        withFirstLineIndentAttribute(const {
          kFirstLineIndentAttribute: true,
        }, 0),
        isEmpty,
      );
    });
  });

  group('preview rendering', () {
    /// 渲染出的 span 里，某段文字前面垫的占位宽度；没垫时为 null。
    double? indentBefore(WidgetTester tester, String lineText) {
      double? found;
      void walk(InlineSpan span) {
        if (span is TextSpan) {
          // WidgetSpan 在 toPlainText 里占一个 U+FFFC，先去掉再比对段文字。
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

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final span = text.textSpan;
        if (span != null) walk(span);
      }
      return found;
    }

    Future<void> pumpPreview(
      WidgetTester tester,
      Document document,
      DiaryTypography typography,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            home: Scaffold(
              body: DiaryAppFlowyPreview(
                document: document,
                appearance: DiaryTextAppearance(typography: typography),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Document document() {
      final doc = Document.blank();
      final nodes = [
        _node(ParagraphBlockKeys.type, '第一段文字'),
        _node(HeadingBlockKeys.type, '标题'),
        _node(BulletedListBlockKeys.type, '列表项'),
        _node(ParagraphBlockKeys.type, '居中段', attributes: {'align': 'center'}),
        _node(ParagraphBlockKeys.type, '  已空段'),
        _node(ParagraphBlockKeys.type, '第二段文字'),
      ];
      for (var i = 0; i < nodes.length; i++) {
        doc.insert([i], [nodes[i]]);
      }
      return doc;
    }

    testWidgets('only plain paragraphs get the indent in the preview', (
      tester,
    ) async {
      await pumpPreview(tester, document(), typography);
      // 2 字 × 16px 字号 = 32px，只出现在两个普通段落前。
      expect(indentBefore(tester, '第一段文字'), 32);
      expect(indentBefore(tester, '第二段文字'), 32);
      expect(indentBefore(tester, '标题'), isNull);
      expect(indentBefore(tester, '列表项'), isNull);
      expect(indentBefore(tester, '居中段'), isNull);
      expect(indentBefore(tester, '  已空段'), isNull);
    });

    testWidgets('zero indent renders no spacer in the preview', (tester) async {
      await pumpPreview(tester, document(), const DiaryTypography());
      expect(indentBefore(tester, '第一段文字'), isNull);
      expect(indentBefore(tester, '第二段文字'), isNull);
    });
  });
}
