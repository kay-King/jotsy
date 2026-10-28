import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/controllers/diary_edit_entry_flow.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/providers/diary_filters.dart';
import '../../diaries/providers/diary_profile_provider.dart';
import '../../diaries/sections/diary_timeline_entry_menu_sheet.dart';
import '../../diaries/widgets/diary_preview/diary_preview_dialogs.dart';
import '../../diaries/widgets/diary_timeline/diary_timeline_avatar.dart';
import '../../diaries/widgets/diary_timeline/diary_timeline_item.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/controllers/profile_page_controller.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/expressive_image_frame.dart';
import 'diary_preview_page.dart';
import 'locked_diary_page.dart';

/// 朋友圈式时间线页：封面 + 头像 + 昵称 + 简介 + 一条条日记。
///
/// 桌面“时间线”入口打开的是这里，不是日记页。日记页的时间线视图
/// （列表/时间线切换）原样不动。
///
/// - 封面：没设时是 Salt 蓝纯色；点封面或左下角相机按钮可换封面
///   （相册选图后拷贝进私有目录，与头像同口径）；
/// - 头像与昵称来自个人资料；昵称白色落在封面右下角（朋友圈式），
///   点头像可换头像；昵称白字带文字阴影，在任何照片上都读得清，
///   封面本身一点不动（不用 BackdropFilter 朦胧：它会把照片封面
///   整片揉白，滚动时还每帧重算导致闪烁）；
/// - 简介只在设了时才显示，放在封面下方；
/// - 日记一条条往下排，复用 [DiaryTimelineItem]（昵称蓝色、九宫格、
///   长文折叠都与日记页时间线一致）；点一条进预览页，不做多选；
/// - 分页复用日记页的 [pagedDiariesProvider]，滑到底自动多加载 30 篇。
/// - 手感：整页用只顶部回弹的 [_TopBounceScrollPhysics]。v18 的双向
///   回弹（[BouncingScrollPhysics]）松手后会在底部越界再弹回，看着
///   像自动滚动；改回原生 [ClampingScrollPhysics] 又把顶部回弹也丢
///   了。所以只留顶部回弹：顶部下拉可越界（封面跟着拉伸放大、松手
///   弹回），底部夹住不越界，松手即停。
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

/// 只顶部回弹的滚动手感：顶部下拉允许越界（回弹 + 封面拉伸），底部
/// 夹住不越界。双向回弹的问题在底部：向上滑松手后冲到底部越界再弹
/// 回，看着像自动滚动；只留顶部回弹，底部松手即停。
class _TopBounceScrollPhysics extends BouncingScrollPhysics {
  const _TopBounceScrollPhysics({super.parent});

  @override
  _TopBounceScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _TopBounceScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // 顶部越界（value < minScrollExtent）：放行，交给回弹处理。
    if (value < position.minScrollExtent) {
      return 0.0;
    }
    // 底部越界（value > maxScrollExtent）：夹住，不越界、不回弹。
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  static const int _pageSize = 30;
  static const double _coverHeight = 280;

  int _visibleLimit = _pageSize;
  final ScrollController _scrollController = ScrollController();
  bool _changingCover = false;
  bool _changingAvatar = false;

  /// 是否已在“接近底部”区内：只在刚进入该区时触发一次分页，离开再
  /// 进入才再次触发。原来每帧都满足条件就 setState，一次拖动能把
  /// _visibleLimit 连加很多个 30，白白重建整页（拖动闪烁的另一半
  /// 原因）；只有 1 篇日记时更是每帧都在 setState。
  bool _nearBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.outOfRange) return;
    final nearBottom = position.pixels >= position.maxScrollExtent - 600;
    // 只在刚进入底部区的那一下分页；已在区内时不再重复触发。
    if (!nearBottom || _nearBottom) {
      _nearBottom = nearBottom;
      return;
    }
    _nearBottom = true;
    // 没更多了就不分页，避免只有 1 篇时反复 setState。
    final query = DiaryPageQuery(
      keyword: '',
      requiredTagIds: const <int>[],
      limit: _visibleLimit,
      sortMode: DiarySortMode.updatedDesc,
    );
    final hasMore =
        ref.read(pagedDiariesProvider(query)).asData?.value.hasMore ?? true;
    if (!hasMore) return;
    setState(() => _visibleLimit += _pageSize);
  }

  Future<void> _changeCover() async {
    if (_changingCover) return;
    setState(() => _changingCover = true);
    try {
      await ProfilePageController(ref).pickCover();
    } finally {
      if (mounted) {
        setState(() => _changingCover = false);
      }
    }
  }

  Future<void> _changeAvatar() async {
    if (_changingAvatar) return;
    setState(() => _changingAvatar = true);
    try {
      await ProfilePageController(ref).pickAvatar();
    } finally {
      if (mounted) {
        setState(() => _changingAvatar = false);
      }
    }
  }

  void _openPreview(DiaryWithTags diary) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => DiaryPreviewPage(
            diaryId: diary.diary.diaryId,
            initialDetail: diary,
          ),
        ),
      ),
    );
  }

  /// 条目右下角“...”菜单：编辑 / 查看详情 / 删除（仿朋友圈）。
  Future<void> _openEntryMenu(DiaryWithTags diary) async {
    final action = await showDiaryTimelineEntryMenuSheet(context);
    if (!mounted || action == null) return;
    switch (action) {
      case DiaryTimelineEntryMenuAction.edit:
        // 时间线是流式查询，改动自动刷新，不用管返回值。
        await openDiaryEditorForDetail(
          context,
          diaryId: diary.diary.diaryId,
          detail: diary,
        );
      case DiaryTimelineEntryMenuAction.viewDetail:
        _openEntryDetail(diary);
      case DiaryTimelineEntryMenuAction.delete:
        await _deleteEntry(diary);
    }
  }

  /// 查看详情：与点条目本身一致；未解封胶囊进封存页。
  void _openEntryDetail(DiaryWithTags diary) {
    final entry = diary.diary;
    final isLockedCapsule = TimeCapsuleState.fromFields(
      lockedAt: entry.capsuleLockedAt,
      unlockAt: entry.capsuleUnlockAt,
      now: DateTime.now(),
    ).isLocked;
    if (isLockedCapsule) {
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) =>
                LockedDiaryPage(diaryId: entry.diaryId, initialDetail: diary),
          ),
        ),
      );
      return;
    }
    _openPreview(diary);
  }

  /// 删除一篇日记：先弹确认框，软删进回收站，提示条里可撤销。
  /// 时间线是流式查询，删除 / 撤销后自动刷新，不用手动处理列表。
  Future<void> _deleteEntry(DiaryWithTags diary) async {
    final shouldDelete = await confirmDiaryPreviewDelete(context);
    if (!mounted || !shouldDelete) return;
    final db = ref.read(appDatabaseProvider);
    await db.softDeleteDiary(diary.diary.diaryId, touchUpdatedAt: false);
    if (!mounted) return;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(context.l10n.autoT0074('1')),
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () {},
        ),
        // 带动作的 SnackBar 默认常驻，须显式关掉自动消失。
        persist: false,
        duration: const Duration(seconds: 4),
      ),
    );
    if (reason == SnackBarClosedReason.action) {
      await db.restoreDiary(diary.diary.diaryId, touchUpdatedAt: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final profile = ref.watch(diaryProfileProvider);
    final query = DiaryPageQuery(
      keyword: '',
      requiredTagIds: const <int>[],
      limit: _visibleLimit,
      sortMode: DiarySortMode.updatedDesc,
    );
    final diariesAsync = ref.watch(pagedDiariesProvider(query));
    final diariesResult = diariesAsync.asData?.value;
    final diaries = diariesResult?.items;
    // 还有更多没加载时不显示“已经到底了”；只有全部加载完才显示。
    final hasMore = diariesResult?.hasMore ?? true;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        // 只顶部回弹：顶部下拉可越界（封面拉伸），底部夹住松手即停。
        physics: const _TopBounceScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: _coverHeight,
            pinned: false,
            // 封面可拉伸：顶部下拉越界时背景放大（zoomBackground），
            // 松手随回弹恢复——仿朋友圈下拉封面放大的效果。
            stretch: true,
            backgroundColor: colors.surface,
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              // 描边 Material 图标：顶栏图标用户明确要描边 Material 风，
              // 且 FontAwesome 在预览字体里常渲染成方框。
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const <StretchMode>[StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // 点封面换背景：手势只包封面图本身，不包头像与相机按钮，
                  // 点头像换头像、点相机换背景，互不抢。
                  GestureDetector(
                    onTap: _changeCover,
                    child: _CoverImage(profile: profile),
                  ),
                  // 封面右下角：昵称（白字）+ 头像，与朋友圈一致。
                  // 不用 BackdropFilter 朦胧：实测三宗罪——照片封面整
                  // 片发白看不清、滚动时每帧重算背景闪烁、模糊块还盖
                  // 住封面。白字改用文字阴影（黑 45%、模糊 6、下移 1），
                  // 在任何照片上都读得清，封面本身一点不动。
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Row(
                      // Positioned 只给右/下，不给宽，Row 拿到的宽度无界：
                      // 必须 shrink-wrap，否则里面的 Flexible 会报
                      // “无界宽度里不能 flex”。Flexible 默认是 loose，
                      // 昵称按本身宽度排，超长时才省略。
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            profile.displayNickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _changingAvatar ? null : _changeAvatar,
                          child: Tooltip(
                            message: l10n.profileChangeAvatar,
                            child: Container(
                              decoration: BoxDecoration(
                                // 头像本身是圆角方块（radius 8），描边必须跟
                                // 着方块走：之前用了圆形描边，圆圈盖不住方块
                                // 的四个角，看起来像头像下面多个白圈。
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: DiaryTimelineAvatar(
                                profile: profile,
                                size: 72,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 封面左下角：相机按钮，提示点封面可换。
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: IconButton(
                      tooltip: l10n.profileChangeCover,
                      onPressed: _changingCover ? null : _changeCover,
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (profile.displayBio.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  profile.displayBio,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          if (diaries == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: DelayedLoadingIndicator()),
              ),
            )
          else if (diaries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    l10n.timelineEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: diaries.length,
              itemBuilder: (context, index) {
                final diary = diaries[index];
                // 跨年时在第一条前显示年份头（“2026年”），与朋友圈一致；
                // 同一年只在第一条前显示一次。分页加载时按前后条目比较，
                // 不会重复出现。
                final year = diary.diary.createdAt.year;
                final showYearHeader =
                    index == 0 ||
                    diaries[index - 1].diary.createdAt.year != year;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showYearHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          DateFormat.y(
                            l10n.localeName,
                          ).format(diary.diary.createdAt),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    DiaryTimelineItem(
                      diary: diary,
                      profile: profile,
                      selected: false,
                      isSelectionMode: false,
                      maxVisibleTags: 5,
                      onOpenEditor: (entry, _) => _openPreview(entry),
                      onToggleSelection: (_, _) {},
                      onOpenMoreMenu: _openEntryMenu,
                      // 长按也开菜单（与朋友圈一致）；时间线页多选已关，
                      // 长按原来是空操作。
                      onLongPressMenu: _openEntryMenu,
                      opensLockedCapsulePage: true,
                    ),
                  ],
                );
              },
            ),
          // 全部加载完才显示“已经到底了”；还有更多时滑到底继续加载，
          // 不显示。底栏本身随回弹滚动一起上下回弹。
          if (diaries != null && diaries.isNotEmpty && !hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
                child: Center(
                  child: Text(
                    '—— ${l10n.timelineReachedEnd} ——',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 封面图：设了封面且文件存在时显示图片，否则显示 Salt 蓝纯色。
///
/// 注意：仓库源码规则限定渐变只能由取色谱/选择面绘制（diary_card_style
/// _source_test 兜底），这里不能用 LinearGradient，默认封面用纯色。
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.profile});

  final DiaryProfile profile;

  @override
  Widget build(BuildContext context) {
    final coverFile = profile.coverFile;
    if (coverFile != null) {
      return Image.file(
        coverFile,
        fit: BoxFit.cover,
        frameBuilder: expressiveImageFrameBuilder,
      );
    }
    return const ColoredBox(color: Color(0xFF0470E6));
  }
}
