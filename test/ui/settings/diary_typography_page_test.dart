import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_appflowy_preview.dart';
import 'package:node_diary/ui/settings/pages/diary_typography_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/diary_typography_test_harness.dart';

const _wenKai = DiaryImportedFont(
  id: 'fwen',
  name: '霞鹜文楷',
  fileName: 'fwen.ttf',
);

/// 预览卡里正文第一段实际渲染的文本样式（AppFlowy 逐块渲染的根 span 样式）。
TextStyle _previewBodyStyle(WidgetTester tester, AppLocalizations l10n) {
  final firstLine = l10n.diaryTypographySampleBody.split('\n').first;
  final candidates = find
      .descendant(
        of: find.byType(DiaryAppFlowyPreview),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.textSpan?.toPlainText() ?? '').contains(firstLine),
        ),
      )
      .evaluate();
  expect(candidates, hasLength(1));
  return (candidates.single.widget as Text).textSpan!.style!;
}

/// 预览卡里段落块底部的段间距（逐块渲染里段间距是段落的外边距）。
double _previewParagraphSpacing(WidgetTester tester) {
  final bottoms = tester
      .widgetList<Padding>(
        find.descendant(
          of: find.byType(DiaryAppFlowyPreview),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding.resolve(TextDirection.ltr).bottom > 0,
          ),
        ),
      )
      .map((padding) => padding.padding.resolve(TextDirection.ltr).bottom);
  return bottoms.isEmpty ? 0 : bottoms.first;
}

void main() {
  late SettingsService settings;
  late FakeDiaryFontStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = await SettingsService.create();
    storage = FakeDiaryFontStorage(const <DiaryImportedFont>[_wenKai]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('choosing fonts and stepping values commits immediately in '
        '${brightness.name}', (tester) async {
      await pumpDiaryTypographyHarness(
        tester,
        settings: settings,
        storage: storage,
        home: const DiaryTypographyPage(),
        brightness: brightness,
      );
      final l10n = tester.element(find.byType(DiaryTypographyPage)).l10n;

      expect(find.text(l10n.diaryTypographySampleTitle), findsOneWidget);
      expect(find.text(_wenKai.name), findsOneWidget);

      await tester.tap(find.text(l10n.diaryTypographyFontSystem));
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.fontId, DiaryTypography.systemFontId);

      await tester.tap(
        find.byTooltip(
          l10n.diaryTypographyIncrease(l10n.diaryTypographyFontSize),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.fontSize, 17);
      expect(_previewBodyStyle(tester, l10n).fontSize, 17);
      expect(_previewBodyStyle(tester, l10n).fontFamily, 'sans-serif');

      await tester.tap(
        find.byTooltip(
          l10n.diaryTypographyIncrease(l10n.diaryTypographyFirstLineIndent),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.firstLineIndent, 0.5);

      // 多了一行滑块后恢复按钮可能在屏外，先滚到可见再点。
      await tester.ensureVisible(find.text(l10n.diaryTypographyReset));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.diaryTypographyReset));
      await tester.pumpAndSettle();
      expect(settings.diaryTypography.hasDefaultMetrics, isTrue);
      // 恢复默认排版只重置数值，保留字体选择。
      expect(settings.diaryTypography.fontId, DiaryTypography.systemFontId);
    });
  }

  testWidgets('dragging a slider previews the draft and commits on release', (
    tester,
  ) async {
    await pumpDiaryTypographyHarness(
      tester,
      settings: settings,
      storage: storage,
      home: const DiaryTypographyPage(),
    );
    final paragraphSlider = find.byType(Slider).at(3);
    final start = tester.getCenter(paragraphSlider);
    // 段间距默认 0，滑块在最左端，从轨道起点开始拖。
    final from = Offset(tester.getTopLeft(paragraphSlider).dx + 30, start.dy);

    final gesture = await tester.startGesture(from);
    await tester.pump();
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();

    // 拖动中：预览按草稿排版，设置尚未提交。
    final draftSpacing = _previewParagraphSpacing(tester);
    expect(draftSpacing, greaterThan(0));
    expect(settings.diaryTypography.paragraphSpacing, 0);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(settings.diaryTypography.paragraphSpacing, draftSpacing);
    expect(_previewParagraphSpacing(tester), draftSpacing);
  });

  testWidgets('deleting the font in use falls back to the bundled font', (
    tester,
  ) async {
    await settings.setDiaryTypography(
      const DiaryTypography().copyWith(fontId: _wenKai.id),
    );
    await pumpDiaryTypographyHarness(
      tester,
      settings: settings,
      storage: storage,
      home: const DiaryTypographyPage(),
    );
    final l10n = tester.element(find.byType(DiaryTypographyPage)).l10n;
    expect(
      _previewBodyStyle(tester, l10n).fontFamily,
      DiaryFontStorageService.familyFor(_wenKai.id),
    );

    await tester.tap(find.byTooltip(l10n.diaryTypographyDeleteFont));
    await tester.pumpAndSettle();
    // 取消不删除。
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(storage.fonts, hasLength(1));

    await tester.tap(find.byTooltip(l10n.diaryTypographyDeleteFont));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();

    expect(storage.fonts, isEmpty);
    expect(find.text(_wenKai.name), findsNothing);
    expect(settings.diaryTypography.fontId, DiaryTypography.bundledFontId);
    expect(find.byIcon(FontAwesomeIcons.trashCan.data), findsNothing);
  });

  testWidgets('a selected font that is no longer on disk is explained', (
    tester,
  ) async {
    await settings.setDiaryTypography(
      const DiaryTypography().copyWith(fontId: 'frestored'),
    );
    await pumpDiaryTypographyHarness(
      tester,
      settings: settings,
      storage: storage,
      home: const DiaryTypographyPage(),
    );
    final l10n = tester.element(find.byType(DiaryTypographyPage)).l10n;

    expect(find.text(l10n.diaryTypographyFontMissing), findsOneWidget);
    // 正文回落到环境主题字体（不覆盖字族）：测试主题是 material2021
    // 的平台字体 Roboto，真机上即系统字体。
    expect(_previewBodyStyle(tester, l10n).fontFamily, 'Roboto');
  });
}
