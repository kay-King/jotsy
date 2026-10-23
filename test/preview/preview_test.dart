// 主题预览渲染台：把真实 App 页面按用户手机尺寸渲成 PNG，供改版时
// 先看图再打包。默认跳过（CI 不受影响），手动运行：
//   JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/preview_test.dart
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
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  // 测试环境不会自动加载 pubspec 字体与图标字体，手动喂给渲染器，
  // 否则文字与图标全是方框。一律走 rootBundle（资源包里都有）。
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  // App 已不指定 UI 字体（走系统默认）：字阶的字体名回落到 Roboto，
  // 把宿主机 Noto Sans CJK 注册到 Roboto 名下模拟系统黑体观感
  // （用户手机上届时会是其系统字体，这里只看字形气质与比例、间距）。
  final roboto = FontLoader('Roboto');
  for (final path in <String>[
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
  ]) {
    roboto.addFont(
      File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await roboto.load();
  // emoji 字体：不加载时心情符号等 emoji 在预览里是方框占位（手机上有
  // 系统 emoji 字体，不受影响）。
  final emoji = FontLoader('Noto Color Emoji');
  emoji.addFont(
    File(
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    ).readAsBytes().then((b) => ByteData.view(b.buffer)),
  );
  await emoji.load();
  await load('MaterialIcons', <String>['fonts/MaterialIcons-Regular.otf']);
  // FontAwesome 在引擎里按「包名/字体名」注册，只写裸名图标会变方框。
  for (final entry in <(String, String)>[
    ('FontAwesomeSolid', 'Font-Awesome-7-Free-Solid-900.otf'),
    ('FontAwesomeRegular', 'Font-Awesome-7-Free-Regular-400.otf'),
    ('FontAwesomeBrands', 'Font-Awesome-7-Brands-Regular-400.otf'),
  ]) {
    final asset = 'packages/font_awesome_flutter/lib/fonts/${entry.$2}';
    await load(entry.$1, <String>[asset]);
    await load('packages/font_awesome_flutter/${entry.$1}', <String>[asset]);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets(
    'render preview pages',
    (tester) async {
      final suffix =
          Platform.environment['JOTSY_PREVIEW_FONT'] == 'system'
          ? '_system'
          : '';
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
      // 塞几篇示例日记，让首页渲出来是带列表和悬浮按钮的真实样子，
      // 而不是空状态。
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
      for (var frame = 0; frame < 120; frame++) {
        if (find.byType(HomePage).evaluate().isNotEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byType(HomePage), findsOneWidget);
      // 骨架出现不等于内容就绪：启动遮罩与日记列表流走的是真实异步，
      // 等第一篇示例日记真的画出来再截图，否则拍到的是白色遮罩帧。
      for (var frame = 0; frame < 300; frame++) {
        if (find.text('秋天的小事').evaluate().isNotEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 800));
      await expectLater(
        find.byType(HomePage),
        matchesGoldenFile('goldens/home$suffix.png'),
      );

      // 设置主页
      await tester.tap(find.text('设置').last);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_root$suffix.png'),
      );

      // 外观与语言页
      await tester.tap(find.text('外观与语言'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/appearance$suffix.png'),
      );
      // 返回设置主页：点顶栏返回键（pageBack 对嵌套导航不可靠）。
      await tester.tap(find.byType(IconButton).first);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      // 编辑器设置页
      await tester.ensureVisible(find.text('编辑器设置'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('编辑器设置'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/editor_settings$suffix.png'),
      );

      // 先从编辑器页返回设置主页
      await tester.tap(find.byType(IconButton).first);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      // 关于页
      await tester.ensureVisible(find.text('关于'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('关于'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/about$suffix.png'),
      );
      await tester.tap(find.byType(IconButton).first);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      // 标签管理页
      await tester.ensureVisible(find.text('标签管理'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('标签管理'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tags$suffix.png'),
      );
      await tester.tap(find.byType(IconButton).first);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      // 编辑器设置 → 心情符号页（最后拍：该页返回可能带确认弹窗）
      await tester.ensureVisible(find.text('编辑器设置'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('编辑器设置'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('心情符号'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('心情符号'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mood$suffix.png'),
      );
    },
    skip: Platform.environment['JOTSY_PREVIEW'] != '1',
  );
}
