import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_day_photos_controller.dart';
import 'package:node_diary/ui/diaries/pages/diary_day_photo_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_day_photos/diary_day_photo_badges.dart';
import 'package:node_diary/ui/diaries/widgets/diary_day_photos/diary_day_photo_tile.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_day_photo_library.dart';

/// “这天的照片”预览页与格子的独立测试：不经过编辑页（不依赖数据库），只
/// 验证翻看、勾选、插入返回与视频时长显示。
void main() {
  final day = DateTime(2026, 10, 12);
  final breakfast = DayPhoto(id: 'a', takenAt: DateTime(2026, 10, 12, 8));
  final clip = DayPhoto(
    id: 'v',
    takenAt: DateTime(2026, 10, 12, 12),
    width: 1920,
    height: 1080,
    isVideo: true,
    duration: const Duration(seconds: 23),
  );
  final hike = DayPhoto(id: 'c', takenAt: DateTime(2026, 10, 12, 14));

  Future<DiaryDayPhotosController> readyController(WidgetTester tester) async {
    final library = FakeDayPhotoLibrary(
      photosByDay: {
        day: [breakfast, clip, hike],
      },
    );
    final controller = DiaryDayPhotosController(library: library);
    addTearDown(controller.dispose);
    controller.configure(day: day, autoShow: true);
    // 控制器的读取是 fire-and-forget 的异步链：离开假时钟等它跑完（直接
    // await 一个零延时在 testWidgets 里等不到假时钟推进）。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(controller.photos, [breakfast, clip, hike]);
    return controller;
  }

  Future<AppLocalizations> pumpPreview(
    WidgetTester tester,
    DiaryDayPhotosController controller, {
    int initialIndex = 0,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiaryDayPhotoPreviewPage(
          controller: controller,
          photos: controller.photos,
          initialIndex: initialIndex,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byType(DiaryDayPhotoPreviewPage)).l10n;
  }

  Finder inPreview(Finder finder) => find.descendant(
    of: find.byType(DiaryDayPhotoPreviewPage),
    matching: finder,
  );

  test('dayPhotoDurationLabel formats like the gallery', () {
    expect(dayPhotoDurationLabel(const Duration(seconds: 23)), '0:23');
    expect(dayPhotoDurationLabel(const Duration(seconds: 0)), '0:00');
    expect(
      dayPhotoDurationLabel(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  testWidgets('the tile previews on tap and toggles on the check circle', (
    tester,
  ) async {
    var previews = 0;
    var toggles = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 76,
              child: DiaryDayPhotoTile(
                image: MemoryImage(kTinyPng),
                selected: false,
                inserted: false,
                semanticLabel: '12:00 video',
                videoDuration: const Duration(seconds: 23),
                onToggle: () => toggles++,
                onPreview: (_) => previews++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0:23'), findsOneWidget);
    final tile = find.byType(DiaryDayPhotoTile);
    await tester.tap(tile);
    await tester.pump();
    expect(previews, 1);
    expect(toggles, 0);

    await tester.tapAt(tester.getTopRight(tile) + const Offset(-12, 12));
    await tester.pump();
    expect(toggles, 1);
    expect(previews, 1);
  });

  testWidgets('the preview pages through photos and video', (tester) async {
    final controller = await readyController(tester);
    final l10n = await pumpPreview(tester, controller);

    expect(find.bySemanticsLabel('1 / 3'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('2 / 3'), findsOneWidget);
    // 视频页底栏写出拍摄时间与时长；假实现给不出播放地址，说明放不了。
    expect(inPreview(find.text('12:00 · 0:23')), findsOneWidget);
    expect(inPreview(find.text(l10n.videoPlaybackFailed)), findsOneWidget);
    expect(inPreview(find.byTooltip(l10n.videoPlay)), findsOneWidget);
  });

  testWidgets('checking in the preview enables insert and pops true', (
    tester,
  ) async {
    final controller = await readyController(tester);
    final l10n = await pumpPreview(tester, controller, initialIndex: 1);

    expect(find.bySemanticsLabel('2 / 3'), findsOneWidget);
    final insertButton = inPreview(find.byType(FilledButton));
    expect(tester.widget<FilledButton>(insertButton).onPressed, isNull);

    await tester.tap(inPreview(find.byTooltip(l10n.diaryDayPhotosSelect)));
    await tester.pumpAndSettle();
    expect(controller.isSelected(clip), isTrue);
    expect(
      inPreview(find.byTooltip(l10n.diaryDayPhotosDeselect)),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(insertButton).onPressed, isNotNull);
    await tester.tap(
      inPreview(find.text(l10n.diaryDayPhotosInsertCountItems(1))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DiaryDayPhotoPreviewPage), findsNothing);
    // 只负责勾选与返回：插入本身由打开者执行，这里仍保持勾选。
    expect(controller.selectedCount, 1);
  });

  testWidgets('an inserted item cannot be checked in the preview', (
    tester,
  ) async {
    final controller = await readyController(tester);
    controller.markInserted([breakfast]);
    final l10n = await pumpPreview(tester, controller);

    expect(
      inPreview(find.byTooltip(l10n.diaryDayPhotosInserted)),
      findsOneWidget,
    );
    await tester.tap(inPreview(find.byTooltip(l10n.diaryDayPhotosInserted)));
    await tester.pumpAndSettle();
    expect(controller.selectedCount, 0);
  });
}
