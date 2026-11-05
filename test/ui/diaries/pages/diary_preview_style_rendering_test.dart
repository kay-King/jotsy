import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_comment_providers.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_appflowy_preview.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_overlays.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_cover_sliver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

var _idSeed = 0;

DiaryWithTags _diary({
  String title = '海边的一天',
  String? cover,
  String content = '[{"insert":"晚霞把整片海都染成了橘色\\n"}]',
  String text = '晚霞把整片海都染成了橘色',
  bool edited = true,
}) {
  final created = DateTime(2025, 3, 2, 9, 30);
  return DiaryWithTags(
    diary: Diary(
      id: _idSeed,
      diaryId: 'preview-style-${_idSeed++}',
      title: title,
      content: content,
      contentText: text,
      metadata:
          '{"context":{"moodEmoji":"😊","energyLevel":4,"location":"西湖","weather":"晴","weatherIconCode":"100"}}',
      cover: cover,
      createdAt: created,
      updatedAt: edited ? created.add(const Duration(days: 1)) : created,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[Tag(id: 1, name: '旅行', color: 0xFF4CAF50)],
  );
}

class _PendingDetailDatabase extends AppDatabase {
  _PendingDetailDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<DiaryWithTags?> getDiaryWithTagsByDiaryId(String diaryId) =>
      Completer<DiaryWithTags?>().future;
}

/// 装配预览页；返回设置服务，用例可以在页面打开期间改写样式（与设置页
/// 写入同一条路径）。
Future<SettingsService> _pump(
  WidgetTester tester, {
  DiaryPreviewStyle style = DiaryPreviewStyle.defaults,
  DiaryPreviewBehavior behavior = DiaryPreviewBehavior.defaults,
  DiaryWithTags? detail,
  Brightness brightness = Brightness.light,
}) async {
  // 同一个用例里多次装配时先卸掉旧树：ProviderScope 与页面状态都要重建，
  // 否则沿用上一次的设置服务。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
  final encoded = DiaryPreviewSettings(
    current: style,
    behavior: behavior,
  ).encode();
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.settings.diary_preview_style': ?encoded,
  });
  final settings = await SettingsService.create();
  final database = _PendingDetailDatabase();
  addTearDown(database.close);
  final entry = detail ?? _diary();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        // 预览页留言区：不打开真实数据库。
        diaryCommentsProvider.overrideWith(
          (ref, diaryId) => Stream.value(const <DiaryCommentRow>[]),
        ),
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        locale: const Locale('zh'),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          quill.FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiaryPreviewPage(
          diaryId: entry.diary.diaryId,
          initialDetail: entry,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

double _top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

/// 正文、列表项与待办各一行：检查正文颜色时覆盖不同的文字块。
const _mixedBody =
    '[{"insert":"晚霞把整片海都染成了橘色\\n"},'
    '{"insert":"带上相机"},{"insert":"\\n","attributes":{"list":"bullet"}},'
    '{"insert":"看日落"},{"insert":"\\n","attributes":{"list":"unchecked"}}]';

const _mixedBodyLines = <String>['晚霞把整片海都染成了橘色', '带上相机', '看日落'];

/// 正文里包含 [text] 的那一行实际绘制的文字颜色：取写着这段文字的片段的
/// 颜色，片段没设时取整行的。读的是画出来的 RichText，而不是样式对象，
/// 渲染层缓存了过期样式时也能发现。
Color _renderedBodyColor(WidgetTester tester, String text) {
  final line = tester
      .widgetList<RichText>(
        find.descendant(
          of: find.byType(DiaryAppFlowyPreview),
          matching: find.byType(RichText),
        ),
      )
      .firstWhere((rich) => rich.text.toPlainText().contains(text));
  Color? color;
  line.text.visitChildren((span) {
    if (span is TextSpan && (span.text?.contains(text) ?? false)) {
      color = span.style?.color;
      return false;
    }
    return true;
  });
  return color ?? line.text.style!.color!;
}

/// 页面纸色（预览页 Scaffold 的底色）。
Color _paper(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor!;

/// 正文各行都按页面主题的正文色绘制，且与纸色的对比度不低于 4.5:1。
void _expectReadableBody(WidgetTester tester, Iterable<String> lines) {
  final paper = _paper(tester);
  final ink = Theme.of(
    tester.element(find.byType(DiaryAppFlowyPreview)),
  ).colorScheme.onSurface;
  for (final text in lines) {
    final color = _renderedBodyColor(tester, text);
    expect(color, ink, reason: text);
    expect(
      DiaryCardColors.contrastOver(color, paper),
      greaterThanOrEqualTo(4.5),
      reason: text,
    );
  }
}

void main() {
  testWidgets('the default look keeps the original top bar and details', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('日记'), findsOneWidget);
    expect(find.textContaining('发表于'), findsOneWidget);
    expect(find.text('西湖'), findsOneWidget);
    expect(find.text('心情 😊'), findsOneWidget);
    expect(find.textContaining('最后编辑于'), findsOneWidget);
    expect(find.byType(DiaryPreviewProgressLine), findsNothing);
    expect(find.byType(DiaryPreviewBackToTop), findsNothing);
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.floating, isTrue);
    expect(bar.pinned, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('details move above the title or after the text', (tester) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        meta: DiaryPreviewMetaStyle(
          position: DiaryPreviewMetaPosition.aboveTitle,
        ),
      ),
    );
    expect(
      _top(tester, find.text('西湖')),
      lessThan(_top(tester, find.text('海边的一天'))),
    );

    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        meta: DiaryPreviewMetaStyle(position: DiaryPreviewMetaPosition.end),
      ),
    );
    expect(
      _top(tester, find.text('西湖')),
      greaterThan(_top(tester, find.byType(DiaryAppFlowyPreview))),
    );
    expect(
      _top(tester, find.text('西湖')),
      lessThan(_top(tester, find.textContaining('最后编辑于'))),
    );
  });

  testWidgets('detail switches, date format and chip styles apply', (
    tester,
  ) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        meta: DiaryPreviewMetaStyle(
          showLocation: false,
          showMood: false,
          dateFormat: DiaryCardDateFormat.full,
          dateSource: DiaryCardDateSource.updated,
          tagStyle: DiaryCardTagStyle.plain,
          showReadingTime: false,
        ),
      ),
    );
    expect(find.text('西湖'), findsNothing);
    expect(find.textContaining('心情'), findsNothing);
    expect(find.text('更新于 2025年3月3日'), findsOneWidget);
    expect(find.text('#旅行'), findsOneWidget);
    expect(find.text('12 字'), findsOneWidget);
  });

  testWidgets('cover modes: inset, hidden and no fallback to body photos', (
    tester,
  ) async {
    const photo = '/missing/photo.png';
    final withCover = _diary(cover: photo);
    await _pump(
      tester,
      detail: withCover,
      style: const DiaryPreviewStyle(
        cover: DiaryPreviewCoverStyle(
          mode: DiaryPreviewCoverMode.inset,
          radius: 20,
          height: 300,
          fit: DiaryPreviewCoverFit.cover,
        ),
      ),
    );
    final sliver = tester.widget<PublishDiaryCoverSliver>(
      find.byType(PublishDiaryCoverSliver),
    );
    expect(sliver.borderRadius, BorderRadius.circular(20));
    expect(sliver.maxExtentHeight, 300);
    expect(sliver.fillFrame, isTrue);

    await _pump(
      tester,
      detail: withCover,
      style: const DiaryPreviewStyle(
        cover: DiaryPreviewCoverStyle(mode: DiaryPreviewCoverMode.hidden),
      ),
    );
    expect(find.byType(PublishDiaryCoverSliver), findsNothing);

    final bodyPhoto = _diary(
      content: '[{"insert":{"image":"$photo"}},{"insert":"\\n图下的文字\\n"}]',
      text: '图下的文字',
    );
    await _pump(tester, detail: bodyPhoto);
    expect(find.byType(PublishDiaryCoverSliver), findsOneWidget);
    await _pump(
      tester,
      detail: bodyPhoto,
      style: const DiaryPreviewStyle(
        cover: DiaryPreviewCoverStyle(useFirstImage: false),
      ),
    );
    expect(find.byType(PublishDiaryCoverSliver), findsNothing);
  });

  testWidgets('the title can hide, drop the untitled placeholder and scale', (
    tester,
  ) async {
    await _pump(
      tester,
      detail: _diary(title: ''),
      style: const DiaryPreviewStyle(
        title: DiaryPreviewTitleStyle(showUntitled: false),
      ),
    );
    expect(find.text('无标题'), findsNothing);

    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        title: DiaryPreviewTitleStyle(
          scale: 1.5,
          weight: DiaryPreviewTitleWeight.regular,
          align: DiaryPreviewAlign.center,
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('海边的一天'));
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.fontWeight, FontWeight.w400);
    final base = Theme.of(
      tester.element(find.text('海边的一天')),
    ).textTheme.headlineSmall!.fontSize!;
    expect(title.style?.fontSize, closeTo(base * 1.5, 0.01));

    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        title: DiaryPreviewTitleStyle(visible: false),
      ),
    );
    expect(find.text('海边的一天'), findsNothing);
  });

  testWidgets('ink paper turns a light app page dark and stays readable', (
    tester,
  ) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(paper: DiaryPreviewPaper.ink),
      ),
      detail: _diary(content: _mixedBody),
    );
    expect(_paper(tester), const Color(0xFF1E2126));
    final pageTheme = Theme.of(tester.element(find.text('海边的一天')));
    expect(pageTheme.brightness, Brightness.dark);
    // 正文（含列表项与待办）也换成深色页的浅色字，不是应用浅色主题的墨色。
    _expectReadableBody(tester, _mixedBodyLines);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching the paper while the page is open repaints the body', (
    tester,
  ) async {
    // 与设置页写入同一路径：页面开着时换纸色（预览页“更多 → 页面样式”改完
    // 返回、宽窗口右栏、设置页实时预览都是这样），正文跟着新主题重画。
    final settings = await _pump(tester, detail: _diary(content: _mixedBody));
    final appInk = expressiveTestTheme(Brightness.light).colorScheme.onSurface;
    expect(_renderedBodyColor(tester, '带上相机'), appInk);

    await settings.setDiaryPreviewStyleRaw(
      const DiaryPreviewSettings(
        current: DiaryPreviewStyle(
          page: DiaryPreviewPageStyle(paper: DiaryPreviewPaper.ink),
        ),
      ).encode(),
    );
    await tester.pumpAndSettle();
    expect(_paper(tester), const Color(0xFF1E2126));
    _expectReadableBody(tester, _mixedBodyLines);

    // 换回默认样式：正文回到应用主题的正文色，与从没换过一样。
    await settings.setDiaryPreviewStyleRaw(null);
    await tester.pumpAndSettle();
    for (final text in _mixedBodyLines) {
      expect(_renderedBodyColor(tester, text), appInk, reason: text);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('top bar mode, title, buttons and reading aids apply', (
    tester,
  ) async {
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(
          topBar: DiaryPreviewTopBarMode.pinned,
          topBarTitle: DiaryPreviewTopBarTitle.none,
          showEditButton: false,
          showShareButton: true,
          progress: DiaryPreviewProgress.line,
          backToTop: true,
        ),
      ),
    );
    final bar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(bar.pinned, isTrue);
    expect(find.text('日记'), findsNothing);
    expect(find.byTooltip('编辑'), findsNothing);
    expect(find.byTooltip('分享'), findsOneWidget);
    expect(find.byType(DiaryPreviewProgressLine), findsOneWidget);
    expect(find.byType(DiaryPreviewBackToTop), findsOneWidget);
  });

  testWidgets('reading behavior locks to-dos and text selection', (
    tester,
  ) async {
    await _pump(
      tester,
      behavior: const DiaryPreviewBehavior(
        todoToggle: false,
        textSelection: false,
      ),
    );
    final preview = tester.widget<DiaryAppFlowyPreview>(
      find.byType(DiaryAppFlowyPreview),
    );
    // todoToggle: false → onToggleTodo 为 null，复选框只读。
    expect(preview.onToggleTodo, isNull);
    expect(preview.textSelection, isFalse);
  });

  testWidgets('the long image behavior reaches the body image builder', (
    tester,
  ) async {
    bool foldsLongImages() =>
        tester
            .widget<DiaryAppFlowyPreview>(find.byType(DiaryAppFlowyPreview))
            .longImageMode ==
        DiaryPreviewLongImageMode.fold;

    await _pump(tester);
    expect(foldsLongImages(), isTrue);

    await _pump(
      tester,
      behavior: const DiaryPreviewBehavior(
        longImageMode: DiaryPreviewLongImageMode.full,
      ),
    );
    expect(foldsLongImages(), isFalse);
  });

  testWidgets('a limited text width centers the text on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      style: const DiaryPreviewStyle(
        page: DiaryPreviewPageStyle(limitWidth: true, contentWidth: 600),
      ),
    );
    final editor = tester.getRect(find.byType(DiaryAppFlowyPreview));
    expect(editor.width, closeTo(600 - 32, 0.5));
    expect(editor.center.dx, closeTo(500, 0.5));
  });

  testWidgets('changing to a re-themed look keeps the reading position', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsService.create();
    final database = _PendingDetailDatabase();
    addTearDown(database.close);
    final long = List<String>.filled(60, '一段很长的正文。').join('\\n');
    final detail = _diary(content: '[{"insert":"$long\\n"}]', text: long);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          // 预览页留言区：不打开真实数据库。
          diaryCommentsProvider.overrideWith(
            (ref, diaryId) => Stream.value(const <DiaryCommentRow>[]),
          ),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiaryPreviewPage(
            diaryId: detail.diary.diaryId,
            initialDetail: detail,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    final before = tester
        .state<ScrollableState>(scrollable.first)
        .position
        .pixels;
    expect(before, greaterThan(0));

    // 设置页那边换成墨色纸 + 进度线：整页换主题，但滚动位置与页面状态保留。
    await settings.setDiaryPreviewStyleRaw(
      const DiaryPreviewSettings(
        current: DiaryPreviewStyle(
          page: DiaryPreviewPageStyle(
            paper: DiaryPreviewPaper.ink,
            progress: DiaryPreviewProgress.line,
          ),
        ),
      ).encode(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.state<ScrollableState>(scrollable.first).position.pixels,
      before,
    );
    expect(
      Theme.of(tester.element(find.byType(DiaryAppFlowyPreview))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('the first frame already uses the stored look', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_preview_style': const DiaryPreviewSettings(
        current: DiaryPreviewStyle(
          page: DiaryPreviewPageStyle(
            topBarTitle: DiaryPreviewTopBarTitle.none,
          ),
        ),
      ).encode()!,
    });
    final settings = await SettingsService.create();
    final database = _PendingDetailDatabase();
    addTearDown(database.close);
    final detail = _diary();
    late BuildContext navigatorContext;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          // 预览页留言区：不打开真实数据库。
          diaryCommentsProvider.overrideWith(
            (ref, diaryId) => Stream.value(const <DiaryCommentRow>[]),
          ),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ...AppLocalizations.localizationsDelegates,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // 与应用一致：设置服务在启动时就已就绪，之后才打开预览页。
          home: Consumer(
            builder: (context, ref, _) {
              navigatorContext = context;
              ref.watch(settingsServiceProvider);
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Navigator.of(navigatorContext).push(
        MaterialPageRoute<void>(
          builder: (_) => DiaryPreviewPage(
            diaryId: detail.diary.diaryId,
            initialDetail: detail,
          ),
        ),
      ),
    );
    // 新路由的第一帧先在幕后构建（为共享元素测量），查找时包含幕后部件。
    await tester.pump();
    expect(find.byType(DiaryPreviewPage, skipOffstage: false), findsOneWidget);
    expect(find.byType(SliverAppBar, skipOffstage: false), findsOneWidget);
    expect(find.text('日记', skipOffstage: false), findsNothing);
    await tester.pumpAndSettle();
  });
}
