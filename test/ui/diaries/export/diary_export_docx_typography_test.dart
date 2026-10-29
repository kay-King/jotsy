import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/export/diary_export_docx.dart';
import 'package:node_diary/ui/diaries/export/diary_export_format.dart';
import 'package:node_diary/ui/diaries/export/diary_export_media.dart';
import 'package:xml/xml.dart';

import 'diary_export_test_fixtures.dart';

/// 验证 Word 实际采用的正文样式及继承边界，而非只检查设置是否传入。
void main() {
  Future<XmlDocument> styles(DiaryTypography typography) async {
    final output = await DiaryDocxWriter.write(
      [richEntry()],
      options: DiaryExportOptions.defaults,
      labels: testExportLabels,
      media: DiaryExportMediaLibrary(),
      documentTitle: 'Typography',
      languageTag: 'zh-CN',
      typography: typography,
    );
    return XmlDocument.parse(
      utf8.decode(
        output.files!.singleWhere((f) => f.path == 'word/styles.xml').bytes!,
      ),
    );
  }

  XmlElement style(XmlDocument document, String id) => document
      .findAllElements('w:style')
      .singleWhere((e) => e.getAttribute('w:styleId') == id);

  test('Word uses the selected body metrics instead of 1.5 lines and 6pt '
      'after every paragraph', () async {
    final document = await styles(
      const DiaryTypography(
        fontSize: 24,
        lineHeight: 2.2,
        letterSpacing: 1.25,
        paragraphSpacing: 12,
      ),
    );
    final normal = style(document, 'Normal');
    final spacing = normal.getElement('w:pPr')!.getElement('w:spacing')!;
    expect(spacing.getAttribute('w:line'), '528');
    expect(spacing.getAttribute('w:lineRule'), 'auto');
    expect(spacing.getAttribute('w:after'), '180');
    final run = normal.getElement('w:rPr')!;
    // 24px = 18pt，字距 1.25px = 0.9375pt；Word 分别按半磅 / twip 取整。
    expect(run.getElement('w:sz')!.getAttribute('w:val'), '36');
    expect(run.getElement('w:szCs')!.getAttribute('w:val'), '36');
    expect(run.getElement('w:spacing')!.getAttribute('w:val'), '19');
    expect(run.childElements.map((e) => e.name.qualified), [
      'w:spacing',
      'w:sz',
      'w:szCs',
    ]);
  });

  test('lists and quotes inherit body metrics without the extra paragraph '
      'gap; headings only follow tracking', () async {
    final document = await styles(
      const DiaryTypography(
        fontSize: 28,
        lineHeight: 3,
        letterSpacing: 2,
        paragraphSpacing: 48,
      ),
    );
    for (final id in ['DiaryList', 'Quote']) {
      final element = style(document, id);
      expect(element.getElement('w:basedOn')!.getAttribute('w:val'), 'Normal');
      final spacing = element.getElement('w:pPr')!.getElement('w:spacing')!;
      expect(spacing.getAttribute('w:after'), '120');
      expect(spacing.getAttribute('w:line'), isNull);
    }
    final heading = style(document, 'Heading1');
    expect(heading.getElement('w:basedOn'), isNull);
    final run = heading.getElement('w:rPr')!;
    expect(run.getElement('w:sz')!.getAttribute('w:val'), '32');
    expect(run.getElement('w:spacing')!.getAttribute('w:val'), '30');
    // 抬头与代码不继承正文参数，否则调大行距 / 字距会破坏各自的版式。
    for (final id in ['Title', 'DiaryMeta', 'CodeBlock']) {
      expect(style(document, id).getElement('w:basedOn'), isNull);
    }
    final code = style(document, 'CodeBlock');
    expect(
      code.getElement('w:rPr')!.getElement('w:sz')!.getAttribute('w:val'),
      '20',
    );
    final spacing = code.getElement('w:pPr')!.getElement('w:spacing')!;
    expect(spacing.getAttribute('w:line'), '276');
    expect(spacing.getAttribute('w:after'), '0');
  });

  test(
    'default typography has the app line height and no paragraph gap',
    () async {
      final normal = style(await styles(const DiaryTypography()), 'Normal');
      final spacing = normal.getElement('w:pPr')!.getElement('w:spacing')!;
      expect(spacing.getAttribute('w:line'), '372');
      expect(spacing.getAttribute('w:after'), '0');
      final run = normal.getElement('w:rPr')!;
      expect(run.getElement('w:sz')!.getAttribute('w:val'), '24');
      expect(run.getElement('w:spacing')!.getAttribute('w:val'), '0');
    },
  );

  test('negative tracking and single spacing remain valid at the lower '
      'bounds', () async {
    final normal = style(
      await styles(
        const DiaryTypography(fontSize: 10, lineHeight: 1, letterSpacing: -1),
      ),
      'Normal',
    );
    final spacing = normal.getElement('w:pPr')!.getElement('w:spacing')!;
    expect(spacing.getAttribute('w:line'), '240');
    expect(spacing.getAttribute('w:after'), '0');
    final run = normal.getElement('w:rPr')!;
    expect(run.getElement('w:sz')!.getAttribute('w:val'), '15');
    expect(run.getElement('w:spacing')!.getAttribute('w:val'), '-15');
  });

  test('first-line indent lands on body paragraphs only, as w:firstLine',
      () async {
    Future<XmlDocument> document(DiaryTypography typography) async {
      final output = await DiaryDocxWriter.write(
        [richEntry()],
        options: DiaryExportOptions.defaults,
        labels: testExportLabels,
        media: DiaryExportMediaLibrary(),
        documentTitle: 'Typography',
        languageTag: 'zh-CN',
        typography: typography,
      );
      return XmlDocument.parse(
        utf8.decode(
          output.files!.singleWhere((f) => f.path == 'word/document.xml')
              .bytes!,
        ),
      );
    }

    String textOf(XmlElement paragraph) => paragraph
        .findAllElements('w:t')
        .map((e) => e.innerText)
        .join();
    XmlElement paragraphWith(XmlDocument doc, String needle) => doc
        .findAllElements('w:p')
        .singleWhere((p) => textOf(p).contains(needle));
    String? firstLineOf(XmlElement paragraph) => paragraph
        .getElement('w:pPr')
        ?.getElement('w:ind')
        ?.getAttribute('w:firstLine');

    // 2 字 × 16px 字号 × 15twip/px = 480twip。
    final indented = await document(
      const DiaryTypography(firstLineIndent: 2),
    );
    expect(
      firstLineOf(paragraphWith(indented, '今天')),
      '480',
    );
    // 标题、列表、引用不带首行缩进（列表仍保留自己的左缩进与悬挂）。
    expect(firstLineOf(paragraphWith(indented, '小标题')), isNull);
    final list = paragraphWith(indented, '第一');
    expect(firstLineOf(list), isNull);
    expect(
      list.getElement('w:pPr')!.getElement('w:ind')!.getAttribute('w:left'),
      '420',
    );
    expect(firstLineOf(paragraphWith(indented, '一句话')), isNull);
    // 默认 0 时整份文档没有 w:firstLine。
    final plain = await document(const DiaryTypography());
    expect(
      plain.findAllElements('w:ind').map(
        (e) => e.getAttribute('w:firstLine'),
      ),
      everyElement(isNull),
    );
  });
}
