import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_code.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_settings.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_view_data.dart';
import 'package:node_diary/ui/settings/pages/diary_card_style_page.dart';
import 'package:node_diary/ui/settings/sections/diary_card_style/diary_card_style_layout_tab.dart';
import 'package:node_diary/ui/settings/sections/diary_card_style/diary_card_style_preview.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_common.dart';
import 'package:node_diary/ui/widgets/triple_bar_drag_handle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/expressive_test_theme.dart';

/// 模拟系统剪贴板：Clipboard.setData / getData 走 platform channel。
String? _clipboard;

void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          _clipboard = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return _clipboard == null
              ? null
              : <String, Object?>{'text': _clipboard};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
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
    MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiaryCardStylePage(settingsService: settings),
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  return (settings, l10n);
}

DiaryCardStyleSettings _stored(SettingsService settings) =>
    DiaryCardStyleSettings.decode(settings.diaryCardStyleRaw);

/// 控制条默认隐藏：点预览顶部空白处叫出来（已显示时不再点）。
/// 顶部几像素是卡片列表上方的留白，不会点中可交互元素。
Future<void> _showControls(WidgetTester tester, AppLocalizations l10n) async {
  if (find
      .byTooltip(l10n.styleEditorSettingsTitle)
      .hitTestable()
      .evaluate()
      .isEmpty) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width / 2, 5));
    await tester.pumpAndSettle();
  }
}

/// 点右上角「样式设置」按钮：打开选项整页，所有分类按区块上下排列。
/// 打开后滚动到 [label] 对应的分类区块（ListView 懒构建，目标可能还没进树）。
Future<void> _openTab(
  WidgetTester tester,
  String label,
  AppLocalizations l10n,
) async {
  await _showControls(tester, l10n);
  final button = find.byTooltip(l10n.styleEditorSettingsTitle);
  expect(button, findsOneWidget, reason: '样式设置按钮');
  await tester.tap(button);
  await tester.pumpAndSettle();
  // 滚动到目标分类区块（ListView 懒构建）：dragUntilVisible 会自动找到
  // 可滚动的祖先，不用手动指定 scrollable。
  final sectionHeader = find.text(label);
  if (sectionHeader.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      sectionHeader,
      find.byType(Scaffold).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
  } else {
    await tester.ensureVisible(sectionHeader);
    await tester.pumpAndSettle();
  }
}

/// 关掉选项整页：直接 Navigator.pop 回到全屏预览。
/// AppTopBar 用自定义返回键（FontAwesome angleLeft），不用标准 BackButton。
Future<void> _closeSheet(WidgetTester tester, AppLocalizations l10n) async {
  final context = tester.element(find.byType(Scaffold).first);
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
}

/// 打开左上角悬浮菜单，返回其中“重置”菜单项的 Finder。
Future<Finder> _openMenu(WidgetTester tester, AppLocalizations l10n) async {
  await _showControls(tester, l10n);
  await tester.tap(find.byTooltip(l10n.diaryCardStyleTitle));
  await tester.pumpAndSettle();
  return find.widgetWithText(MenuItemButton, l10n.commonReset);
}

/// 选项列表是懒构建的：目标还没进树时先在选项整页里向下滚动。
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      finder,
      find.byType(Scaffold).last,
      const Offset(0, -200),
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 等撤销提示自行关闭，避免它的强制关闭计时器在用例结束时仍未触发。
Future<void> _dismissSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(DiaryCardViewData.debugClearCache);

  testWidgets('shows a full-screen preview with four category sections', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester);
    expect(find.byType(DiariesListSection), findsOneWidget);
    // 打开右上角「样式设置」：4 个分类按区块上下排列在选项整页里。
    await _showControls(tester, l10n);
    final button = find.byTooltip(l10n.styleEditorSettingsTitle);
    await tester.tap(button);
    await tester.pumpAndSettle();
    // 逐个滚动查找 4 个分类区块标题（ListView 懒加载，不可见的需要滚出来）。
    final scrollable = find.byType(Scrollable).first;
    for (final label in <String>[
      l10n.diaryCardStyleTabPresets,
      l10n.diaryCardStyleTabLayout,
      l10n.diaryCardStyleTabContent,
      l10n.diaryCardStyleTabAppearance,
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text(label), findsWidgets, reason: label);
    }
    // 回到全屏预览，验证示例标题还在。
    await _closeSheet(tester, l10n);
    expect(find.text(l10n.diaryCardStyleSampleTitle1), findsOneWidget);
    // 默认样式时菜单里的“重置”不可用。
    final reset = await _openMenu(tester, l10n);
    expect(tester.widget<MenuItemButton>(reset).onPressed, isNull);
    // 关掉菜单。
    await tester.tap(find.byTooltip(l10n.diaryCardStyleTitle));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches persist immediately and update the preview', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabContent, l10n);
    await _tapVisible(
      tester,
      find.widgetWithText(SettingsSwitchTile, l10n.diaryCardStyleShowPreview),
    );
    expect(_stored(settings).current.content.showPreview, isFalse);
    expect(find.text(l10n.diaryCardStyleSampleBody1), findsNothing);
  });

  testWidgets('the untitled switch updates the preview and follows the title', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    // 直接打开内容分类，找到“无标题”开关。
    await _openTab(tester, l10n.diaryCardStyleTabContent, l10n);
    final untitledSwitch = find.widgetWithText(
      SettingsSwitchTile,
      l10n.diaryCardStyleShowUntitled,
    );
    // 开关存在且默认开启。
    expect(untitledSwitch, findsOneWidget);
    expect(_stored(settings).current.content.showUntitled, isTrue);

    // 关闭后设置持久化。
    await _tapVisible(tester, untitledSwitch);
    expect(_stored(settings).current.content.showUntitled, isFalse);

    // 标题整体关闭后这个开关没有意义，随之收起。
    await _tapVisible(
      tester,
      find.widgetWithText(SettingsSwitchTile, l10n.diaryCardStyleShowTitle),
    );
    expect(_stored(settings).current.content.showTitle, isFalse);
    expect(untitledSwitch, findsNothing);
  });

  testWidgets('date choices center their radio dots beside the examples', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester);
    // 日期选项并进了「内容」分类。
    await _openTab(tester, l10n.diaryCardStyleTabContent, l10n);
    for (final label in <String>[
      l10n.diaryCardStyleDateFull,
      l10n.diaryCardStyleFooterRelative,
    ]) {
      final text = find.text(label);
      await _tapVisible(tester, text);
      final tile = find.ancestor(of: text, matching: find.byType(ListTile));
      final dot = find.descendant(of: tile, matching: find.byType(FaIcon));
      expect(
        (tester.getCenter(dot).dy - tester.getCenter(tile).dy).abs(),
        lessThan(0.5),
        reason: label,
      );
    }
  });

  testWidgets('reordering blocks inside the sheet keeps the sheet open', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    // 排序选项并进了「布局」分类。
    await _openTab(tester, l10n.diaryCardStyleTabLayout, l10n);
    // 拖动“标题”行（第二行）的手柄（拿起即拖动，不经过长按）到“标签”下方。
    // 合并后排序排在布局下方：先把手柄滚进可视区再拖，否则手势落在屏外、
    // 拖动不生效。
    final handle = find.byType(TripleBarDragHandle).at(1);
    await tester.ensureVisible(handle);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_stored(settings).current.content.blocks, <DiaryCardBlock>[
      DiaryCardBlock.eyebrow,
      DiaryCardBlock.tags,
      DiaryCardBlock.title,
      DiaryCardBlock.preview,
      DiaryCardBlock.footer,
    ]);
    expect(find.byType(DiaryCardStylePreviewToolbar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide screens use the same floating buttons and sheets', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester, size: const Size(900, 700));
    // 新版顶部工具栏（列表/瀑布流分段 + 明暗按钮）存在。
    expect(find.byType(DiaryCardStylePreviewToolbar), findsOneWidget);
    expect(find.byType(TabBarView), findsNothing);
    // 分类收进「样式设置」整页与底部导航：主页面上不直接显示分类名
    // （底部导航默认隐藏，只在树里）。
    expect(
      find.text(l10n.diaryCardStyleTabPresets).hitTestable(),
      findsNothing,
    );
    await _openTab(tester, l10n.diaryCardStyleTabLayout, l10n);
    // 选项整页是 Navigator 推入的整页，不再是 BottomSheet。
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sliders preview while dragging and persist on release', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabLayout, l10n);
    final tile = tester.widget<StyleSliderRow>(
      find.widgetWithText(StyleSliderRow, l10n.diaryCardStyleCornerRadius),
    );
    tile.onChanged!(7);
    await tester.pump();
    expect(settings.diaryCardStyleRaw, isNull);
    expect(find.text(l10n.diaryCardStyleValueDp('7')), findsOneWidget);

    tile.onChangeEnd!(7);
    await tester.pumpAndSettle();
    expect(_stored(settings).current.surface.cornerRadius, 7);
  });

  testWidgets('reset restores the default style and can be undone', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabPresets, l10n);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetMagazine));
    await _dismissSnackBars(tester);
    final magazine = DiaryCardPresets.styleOf(DiaryCardPresetId.magazine);
    expect(_stored(settings).current, magazine);

    await _closeSheet(tester, l10n);
    await tester.tap(await _openMenu(tester, l10n));
    await tester.pumpAndSettle();
    expect(settings.diaryCardStyleRaw, isNull);
    expect(find.text(l10n.styleEditorResetDone), findsOneWidget);

    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).current, magazine);
  });

  testWidgets('applying a preset can be undone', (tester) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabPresets, l10n);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetMinimal));
    expect(
      _stored(settings).current,
      DiaryCardPresets.styleOf(DiaryCardPresetId.minimal),
    );
    expect(
      find.text(l10n.styleEditorApplied(l10n.diaryCardStylePresetMinimal)),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(settings.diaryCardStyleRaw, isNull);
  });

  testWidgets('saved styles can be saved, renamed and deleted with undo', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabPresets, l10n);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetCompact));
    await _dismissSnackBars(tester);

    await _tapVisible(tester, find.text(l10n.styleEditorSaveCurrent));
    await tester.enterText(find.byType(TextField), 'Dense');
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.pumpAndSettle();
    await _dismissSnackBars(tester);
    expect(_stored(settings).saved.single.name, 'Dense');
    expect(
      _stored(settings).saved.single.style,
      DiaryCardPresets.styleOf(DiaryCardPresetId.compact),
    );

    await _tapVisible(
      tester,
      find.byTooltip(l10n.styleEditorSavedActions('Dense')),
    );
    await tester.tap(find.text(l10n.styleEditorRename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tight');
    await tester.tap(find.text(l10n.commonConfirm));
    await tester.pumpAndSettle();
    expect(_stored(settings).saved.single.name, 'Tight');

    await _tapVisible(
      tester,
      find.byTooltip(l10n.styleEditorSavedActions('Tight')),
    );
    await tester.tap(find.text(l10n.commonDelete));
    await tester.pumpAndSettle();
    expect(_stored(settings).saved, isEmpty);
    await tester.tap(find.text(l10n.commonUndo));
    await tester.pumpAndSettle();
    expect(_stored(settings).saved.single.name, 'Tight');
  });

  testWidgets('style codes are copied and imported through the clipboard', (
    tester,
  ) async {
    _mockClipboard(tester);
    final (settings, l10n) = await _pumpPage(tester);
    await _openTab(tester, l10n.diaryCardStyleTabPresets, l10n);
    await _tapVisible(tester, find.text(l10n.diaryCardStylePresetJournal));
    await _dismissSnackBars(tester);

    await _tapVisible(tester, find.text(l10n.styleEditorCopyCode));
    expect(_clipboard, startsWith('${DiaryCardStyleCode.scheme}:v1:'));
    await _dismissSnackBars(tester);

    final code = _clipboard!;
    await _closeSheet(tester, l10n);
    await tester.tap(await _openMenu(tester, l10n));
    await tester.pumpAndSettle();
    await _dismissSnackBars(tester);
    expect(settings.diaryCardStyleRaw, isNull);

    _clipboard = 'Try this one: $code';
    await _openTab(tester, l10n.diaryCardStyleTabPresets, l10n);
    await _tapVisible(tester, find.text(l10n.styleEditorImportCode));
    expect(
      _stored(settings).current,
      DiaryCardPresets.styleOf(DiaryCardPresetId.journal),
    );
    expect(
      find.text(
        l10n.styleEditorImportedNamed(l10n.diaryCardStylePresetJournal),
      ),
      findsOneWidget,
    );
    await _dismissSnackBars(tester);

    _clipboard = 'definitely not a style';
    await _tapVisible(tester, find.text(l10n.styleEditorImportCode));
    expect(find.text(l10n.styleEditorImportInvalid), findsOneWidget);
    expect(
      _stored(settings).current,
      DiaryCardPresets.styleOf(DiaryCardPresetId.journal),
    );
    await _dismissSnackBars(tester);
  });

  testWidgets('the layout toggle edits the waterfall-only options', (
    tester,
  ) async {
    final (settings, l10n) = await _pumpPage(tester);
    // 列表/瀑布流切换在顶部工具条里，先叫出控制条。
    await _showControls(tester, l10n);
    await tester.tap(find.text(l10n.autoT0147));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DiariesListSection>(find.byType(DiariesListSection))
          .layoutMode,
      DiaryLayoutMode.waterfall,
    );
    await _openTab(tester, l10n.diaryCardStyleTabLayout, l10n);
    // 布局分类里布局与封面两个 tab 各有一个“仅瀑布流”模式分组，标题相同：
    // 只断言布局 tab 里的那一个。
    expect(
      find.descendant(
        of: find.byType(DiaryCardStyleLayoutTab),
        matching: find.text(l10n.diaryCardStyleWaterfallGroup),
      ),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text(l10n.diaryCardStyleColumnsValue(3)));
    expect(_stored(settings).current.waterfall.columns, 3);
    expect(_stored(settings).current.list, DiaryCardModeStyle.listDefaults);
  });

  testWidgets('the preview can switch to the opposite brightness', (
    tester,
  ) async {
    final (_, l10n) = await _pumpPage(tester);
    Brightness previewBrightness() =>
        Theme.of(tester.element(find.byType(DiariesListSection))).brightness;
    expect(previewBrightness(), Brightness.light);
    // 明暗按钮在顶部工具条里，先叫出控制条。
    await _showControls(tester, l10n);
    await tester.tap(find.byTooltip(l10n.styleEditorPreviewDark));
    await tester.pumpAndSettle();
    expect(previewBrightness(), Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('every tab sheet fits a 320dp screen in $brightness', (
      tester,
    ) async {
      final (_, l10n) = await _pumpPage(
        tester,
        brightness: brightness,
        size: const Size(320, 640),
      );
      for (final label in <String>[
        l10n.diaryCardStyleTabPresets,
        l10n.diaryCardStyleTabLayout,
        l10n.diaryCardStyleTabContent,
        l10n.diaryCardStyleTabAppearance,
      ]) {
        await _openTab(tester, label, l10n);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
        await _closeSheet(tester, l10n);
      }
    });
  }
}
