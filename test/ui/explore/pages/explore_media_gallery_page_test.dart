import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:node_diary/ui/explore/pages/explore_media_gallery_page.dart';
import 'package:node_diary/ui/explore/pages/gallery_video_page.dart';
import 'package:node_diary/ui/explore/sections/gallery_media_tile.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../../support/expressive_test_theme.dart';
import '../explore_test_fixtures.dart';

void main() {
  _registerFirstFrameTest();
  _registerFilterTests();
  for (final brightness in Brightness.values) {
    testWidgets(
      'shows all diary images and opens the tapped image in $brightness',
      (tester) async {
        final database = _GalleryDatabase();
        addTearDown(database.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              theme: expressiveTestTheme(brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ExploreMediaGalleryPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final thumbs = find.byType(ExploreMediaThumb);
        expect(
          tester
              .widgetList<ExploreMediaThumb>(thumbs)
              .map((item) => item.source),
          ['/cover.jpg', '/first.jpg', '/second.jpg'],
        );
        expect(tester.takeException(), isNull);

        await tester.tap(
          find
              .descendant(
                of: find.byType(SliverGrid),
                matching: find.byType(InkWell),
              )
              .at(2),
        );
        await tester.pumpAndSettle();

        final viewer = tester.widget<ImageViewerPage>(
          find.byType(ImageViewerPage),
        );
        expect(viewer.items.map((item) => item.source), [
          '/cover.jpg',
          '/first.jpg',
          '/second.jpg',
        ]);
        expect(viewer.initialIndex, 2);
        // 每张图带上所在日记，看图页长按面板可以直接打开它。
        expect(viewer.items.map((item) => item.diaryId).toSet(), {'diary-1'});
        expect(viewer.onOpenDiary, isNotNull);
        // 页码数字单独滚动切换，可见文本拆成两段；读屏仍读整句页码。
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('3 / 3'), findsOneWidget);
        semantics.dispose();
        expect(tester.takeException(), isNull);

        await tester.tap(
          find
              .descendant(
                of: find.byType(ImageViewerPage),
                matching: find.byType(IconButton),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExploreMediaThumb), findsNWidgets(3));
      },
    );
  }
}

void _registerFilterTests() {
  testWidgets('filter bar switches the grid by kind and opens players', (
    tester,
  ) async {
    final database = _MixedGalleryDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExploreMediaGalleryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(ExploreMediaGalleryPage)).l10n;

    // 默认全部：2 张图片缩略图 + 音频、视频各一格。
    expect(find.byType(ExploreMediaThumb), findsNWidgets(2));
    expect(find.byType(GalleryMediaTile), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    // 切音频：只剩音频格，底栏文案也跟着分类走。
    await tester.tap(find.text(l10n.galleryFilterAudio));
    await tester.pumpAndSettle();
    expect(find.byType(ExploreMediaThumb), findsNothing);
    expect(find.byType(GalleryMediaTile), findsOneWidget);
    expect(find.text(l10n.galleryNoMoreAudio), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 点音频格：底部面板里是日记正文同款播放器 + 打开日记按钮。
    await tester.tap(find.byType(GalleryMediaTile));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryAudioPlayer), findsOneWidget);
    expect(find.text(l10n.imageViewerOpenDiary), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 点面板外的遮罩收起面板（pageBack 在这里会去点顶栏返回键，被面板路由
    // 挡住只剩警告，改点遮罩才是面板本身的关闭路径）。
    await tester.tapAt(const Offset(400, 100));
    await tester.pumpAndSettle();
    expect(find.byType(DiaryAudioPlayer), findsNothing);

    // 切视频：只剩视频格，点开是单独的视频播放页。
    await tester.tap(find.text(l10n.galleryFilterVideo));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryMediaTile), findsOneWidget);
    await tester.tap(find.byType(GalleryMediaTile));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryVideoPage), findsOneWidget);
    expect(find.byType(DiaryVideoPlayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image viewer under All filter only flips through images', (
    tester,
  ) async {
    final database = _MixedGalleryDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExploreMediaGalleryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 全部筛选下点第一张图：看图页只含两张图片，不含音频 / 视频路径。
    await tester.tap(
      find
          .descendant(
            of: find.byType(SliverGrid),
            matching: find.byType(InkWell),
          )
          .at(0),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<ImageViewerPage>(find.byType(ImageViewerPage));
    expect(viewer.items.map((item) => item.source), [
      '/cover.jpg',
      '/first.jpg',
    ]);
    expect(viewer.initialIndex, 0);
    expect(tester.takeException(), isNull);
  });
}

void _registerFirstFrameTest() {
  testWidgets('opening the gallery never flashes the empty state', (
    tester,
  ) async {
    final database = _GalleryDatabase();
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExploreMediaGalleryPage(),
        ),
      ),
    );
    final l10n = tester.element(find.byType(ExploreMediaGalleryPage)).l10n;
    // 首次加载在首帧之后才发起：这期间不能先露出“暂无媒体”。
    for (var frame = 0; frame < 6; frame++) {
      expect(find.text(l10n.autoT0055), findsNothing, reason: '$frame');
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(find.byType(ExploreMediaThumb), findsNWidgets(3));
    expect(find.text(l10n.autoT0055), findsNothing);
  });
}

class _GalleryDatabase extends AppDatabase {
  _GalleryDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<List<Diary>> getActiveDiariesPage({
    required int limit,
    required int offset,
  }) async => [
    createExploreTestDiary(
      cover: '/cover.jpg',
      content:
          '[{"insert":{"image":"/first.jpg"}},'
          '{"insert":{"image":"/cover.jpg"}},'
          '{"insert":{"image":"/second.jpg"}}]',
    ),
  ];
}

/// 混合媒体库：封面图 + 正文图片 / 视频 / 音频各一条（同一篇日记）。
class _MixedGalleryDatabase extends AppDatabase {
  _MixedGalleryDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<List<Diary>> getActiveDiariesPage({
    required int limit,
    required int offset,
  }) async => [
    createExploreTestDiary(
      cover: '/cover.jpg',
      content: jsonEncode([
        {
          'insert': {'image': '/first.jpg'},
        },
        {
          'insert': {'video': '/clip.mp4'},
        },
        {
          'insert': {
            'audio': jsonEncode({
              'path': '/rec.m4a',
              'durationMs': 65000,
              'name': '晨间录音',
            }),
          },
        },
      ]),
    ),
  ];
}
