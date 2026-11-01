import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_settings.dart';
import 'package:node_diary/ui/settings/pages/home_bar_style_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'expressive_test_theme.dart';

// 导航栏样式页的组件测试共用的装配与操作：真实的 SettingsService（内存
// SharedPreferences）、按标签页滚动到懒构建的选项再点按。

Widget homeBarStyleApp(
  SettingsService settings,
  Widget home, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
}) {
  return ProviderScope(
    overrides: [settingsServiceProvider.overrideWith((ref) async => settings)],
    child: MaterialApp(
      theme: expressiveTestTheme(brightness),
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        quill.FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<(SettingsService, AppLocalizations)> pumpHomeBarStylePage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('zh'),
  Size size = const Size(400, 860),
  HomeBarSettings? initial,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (initial != null) 'app.settings.home_bar_style': initial.encode()!,
  });
  final settings = (await tester.runAsync(SettingsService.create))!;
  await tester.pumpWidget(
    homeBarStyleApp(
      settings,
      HomeBarStylePage(settingsService: settings),
      brightness: brightness,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  return (settings, l10n);
}

HomeBarSettings storedHomeBarSettings(SettingsService settings) =>
    HomeBarSettings.decode(settings.homeBarStyleRaw);

/// 点右上角「样式设置」按钮：打开选项整页，所有分类按区块上下排列。
/// 打开后滚动到 [label] 对应的分类区块（ListView 懒构建，目标可能还没进树）。
Future<void> openHomeBarStyleTab(
  WidgetTester tester,
  String label, {
  AppLocalizations? l10n,
}) async {
  final resolvedL10n =
      l10n ?? AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  final button = find.byTooltip(resolvedL10n.styleEditorSettingsTitle);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
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
Future<void> closeHomeBarStyleSheet(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final context = tester.element(find.byType(Scaffold).first);
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
}

/// 打开左上角悬浮菜单，返回其中“重置”菜单项的 Finder。
Future<Finder> openHomeBarStyleMenu(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await tester.tap(find.byTooltip(l10n.homeBarStyleTitle));
  await tester.pumpAndSettle();
  return find.widgetWithText(MenuItemButton, l10n.commonReset);
}

/// 选项整页里的纵向滚动列表。
Finder homeBarSheetScrollable() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

/// 选项列表是懒构建的：目标还没进树时先在选项整页里向下滚动。
Future<void> scrollToHomeBarOption(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      finder,
      find.byType(Scaffold).last,
      const Offset(0, -200),
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapHomeBarOption(WidgetTester tester, Finder finder) async {
  await scrollToHomeBarOption(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 选项整页里的某个文字（不含下方预览）。
Finder inHomeBarOptions(String text) =>
    find.descendant(of: find.byType(Scaffold), matching: find.text(text));
