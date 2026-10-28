// 朋友圈式时间线页预览：封面（默认渐变）+ 头像 + 昵称 + 简介 + 一条条日记
// （昵称蓝色、九宫格、长文折叠），给用户看新时间线页的效果。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/timeline_page_preview_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/timeline_page.dart';
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

Future<({AppDatabase database, SettingsService settings})> _seed() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = await SettingsService.create();
  await settings.setProfileNickname('阿柠');
  await settings.setProfileBio('山野有雾灯，往事皆可期。');
  const longBody =
      '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。\n'
      '带了卡式炉和小锅，煮了面，还烤了红薯，烟火气很足。\n'
      '半夜醒来看见满天星星，银河比照片里还要清楚。\n'
      '早上被鸟叫吵醒，帐篷外全是雾，太阳出来后慢慢散了。';
  final longDoc = <Object?>[
    {'insert': '$longBody\n'},
  ];
  final photoDoc = <Object?>[
    {'insert': '去海边玩了一天，拍了好多照片，海风很大，浪打在礁石上。\n'},
    {'insert': '\n'},
  ];
  await database.createDiary(
    title: '周末去露营',
    contentDocJson: jsonEncode(longDoc),
    contentText: longBody,
    metadataJson: '{}',
  );
  await database.createDiary(
    title: '海边的一天',
    contentDocJson: jsonEncode(photoDoc),
    contentText: '去海边玩了一天，拍了好多照片，海风很大，浪打在礁石上。',
    metadataJson: '{}',
  );
  await database.createDiary(
    title: '晨跑五公里',
    contentDocJson: '[{"insert":"今天配速比上周快了半分钟，跑完在便利店买了瓶冰水。\\n"}]',
    contentText: '今天配速比上周快了半分钟，跑完在便利店买了瓶冰水。',
    metadataJson: '{}',
  );
  return (database: database, settings: settings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('timeline page preview', (tester) async {
    tester.view.physicalSize = const Size(936, 2048);
    tester.view.devicePixelRatio = 2.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seeded = (await tester.runAsync(_seed))!;
    addTearDown(seeded.database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(seeded.database),
          settingsServiceProvider.overrideWith((ref) async => seeded.settings),
        ],
        child: MaterialApp(
          theme: const MaterialTheme(TextTheme()).light(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const TimelinePage(),
        ),
      ),
    );
    // 分页流 + 头像/封面都是异步，等几轮再截图。stream provider 常驻，
    // pumpAndSettle 永远等不到落定，用定量 pump（timeline_test 同口径）。
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(TimelinePage),
      matchesGoldenFile('goldens/timeline_page.png'),
    );
    await _flushDisposal(tester);
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}

/// 测试体结束前先把整棵树换成空 widget 再出几帧：ProviderScope 卸载时
/// drift 查询流的关闭会挂零时定时器，不在这里放掉，测试框架在收尾校验
/// （!timersPending）就会判失败，并把下一个测试也拖垮。
Future<void> _flushDisposal(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
