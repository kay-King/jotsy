// 日记列表预览：拍日记页（底栏第二个 Tab）——竖版通栏大图 + 大字 +
// 宽松间距的高级感卡片，给用户看新列表效果。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/diary_list_preview_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/node_diary_app.dart';
import 'package:node_diary/ui/widgets/bottom_nav.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
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

/// 纯 Dart 编 PNG（首帧前调 dart:ui Picture.toImage 会挂住，见 timeline
/// 预览的教训）：200×200 单色图，供封面缩略图用。
List<int> _solidColorPng(int size, int r, int g, int b) {
  final raw = <int>[];
  for (var y = 0; y < size; y++) {
    raw.add(0);
    for (var x = 0; x < size; x++) {
      raw.addAll(<int>[r, g, b]);
    }
  }
  final idat = zlib.encode(raw);
  List<int> chunk(String type, List<int> data) {
    final out = <int>[];
    out.addAll(_u32(data.length));
    out.addAll(type.codeUnits);
    out.addAll(data);
    final crcInput = <int>[...type.codeUnits, ...data];
    out.addAll(_u32(_crc32(crcInput)));
    return out;
  }

  final out = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  out.addAll(chunk('IHDR', <int>[..._u32(size), ..._u32(size), 8, 2, 0, 0, 0]));
  out.addAll(chunk('IDAT', idat));
  out.addAll(chunk('IEND', <int>[]));
  return out;
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

/// 造 3 篇日记（今天带封面 + 2 张图、昨天、3 天前：总数 3 篇、连续 2 天）。
/// 全部准备工作（设置、临时图片、写库）都包在 runAsync 里做，和
/// explore_stats_test 同一套路：直接 await 真异步会卡在测试的 fake
/// async 里。
Future<({AppDatabase database, SettingsService settings})> _seed() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = await SettingsService.create();
  final tempDir = await Directory.systemTemp.createTemp('jotsy_diarylist_');
  final coverPath = await _writeColorPng(
    tempDir,
    'cover.png',
    const Color(0xFF7FB069),
  );
  final secondPath = await _writeColorPng(
    tempDir,
    'second.png',
    const Color(0xFF4A90D9),
  );
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

  // 真实当天是 2026-10-25（周日），问候语按当时的小时出（测试跑在
  // 白天一般是“早上好/中午好/下午好”）。
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 21);
  final yesterday = today.subtract(const Duration(days: 1));
  await addDiary(
    title: '周末去露营',
    text: '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。',
    createdAt: today,
    images: <String>[coverPath, secondPath],
    cover: coverPath,
  );
  await addDiary(
    title: '海边的一天',
    text: '去海边玩了一天，拍了好多照片，海风很大。',
    createdAt: yesterday,
    images: <String>[secondPath],
    cover: secondPath,
  );
  await addDiary(
    title: '晨跑五公里',
    text: '今天配速比上周快了半分钟，跑完在便利店买了瓶冰水。',
    createdAt: today.subtract(const Duration(days: 3)),
  );
  return (database: database, settings: settings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('diary list preview', (tester) async {
    tester.view.physicalSize = const Size(936, 2048);
    tester.view.devicePixelRatio = 2.2;
    addTearDown(tester.view.reset);
    // 区域设置要在 SettingsService.create 之前定，否则整页变英文。
    tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
    tester.platformDispatcher.localesTestValue = const <Locale>[
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final seeded = (await tester.runAsync(_seed))!;
    final database = seeded.database;
    final settings = seeded.settings;
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: const NodeDiaryApp(),
      ),
    );
    // 首帧是桌面 Tab：等“最近记录”出现，再点底栏“日记”进列表。
    var ready = false;
    for (var i = 0; i < 600 && !ready; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      ready = find.text('最近记录').evaluate().isNotEmpty;
    }
    await tester.tap(
      find.descendant(of: find.byType(BottomNav), matching: find.text('日记')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    // 等第一篇日记的标题画出来。
    var listReady = false;
    for (var i = 0; i < 600 && !listReady; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      listReady = find.text('周末去露营').evaluate().isNotEmpty;
    }
    // 封面图是真实异步加载，多给几帧落定。
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
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
      matchesGoldenFile('goldens/diary_list.png'),
    );

    // 收尾多出几帧放掉 drift 定时器。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
