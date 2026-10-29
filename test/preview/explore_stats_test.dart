// 合并后的首页统计（概况卡）与相册（年/月/日视图 + 布局子菜单）预览台。
// 首页就是原来的探索页内容（概况卡在最上），所以不用再切 Tab。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/explore_stats_test.dart
//
// 字体加载与纯色 PNG 编码与 timeline_test.dart 里的是同一份（预览台之间
// 不互相 import，复制一份更稳）。
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

/// 纯 Dart 编 PNG（不经过 dart:ui，见 timeline_test.dart 的注释）。
List<int> _solidColorPng(int size, int r, int g, int b) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0);
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
    ..add(<int>[8, 2, 0, 0, 0]);
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

/// 跨 6 个月造数据：月度柱、6 个月走势、热力图、时段分布、相册两月都有数。
Future<({AppDatabase database, SettingsService settings})> _seed() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = await SettingsService.create();
  final tempDir = await Directory.systemTemp.createTemp('jotsy_explore_');
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
  // 九月那篇用另外 3 张图：同一文件会被去重，否则 9 月筛选项出不来。
  final sepColors = <Color>[
    const Color(0xFF5B8C5A),
    const Color(0xFFD9A441),
    const Color(0xFF7C6BD9),
  ];
  final sepImagePaths = <String>[];
  for (var i = 0; i < sepColors.length; i++) {
    sepImagePaths.add(await _writeColorPng(tempDir, 'sep$i.png', sepColors[i]));
  }

  Future<void> addDiary({
    required String title,
    required String text,
    required DateTime createdAt,
    List<String> images = const <String>[],
    String? cover,
  }) async {
    final doc = <Object?>[
      {'insert': '$text\n'},
    ];
    if (images.isNotEmpty) {
      doc.addAll([
        for (final path in images)
          {
            'insert': {'image': path},
          },
        {'insert': '\n'},
      ]);
    }
    await database.createDiary(
      title: title,
      contentDocJson: jsonEncode(doc),
      contentText: text,
      metadataJson: '{}',
      cover: cover,
      createdAtOverride: createdAt,
    );
  }

  // 2026-10-25 是周日；各篇多放在 21 点，时段结论落在晚上。
  const longBody =
      '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。\n'
      '带了卡式炉和小锅，煮了面，还烤了红薯，烟火气很足。\n'
      '半夜醒来看见满天星星，银河比照片里还要清楚。\n'
      '早上被鸟叫吵醒，帐篷外全是雾，太阳出来后慢慢散了。';
  await addDiary(
    title: '周末去露营',
    text: longBody,
    createdAt: DateTime(2026, 10, 25, 21),
  );
  await addDiary(
    title: '海边的一天',
    text: '去海边玩了一天，拍了好多照片，海风很大，浪打在礁石上。',
    createdAt: DateTime(2026, 10, 24, 21),
    images: imagePaths,
    // 有封面时探索页的媒体画廊卡才有缩略图（概览只取封面）。
    cover: imagePaths[0],
  );
  await addDiary(
    title: '晨跑五公里',
    text: '今天配速比上周快了半分钟，跑完在便利店买了瓶冰水。',
    createdAt: DateTime(2026, 10, 22, 21),
  );
  // 一天 800 字：热力图最深档。
  await addDiary(
    title: '秋天的小事',
    text: '秋天来了。' * 200,
    createdAt: DateTime(2026, 10, 18, 9),
  );
  await addDiary(
    title: '加班到深夜',
    text: '今天又加班到十一点！回来路上买了关东煮，热乎乎的。',
    createdAt: DateTime(2026, 10, 11, 21),
  );
  await addDiary(
    title: '十月第一天',
    text: '十月第一天，天气转凉，翻出了去年的外套，口袋里还有一张旧车票。',
    createdAt: DateTime(2026, 10, 3, 21),
  );
  await addDiary(
    title: '山顶的日出',
    text: '凌晨四点起床爬山看日出，云海翻腾，太阳出来的一刻大家都安静了。',
    createdAt: DateTime(2026, 9, 20, 21),
    images: sepImagePaths,
  );
  await addDiary(
    title: '九月的中旬',
    text: '九月中旬了，桂花开始香了，楼下的小店换上了秋天的菜单。',
    createdAt: DateTime(2026, 9, 12, 21),
  );
  await addDiary(
    title: '八月末的雨',
    text: '八月末下了场大雨，阳台的花被打蔫了，雨后空气很清新。',
    createdAt: DateTime(2026, 8, 30, 21),
  );
  await addDiary(
    title: '七月流火',
    text: '七月真热啊，蝉鸣从早叫到晚，冰镇西瓜是续命神器。',
    createdAt: DateTime(2026, 7, 15, 21),
  );
  await addDiary(
    title: '六月初夏',
    text: '六月了，初夏的风很舒服，傍晚去河边散步，看人钓鱼。',
    createdAt: DateTime(2026, 6, 5, 21),
  );
  await addDiary(
    title: '五月花开',
    text: '五月的花开得正好，公园里全是拍照的人，我也凑了张热闹……😀',
    createdAt: DateTime(2026, 5, 20, 21),
  );
  return (database: database, settings: settings);
}

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
  print('EXPLORE_PROBE ready=$ready probe=$probe');
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

/// 等某段文案出现（探索页统计是异步聚合的，加载完才有）。
Future<void> _waitForText(WidgetTester tester, String text) async {
  var found = false;
  for (var i = 0; i < 600 && !found; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    found = find.text(text).evaluate().isNotEmpty;
  }
  // ignore: avoid_print
  print('EXPLORE_PROBE found=$found text=$text');
}

/// 磁盘图片解码走真实异步：多等几轮真时间再截图，否则格子占了位、
/// 图片还是空白。
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  } on Object {
    // 落定与否都继续。
  }
}

/// 把含某段文案的卡滚到视口里。scrollUntilVisible 内部取目标 widget 时
/// 要求 finder 唯一，万一匹配到多个就退回固定拖拽。步长 50：上一次用 200
/// 时最后一步冲过了头，趋势图标题被顶出视口，节奏卡只拍到下半截。
Future<void> _scrollTo(WidgetTester tester, String text) async {
  try {
    await tester.scrollUntilVisible(find.text(text), 50);
  } on Object {
    await tester.drag(find.byType(NodeDiaryApp), const Offset(0, -900));
  }
  await _settle(tester);
}

/// 见 timeline_test.dart：测试体结束前先把整棵树换成空 widget 再出几帧，
/// 把 drift 查询流关闭时挂的零时定时器放干净。
Future<void> _flushDisposal(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('explore stats and gallery', (tester) async {
    _setLocale(tester);
    final seeded = (await tester.runAsync(_seed))!;
    addTearDown(seeded.database.close);
    await _pumpApp(tester, seeded.database, seeded.settings);
    await _waitReady(tester, '周末去露营');
    // 概况卡标题（热力图 / 节奏 / 内容三段已下线，2026-10-25）。
    await _waitForText(tester, '概况');
    await _settleImages(tester);
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/explore_top.png'),
    );
    // 滚到底，进媒体画廊（月视图：第一段标题行右边带 ⋮）。
    await _scrollTo(tester, '媒体画廊');
    await tester.tap(find.text('媒体画廊'));
    await _waitForText(tester, '2026年10月');
    await _settleImages(tester);
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/gallery.png'),
    );
    // 点第一段标题行右边的 ⋮，进布局子菜单（视图 / 每行数量 / 排序）。
    // 注意：别用 FaIcon 谓词找它——树里 FaIcon 的 icon 与
    // FontAwesomeIcons.ellipsisVertical 的 codePoint 相同但 == 为 false
    //（IconData 的 == 对类型敏感）；按 tooltip 找 IconButton 最稳。
    await tester.tap(find.byTooltip('显示布局'));
    await _waitForText(tester, '视图');
    await _settle(tester);
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/gallery_filter.png'),
    );
    // 切到日视图验证按天分段：点遮罩关掉子菜单再拍。
    await tester.tap(find.text('日视图'));
    await tester.tapAt(const Offset(200, 150));
    await _settle(tester);
    await expectLater(
      find.byType(NodeDiaryApp),
      matchesGoldenFile('goldens/gallery_day.png'),
    );
    await _flushDisposal(tester);
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
