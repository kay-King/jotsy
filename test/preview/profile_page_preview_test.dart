// 个人资料页预览台：首页进设置页再进个人资料。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/profile_page_preview_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:path/path.dart' as p;
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

/// 生成一张纯色 PNG，供九宫格预览用（真机上是相册照片）。
///
/// 纯 Dart 编码，不经过 dart:ui：首帧还没出之前调 `Picture.toImage`
/// 会一直等不到光栅任务，上一版预览就是挂在这里跑满 10 分钟超时。
List<int> _solidColorPng(int size, int r, int g, int b) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // 每行 filter: none
    for (var x = 0; x < size; x++) {
      raw.add(<int>[r, g, b]);
    }
  }
  final compressed = ZLibEncoder().convert(raw.toBytes());
  final out = BytesBuilder();
  out.add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typeBytes = type.codeUnits;
    out.add(_u32(data.length));
    out.add(typeBytes);
    out.add(data);
    out.add(_u32(_crc32(<int>[...typeBytes, ...data])));
  }

  final ihdr = BytesBuilder()
    ..add(_u32(size))
    ..add(_u32(size))
    ..add(<int>[8, 2, 0, 0, 0]); // 8 位、RGB、压缩/过滤/隔行均为 0
  chunk('IHDR', ihdr.toBytes());
  chunk('IDAT', compressed);
  chunk('IEND', <int>[]);
  return out.toBytes();
}

List<int> _u32(int value) => <int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crc32Table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

final List<int> _crc32Table = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

Future<String> _writeColorPng(Directory dir, String name, Color color) async {
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(
    _solidColorPng(
      200,
      (color.r * 255.0).round().clamp(0, 255),
      (color.g * 255.0).round().clamp(0, 255),
      (color.b * 255.0).round().clamp(0, 255),
    ),
  );
  return file.path;
}

Future<({AppDatabase database, SettingsService settings})> _seed() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = await SettingsService.create();
  final tempDir = await Directory.systemTemp.createTemp('jotsy_timeline_');
  final colors = <Color>[
    const Color(0xFF7FB069),
    const Color(0xFF4A90D9),
    const Color(0xFFE07A5F),
    const Color(0xFFF2CC8F),
    const Color(0xFF9B7EBD),
  ];
  final imagePaths = <String>[];
  for (var i = 0; i < colors.length; i++) {
    imagePaths.add(await _writeColorPng(tempDir, 'img$i.png', colors[i]));
  }
  const longBody =
      '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。\n'
      '带了卡式炉和小锅，煮了面，还烤了红薯，烟火气很足。\n'
      '半夜醒来看见满天星星，银河比照片里还要清楚。\n'
      '早上被鸟叫吵醒，帐篷外全是雾，太阳出来后慢慢散了。\n'
      '收帐篷的时候发现鞋带上沾了露水，裤脚也湿了一截。\n'
      '下山路上摘了几颗野草莓，酸酸的，但很好吃。\n'
      '回来路上一直在想，下次要带个吊床，睡在两棵树中间。\n'
      '这次没带够水，下次记得多带两瓶，还要带驱蚊液。';
  final longDoc = <Object?>[
    {'insert': '$longBody\n'},
  ];
  final photoDoc = <Object?>[
    {'insert': '去海边玩了一天，拍了好多照片，海风很大，浪打在礁石上。\n'},
    for (final path in imagePaths)
      {
        'insert': {'image': path},
      },
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

/// 区域设置必须在 [SettingsService.create] 之前定好：创建时会按当前系统语言
/// 解析初始语言，晚了就解析成英文，整页文案跟着变英文（上一版预览全是英文
/// 就是这个原因）。
void _setLocale(WidgetTester tester) {
  tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
  tester.platformDispatcher.localesTestValue = const <Locale>[
    Locale('zh', 'CN'),
  ];
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppDatabase database,
  SettingsService settings,
) async {
  tester.view.physicalSize = const Size(936, 2048);
  tester.view.devicePixelRatio = 2.2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: const NodeDiaryApp(),
    ),
  );
}

Future<void> _waitReady(WidgetTester tester, String probe) async {
  var ready = false;
  for (var i = 0; i < 600 && !ready; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    ready =
        find.byType(HomeCreateFab).evaluate().isNotEmpty &&
        find.text(probe).evaluate().isNotEmpty;
  }
  // ignore: avoid_print
  print('TIMELINE_PROBE ready=$ready probe=$probe');
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
}

/// 测试体结束前先把整棵树换成空 widget 再出几帧：ProviderScope 卸载时
/// drift 查询流的关闭会挂零时定时器，不在这里放掉，测试框架在收尾校验
/// （!timersPending）就会判失败，并把下一个测试也拖垮。
Future<void> _flushDisposal(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // 关闭是级联的：每出一帧放掉一批零时定时器、下一批才挂上来，2 帧不够，
  // 10 帧才放干净（3 帧时收尾校验仍能看到残留定时器）。
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('profile page', (tester) async {
    _setLocale(tester);
    final seeded = (await tester.runAsync(_seed))!;
    addTearDown(seeded.database.close);
    await _pumpApp(tester, seeded.database, seeded.settings);
    // 桌面有“最近记录”即就绪（日记标题不在桌面上，之前等“周末去露营”
    // 永远等不到；v16 起首页默认是桌面）。
    await _waitReady(tester, '最近记录');
    // 底栏切到设置页，再进个人资料。标签切换是动画，出几帧等新页落定。
    // 桌面上也有“设置”快捷入口，点底栏必须限定在 BottomNav 内找。
    await tester.tap(
      find.descendant(of: find.byType(BottomNav), matching: find.text('设置')),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print(
      'PROFILE_PROBE settings=${find.text('设置').evaluate().length} '
      'profile=${find.text('个人资料').evaluate().length}',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('个人资料'));
    await tester.pump(const Duration(milliseconds: 400));
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 50),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    } on Object {
      // 同上，落定与否都截图。
    }
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/profile_page.png'),
    );
    await _flushDisposal(tester);
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
