import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_content.dart';
import 'package:node_diary/ui/settings/pages/diary_preview_style_page.dart';
import 'package:node_diary/ui/settings/sections/settings_diary_preview_style_tile.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

Widget _app(SettingsService settings, Widget home, {AppDatabase? database}) {
  return ProviderScope(
    overrides: [
      settingsServiceProvider.overrideWith((ref) async => settings),
      if (database != null) appDatabaseProvider.overrideWithValue(database),
    ],
    child: MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<(SettingsService, AppLocalizations)> _pumpPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 860),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiaryPreviewStylePage(settingsService: settings),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  return (settings, l10n);
}

DiaryPreviewSettings _stored(SettingsService settings) =>
    DiaryPreviewSettings.decode(settings.diaryPreviewStyleRaw);

/// 点底部悬浮分类按钮：弹 BottomSheet 显示该分类的选项。
Future<void> _openTab(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// 关掉选项 BottomSheet：点右上角的关闭按钮。
Future<void> _closeSheet(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.byTooltip(l10n.commonClose));
  await tester.pumpAndSettle();
}

/// 打开左上角悬浮菜单，返回其中“重置”菜单项的 Finder。
Future<Finder> _openMenu(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(find.byTooltip(l10n.diaryPreviewStyleTitle));
  await tester.pumpAndSettle();
  return find.widgetWithText(MenuItemButton, l10n.commonReset);
}

/// BottomSheet 里的纵向滚动列表。
Finder _sheetScrollable() => find
    .descendant(
      of: find.byType(BottomSheet),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .first;

/// 选项列表是懒构建的：目标还没进树时先在 BottomSheet 里向下滚动。
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 120, scrollable: _sheetScrollable());
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 120, scrollable: _sheetScrollable());
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _dismissSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a full-screen preview with seven floating tab buttons', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester);
    expect(find.byType(DiaryPreviewContent), findsWidgets);
    for (final label in <String>[
      l10n.diaryPreviewStyleTabPresets,
      l10n.diaryPreviewStyleTabPage,
      l10n.diaryPreviewStyleTabCover,
      l10n.diaryPreviewStyleTabTitle,
      l10n.diaryPreviewStyleTabMeta,
      l10n.diaryPreviewStyleTabBody,
      l10n.diaryPreviewStyleTabPaging,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.bySemanticsLabel(l10n.diaryPreviewStyleSampleOf(1, 3)),
      findsOneWidget,
    );
    // 默认样式时菜单里的“重置”不可用。
    final reset = await _openMenu(tester, l10n);
    expect(tester.widget<MenuItemButton>(reset).onPressed, isNull);
    // 关掉菜单。
    await tester.tap(find.byTooltip(l10n.diaryPreviewStyleTitle));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches persist immediately and update the preview', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryPreviewStyleTabMeta);
    await _tapVisible(
      tester,
      find.widgetWithText(
        SettingsSwitchTile,
        l10n.diaryPreviewStyleShowLocation,
      ),
    );
    expect(_stored(settings).current.meta.showLocation, isFalse);
    expect(find.text(l10n.diaryCardStyleSampleLocation), findsNothing);
  });

  testWidgets('the paging tab keeps reading behavior apart from the look', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryPreviewStyleTabPaging);
    await _tapVisible(
      tester,
      find.widgetWithText(
        SettingsSwitchTile,
        l10n.diaryPreviewStyleHapticOnPage,
      ),
    );
    await _tapVisible(
      tester,
      find.text(l10n.diaryPreviewStyleSensitivityStrict),
    );
    await _tapVisible(tester, find.text(l10n.diaryPreviewStyleTransitionStack));
    await _tapVisible(
      tester,
      find.widgetWithText(
        SettingsSwitchTile,
        l10n.diaryPreviewStyleNeighborCards,
      ),
    );
    var stored = _stored(settings);
    expect(stored.behavior.hapticOnPage, isTrue);
    expect(
      stored.behavior.swipeSensitivity,
      DiaryPreviewSwipeSensitivity.strict,
    );
    expect(
      stored.current.navigation.transition,
      DiaryPreviewPageTransition.stack,
    );
    expect(stored.current.navigation.neighborCards, isTrue);

    // 关掉滑动后灵敏度与轻震随之收起。
    await _tapVisible(
      tester,
      find.widgetWithText(SettingsSwitchTile, l10n.diaryPreviewStyleSwipe),
    );
    stored = _stored(settings);
    expect(stored.behavior.swipeBetweenDiaries, isFalse);
    expect(find.text(l10n.diaryPreviewStyleSwipeSensitivity), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the body tab switches long images between fold and full', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryPreviewStyleTabBody);
    await _scrollTo(tester, find.text(l10n.diaryPreviewStyleLongImage));
    expect(
      _stored(settings).behavior.longImageMode,
      DiaryPreviewLongImageMode.fold,
    );

    await _tapVisible(tester, find.text(l10n.diaryPreviewStyleLongImageFull));
    var stored = _stored(settings);
    expect(stored.behavior.longImageMode, DiaryPreviewLongImageMode.full);
    // 属于阅读行为：外观没有变化。
    expect(stored.current, const DiaryPreviewStyle());

    await _tapVisible(tester, find.text(l10n.diaryPreviewStyleLongImageFold));
    stored = _stored(settings);
    expect(stored.behavior.longImageMode, DiaryPreviewLongImageMode.fold);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the live preview swipes between samples', (tester) async {
    final (_, l10n) = await _pumpPage(tester);
    final gesture = await tester.startGesture(const Offset(300, 220));
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l10n.diaryPreviewStyleSampleOf(2, 3)),
      findsOneWidget,
    );
  });

  testWidgets('sliders preview while dragging and persist on release', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryPreviewStyleTabPage);
    final finder = find.widgetWithText(
      SettingsSliderTile,
      l10n.diaryPreviewStylePadding,
    );
    await _scrollTo(tester, finder);
    final tile = tester.widget<SettingsSliderTile>(finder);
    tile.onChanged!(30);
    await tester.pump();
    expect(settings.diaryPreviewStyleRaw, isNull);
    expect(find.text(l10n.diaryCardStyleValueDp('30')), findsOneWidget);

    tile.onChangeEnd!(30);
    await tester.pumpAndSettle();
    expect(_stored(settings).current.page.horizontalPadding, 30);
  });

  testWidgets('a preset changes the look but keeps the reading behavior', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryPreviewStyleTabBody);
    await _tapVisible(
      tester,
      find.widgetWithText(SettingsSwitchTile, l10n.diaryPreviewStyleTodoToggle),
    );
    expect(_stored(settings).behavior.todoToggle, isFalse);
    await _closeSheet(tester, l10n);

    await _openTab(tester, l10n.diaryPreviewStyleTabPresets);
    await _tapVisible(tester, find.text(l10n.diaryPreviewStylePresetNight));
    expect(
      _stored(settings).current,
      DiaryPreviewPresets.styleOf(DiaryPreviewPresetId.night),
    );
    expect(_stored(settings).behavior.todoToggle, isFalse);
    expect(
      find.text(l10n.styleEditorApplied(l10n.diaryPreviewStylePresetNight)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).current, DiaryPreviewStyle.defaults);
    expect(_stored(settings).behavior.todoToggle, isFalse);
  });

  testWidgets('reset restores the default look and can be undone', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryPreviewStyleTabPresets);
    await _tapVisible(tester, find.text(l10n.diaryPreviewStylePresetMagazine));
    await _dismissSnackBars(tester);
    final magazine = DiaryPreviewPresets.styleOf(DiaryPreviewPresetId.magazine);
    expect(_stored(settings).current, magazine);

    await _closeSheet(tester, l10n);
    await tester.tap(await _openMenu(tester, l10n));
    await tester.pumpAndSettle();
    expect(settings.diaryPreviewStyleRaw, isNull);
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).current, magazine);
  });

  testWidgets('the appearance entry names the current preset', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_preview_style': DiaryPreviewSettings(
        current: DiaryPreviewPresets.styleOf(DiaryPreviewPresetId.paper),
      ).encode()!,
    });
    final settings = (await tester.runAsync(SettingsService.create))!;
    await tester.pumpWidget(
      _app(
        settings,
        Scaffold(
          body: SettingsDiaryPreviewStyleTile(
            settingsAsync: AsyncValue<SettingsService>.data(settings),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(
      find.text(
        l10n.diaryPreviewStyleEntrySubtitle(l10n.diaryPreviewStylePresetPaper),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.diaryPreviewStyleTitle));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryPreviewStylePage), findsOneWidget);
  });

  testWidgets('the preview page More sheet opens the style page with it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = (await tester.runAsync(SettingsService.create))!;
    final database = _PendingDetailDatabase();
    addTearDown(database.close);
    final now = DateTime(2026, 10, 14, 9);
    final detail = DiaryWithTags(
      diary: Diary(
        id: 1,
        diaryId: 'more-style-1',
        title: '我自己的日记',
        content: '[{"insert":"正文\\n"}]',
        contentText: '正文',
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        isArchived: false,
        isPinned: false,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );
    await tester.pumpWidget(
      _app(
        settings,
        DiaryPreviewPage(diaryId: 'more-style-1', initialDetail: detail),
        database: database,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.byTooltip(l10n.autoT0125));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.diaryPreviewStyleMoreEntry));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryPreviewStylePage), findsOneWidget);
    // 第一篇示例就是这篇日记。
    expect(
      find.descendant(
        of: find.byType(DiaryPreviewStylePage),
        matching: find.text('我自己的日记'),
      ),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('every tab fits a 320dp screen in $brightness', (tester) async {
      final (settings, l10n) = await _pumpPage(
        tester,
        brightness: brightness,
        size: const Size(320, 640),
      );
      // 打开有条件显示的分组，让它们也参与检查。
      await settings.setDiaryPreviewStyleRaw(
        const DiaryPreviewSettings(
          current: DiaryPreviewStyle(
            page: DiaryPreviewPageStyle(
              colorSeed: DiaryPreviewColorSeed.mood,
              paper: DiaryPreviewPaper.warm,
              limitWidth: true,
            ),
            cover: DiaryPreviewCoverStyle(mode: DiaryPreviewCoverMode.inset),
          ),
          behavior: DiaryPreviewBehavior(textSelection: false),
        ).encode(),
      );
      await tester.pumpAndSettle();
      for (final label in <String>[
        l10n.diaryPreviewStyleTabPresets,
        l10n.diaryPreviewStyleTabPage,
        l10n.diaryPreviewStyleTabCover,
        l10n.diaryPreviewStyleTabTitle,
        l10n.diaryPreviewStyleTabMeta,
        l10n.diaryPreviewStyleTabBody,
        l10n.diaryPreviewStyleTabPaging,
      ]) {
        await _openTab(tester, label);
        await tester.drag(_sheetScrollable(), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
        await _closeSheet(tester, l10n);
      }
    });
  }
}

class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      Completer<DiaryWithTags?>().future;
}
