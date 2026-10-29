// 暖阳预设预览：日记列表（列表布局）——暖复古风：通栏大图、奶油底色、
// 橘色大日期与标题同行、右下角媒体徽章，给用户看新预设效果。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/warm_preset_preview_test.dart
//
// 注意：这里只渲染日记列表（与卡片矩阵测试同一套路），不经过整机 App。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_view_data.dart';
import 'package:path/path.dart' as p;

import '../support/expressive_test_theme.dart';

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

/// 写两张纯色封面（暖金、柔绿）供预览用；真实异步加载放在 runAsync 里做。
Future<({String goldCover, String greenCover})> _seedCovers() async {
  final tempDir = await Directory.systemTemp.createTemp('jotsy_warm_preset_');
  final goldCover = await _writeColorPng(
    tempDir,
    'gold.png',
    const Color(0xFFD9A441),
  );
  final greenCover = await _writeColorPng(
    tempDir,
    'green.png',
    const Color(0xFF7FB069),
  );
  return (goldCover: goldCover, greenCover: greenCover);
}

/// 今天这篇的正文：以“世界很美好”开头，照原版截图里标题“123”+ 摘要
/// “世界很美好”的样子。
const _todayText =
    '世界很美好。今天天气很好，阳光洒在窗台上，菊花开得正盛。上午去公园散步，湖边的风很轻，吹得人心里很安静。回来路上买了一束花，放在书桌上，整个房间都香了起来。晚上坐在窗边看书，日子就是这样，平平淡淡的，却让人觉得很踏实，明天也要好好生活。今天真好。';

List<DiaryWithTags> _diaries({
  required String goldCover,
  required String greenCover,
}) {
  Diary diary(
    String id, {
    required String title,
    required String text,
    required DateTime createdAt,
    String? cover,
    String? image,
  }) {
    final embeds = image == null
        ? ''
        : '{"insert":{"image":"$image"}},';
    return Diary(
      id: id.hashCode,
      diaryId: 'warm_$id',
      title: title,
      content:
          '[$embeds{"insert":"$text\\n"}]',
      contentText: text,
      metadata: '{}',
      cover: cover,
      createdAt: createdAt,
      updatedAt: createdAt,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    );
  }

  // 真实当天是 2026-10-28（周三），第一张卡的大日期就是“28 · 10月 周三”，
  // 与参考图一致；标题“123”+ 摘要“世界很美好”也照原版截图。
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 21);
  final yesterday = today.subtract(const Duration(days: 1));
  return <DiaryWithTags>[
    DiaryWithTags(
      diary: diary(
        'today',
        title: '123',
        text: _todayText,
        createdAt: today,
        cover: goldCover,
        image: goldCover,
      ),
      tags: const <Tag>[],
    ),
    DiaryWithTags(
      diary: diary(
        'yesterday',
        title: '海边的一天',
        text: '去海边玩了一天，拍了好多照片，海风很大。',
        createdAt: yesterday,
        cover: greenCover,
        image: greenCover,
      ),
      tags: const <Tag>[],
    ),
    DiaryWithTags(
      diary: diary(
        'threeDaysAgo',
        title: '晨跑五公里',
        text: '今天配速比上周快了半分钟，跑完在便利店买了瓶冰水。',
        createdAt: today.subtract(const Duration(days: 3)),
      ),
      tags: const <Tag>[],
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  setUp(DiaryCardViewData.debugClearCache);

  testWidgets('warm preset preview', (tester) async {
    tester.view.physicalSize = const Size(864, 1536);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
    tester.platformDispatcher.localesTestValue = const <Locale>[
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final covers = (await tester.runAsync(_seedCovers))!;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              DiariesListSection(
                diaries: _diaries(
                  goldCover: covers.goldCover,
                  greenCover: covers.greenCover,
                ),
                layoutMode: DiaryLayoutMode.list,
                selectedDiaryIds: const <String>{},
                isSelectionMode: false,
                maxVisibleTags: 3,
                onCreate: () {},
                onOpenEditor: (_, _) {},
                onToggleSelection: (_, _) {},
                cardStyle: DiaryCardPresets.styleOf(DiaryCardPresetId.warm),
              ),
            ],
          ),
        ),
      ),
    );
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
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/warm_preset.png'),
    );

    // 收尾多出几帧放掉定时器。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
