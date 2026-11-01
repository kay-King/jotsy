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
  // 注意：find.byTooltip 是懒求值的，ensureVisible 会重新求值；
  // 实测中两次求值结果不一致（1 个变 2 个），故直接取 .first 固化，
  // 顶栏按钮恒可见，无需 ensureVisible。
  final button = find
      .byTooltip(resolvedL10n.styleEditorSettingsTitle)
      .first;
  await tester.tap(button);
  await tester.pumpAndSettle();
  // 注意：分类标题文本可能在区块内容里重复出现（如分组标题），
  // 但区块头在树中排在内容之前，操作时取 .first 固化。
  if (find.text(label).evaluate().isEmpty) {
    // 懒构建还没进树：向下滚动触发构建。不直接用 dragUntilVisible(find.text(label))，
    // 因为滚动过程中文本可能出现多次导致其内部 element() 报 Too many elements。
    final scrollable = find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            widget.axisDirection == AxisDirection.down &&
            widget.physics is AlwaysScrollableScrollPhysics,
      ),
    );
    // 最多滚 10 次，每次 500px，直到文本出现。
    for (int i = 0; i < 10 && find.text(label).evaluate().isEmpty; i++) {
      await tester.drag(scrollable.first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
  } else {
    await tester.ensureVisible(find.text(label).first);
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

/// 选项整页里的纵向滚动列表（取最后一个 Scaffold 里的主 ListView，
/// 排除内嵌的 NeverScrollableScrollPhysics 滚动区）。
Finder homeBarSheetScrollable() => find.descendant(
  of: find.byType(Scaffold).last,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        widget.axisDirection == AxisDirection.down &&
        widget.physics is AlwaysScrollableScrollPhysics,
  ),
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
  // 取 .first 固化，避免文本在页内重复时 ensureVisible 重求值报 Too many elements。
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> tapHomeBarOption(WidgetTester tester, Finder finder) async {
  await scrollToHomeBarOption(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// 选项整页里的某个文字（取最后一个 Scaffold，避免命中底下主预览页）。
Finder inHomeBarOptions(String text) => find.descendant(
  of: find.byType(Scaffold).last,
  matching: find.text(text),
);
