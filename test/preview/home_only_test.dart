// 首页专用截图台：只拍带示例日记的首页（给主题改造看悬浮钮/底栏）。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/home_only_test.dart
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
import 'package:node_diary/ui/home/widgets/home_bar/home_create_fab.dart';
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

  testWidgets('home only', (tester) async {
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
      const samples = <(String, String)>[
        ('秋天的小事', '下午去公园走了走，银杏叶落了一地，风里已经有凉意了。'),
        ('晨跑五公里', '今天配速比上周快了半分钟，跑完在便利店买了瓶冰水。'),
        ('给妈妈打电话', '聊了快一个小时，她说院子里的石榴熟了，周末回去摘。'),
        ('读书笔记', '云边有个小卖部，读到外婆那段还是忍不住鼻子发酸。'),
      ];
      for (final (title, body) in samples) {
        await database.createDiary(
          title: title,
          contentDocJson: '[{"insert":"$body\\n"}]',
          contentText: body,
          metadataJson: '{}',
        );
      }
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
    // 等悬浮钮与第一篇日记都出现（真实异步驱动，不用 pumpAndSettle，
    // 免得被应用内的周期计时器拖住）。
    var ready = false;
    for (var i = 0; i < 600 && !ready; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      ready =
          find.byType(HomeCreateFab).evaluate().isNotEmpty &&
          find.text('秋天的小事').evaluate().isNotEmpty;
    }
    // ignore: avoid_print
    print(
      'HOME_PROBE ready=$ready '
      'fab=${find.byType(HomeCreateFab).evaluate().length} '
      'title=${find.text('秋天的小事').evaluate().length}',
    );
    await tester.pump(const Duration(milliseconds: 400));
    // 启动揭幕动画（LaunchReveal 的共享进度）要靠持续出帧推进，
    // 纯 pump 假时间推不动它，最后用 pumpAndSettle 把编排走完。
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    } on Object {
      // 编排未完全落定也继续截图，画面以当前帧为准。
    }
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/home_only.png'),
    );
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
