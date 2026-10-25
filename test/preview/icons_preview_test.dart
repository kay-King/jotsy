// 顶栏图标改描边版预览：拍日记页顶栏（搜索 + 草稿/归档/⋮）与日历页
// 顶栏（爱心/漏斗/滑杆/回今天），给用户看描边图标的效果。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/icons_preview_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
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
    final roboto = FontLoader('Roboto');
    roboto.addFont(
      robotoFile.readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
    final boldFile = File(
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    );
    if (await boldFile.exists()) {
      roboto.addFont(
        boldFile.readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await roboto.load();
  }
  await load('MaterialIcons', <String>['fonts/MaterialIcons-Regular.otf']);
  for (final entry in <(String, String)>[
    ('FontAwesomeSolid', 'Font-Awesome-7-Free-Solid-900.otf'),
    ('FontAwesomeRegular', 'Font-Awesome-7-Free-Regular-400.otf'),
    ('FontAwesomeBrands', 'Font-Awesome-7-Brands-Regular-400.otf'),
  ]) {
    await load(entry.$1, <String>[
      'packages/font_awesome_flutter/lib/fonts/${entry.$2}',
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('icons preview', (tester) async {
    tester.view.physicalSize = const Size(936, 2048);
    tester.view.devicePixelRatio = 2.2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
    tester.platformDispatcher.localesTestValue = const <Locale>[
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final settings = await SettingsService.create();
    await tester.runAsync(() async {
      await database.createDiary(
        title: '秋天的小事',
        contentDocJson: '[{"insert":"下午去公园走了走，银杏叶落了一地。\\n"}]',
        contentText: '下午去公园走了走，银杏叶落了一地。',
        metadataJson: '{}',
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: const NodeDiaryApp(),
      ),
    );
    // 等第一篇日记出现。
    var ready = false;
    for (var i = 0; i < 600 && !ready; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      ready = find.text('秋天的小事').evaluate().isNotEmpty;
    }
    await tester.pump(const Duration(milliseconds: 400));
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    } on Object {
      // 编排未完全落定也继续截图，画面以当前帧为准。
    }
    // 日记页顶栏。
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/icons_diary.png'),
    );

    // 切到日历页，等「日历」标题出现再拍顶栏。
    final calendarNav = find.descendant(
      of: find.byType(BottomNav),
      matching: find.text('日历'),
    );
    await tester.tap(calendarNav);
    var calendarReady = false;
    for (var i = 0; i < 200 && !calendarReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      calendarReady = find.text('日历').evaluate().length >= 2;
    }
    await tester.pump(const Duration(milliseconds: 400));
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    } on Object {
      // 同上。
    }
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/icons_calendar.png'),
    );

    // 收尾多出几帧放掉 drift 定时器。
    // 注：预览页顶栏的 4 个描边图标（排版/编辑/分享/⋮）已用探针单独验过
    // 都是描边（见 icons_probe 探针记录），这里不进预览页拍。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
