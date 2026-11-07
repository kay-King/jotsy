// 样式编辑页预览：重构后的 StyleEditorScaffold（默认隐藏控制条、点预览
// 空白处显隐、底部导航 + 矮面板），卡片样式页与预览页样式页各两张。
// 主题必须用应用真实装配（Salt 蓝种子 #0470E6 + 中性表面），不用
// expressiveTestTheme：后者的种子是青色 #1E6586、无中性表面处理，
// primaryContainer/描边等角色会染上青色，预览图里的日期块、药丸选中态、
// 描边都和真机不一致。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/style_editor_preview_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/diary_card_style_page.dart';
import 'package:node_diary/ui/settings/pages/diary_preview_style_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  final robotoFile = File(
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  );
  if (await robotoFile.exists()) {
    final bytes = await robotoFile.readAsBytes();
    final boldFile = File(
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    );
    final boldBytes = await boldFile.exists()
        ? await boldFile.readAsBytes()
        : null;
    // UI 走 Roboto，正文走 HarmonyOSSansSC：同一份 CJK 字体注册两个字族，
    // 否则预览页标题/正文在测试里画成方框。
    for (final family in <String>['Roboto', 'HarmonyOSSansSC']) {
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      if (boldBytes != null) {
        loader.addFont(Future.value(ByteData.view(boldBytes.buffer)));
      }
      // 心情 emoji（😊🤩😐…）不在 NotoSansCJK 里：把系统彩色 emoji 并进
      // 同一字族，测得到就显示，测不到也只是心情处一个方框、不影响布局。
      final emojiFile = File(
        '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
      );
      if (await emojiFile.exists()) {
        final emojiBytes = await emojiFile.readAsBytes();
        loader.addFont(Future.value(ByteData.view(emojiBytes.buffer)));
      }
      await loader.load();
    }
  }
  await load('MaterialIcons', <String>['fonts/MaterialIcons-Regular.otf']);
  // FaIcon 的 IconData 带 fontPackage，引擎按
  // 'packages/font_awesome_flutter/<字族>' 查字体：只注册裸字族名画出
  // 来是方框（既有 icons_diary golden 里的底栏图标就是这么缺的），
  // 必须再按包名前缀注册一份。
  for (final entry in <(String, String)>[
    ('FontAwesomeSolid', 'Font-Awesome-7-Free-Solid-900.otf'),
    ('FontAwesomeRegular', 'Font-Awesome-7-Free-Regular-400.otf'),
    ('FontAwesomeBrands', 'Font-Awesome-7-Brands-Regular-400.otf'),
  ]) {
    await load(entry.$1, <String>[
      'packages/font_awesome_flutter/lib/fonts/${entry.$2}',
    ]);
    await load('packages/font_awesome_flutter/${entry.$1}', <String>[
      'packages/font_awesome_flutter/lib/fonts/${entry.$2}',
    ]);
  }
}

const _size = Size(360, 800);

Future<void> _setUpView(WidgetTester tester) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
  tester.platformDispatcher.localesTestValue = const <Locale>[
    Locale('zh', 'CN'),
  ];
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

Future<SettingsService> _createSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return (await tester.runAsync(SettingsService.create))!;
}

Future<AppLocalizations> _pumpCardPage(WidgetTester tester) async {
  await _setUpView(tester);
  final settings = await _createSettings(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // 用应用真实主题装配（见文件头注释），不用青色种子的测试主题。
      theme: buildSeededAppTheme(const Color(0xff0470e6), Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiaryCardStylePage(settingsService: settings),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
}

Future<AppLocalizations> _pumpPreviewPage(WidgetTester tester) async {
  await _setUpView(tester);
  final settings = await _createSettings(tester);
  // 预览页会触到数据库（示例内容读库）：用内存库挡掉真实 path_provider。
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // 用应用真实主题装配（见文件头注释），不用青色种子的测试主题。
        theme: buildSeededAppTheme(const Color(0xff0470e6), Brightness.light),
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
  return AppLocalizations.of(tester.element(find.byType(Scaffold).first));
}

/// 控制条默认隐藏：点预览顶部空白处叫出来（已显示时不再点）。
/// 顶部几像素是预览上方的留白，不会点中示例卡片等可交互元素。
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

/// 点底部导航的第一个分类（预设），打开矮设置面板。
/// 面板收起时仍在树里、标题就是分类名（滑到屏外），所以必须把查找范围
/// 限定在底部导航里，否则会点中屏外的面板标题、面板打不开。
/// 导航按 key 定位：tab 放得下时居中排布（没有横向滚动视图），只有真
/// 溢出时才横向滚动，不能再靠 SingleChildScrollView 找导航。
Future<void> _openFirstTab(
  WidgetTester tester,
  String label,
  AppLocalizations l10n,
) async {
  await _showControls(tester, l10n);
  final nav = find.byKey(const ValueKey('style_editor_bottom_nav_bar'));
  await tester.tap(find.descendant(of: nav, matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('style editor card page default', (tester) async {
    await _pumpCardPage(tester);
    await _capture(tester, 'style_editor_card_default');
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');

  testWidgets('style editor card page controls', (tester) async {
    final l10n = await _pumpCardPage(tester);
    await _openFirstTab(tester, l10n.diaryCardStyleTabPresets, l10n);
    await _capture(tester, 'style_editor_card_controls');
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');

  testWidgets('style editor preview page default', (tester) async {
    await _pumpPreviewPage(tester);
    await _capture(tester, 'style_editor_preview_default');
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');

  testWidgets('style editor preview page controls', (tester) async {
    final l10n = await _pumpPreviewPage(tester);
    await _openFirstTab(tester, l10n.diaryPreviewStyleTabPresets, l10n);
    await _capture(tester, 'style_editor_preview_controls');
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
