import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/providers/diary_filters.dart';
import '../../diaries/providers/diary_profile_provider.dart';
import '../../diaries/widgets/diary_timeline/diary_timeline_avatar.dart';
import '../../diaries/widgets/diary_timeline/diary_timeline_item.dart';
import '../../settings/controllers/profile_page_controller.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/expressive_image_frame.dart';
import 'diary_preview_page.dart';

/// 朋友圈式时间线页：封面 + 头像 + 昵称 + 简介 + 一条条日记。
///
/// 桌面“时间线”入口打开的是这里，不是日记页。日记页的时间线视图
/// （列表/时间线切换）原样不动。
///
/// - 封面：没设时是 Salt 蓝纯色；点封面或右下角相机按钮可换封面
///   （相册选图后拷贝进私有目录，与头像同口径）；
/// - 头像与昵称来自个人资料；昵称白色落在封面右下角（朋友圈式）；
/// - 简介只在设了时才显示，放在封面下方；
/// - 日记一条条往下排，复用 [DiaryTimelineItem]（昵称蓝色、九宫格、
///   长文折叠都与日记页时间线一致）；点一条进预览页，不做多选；
/// - 分页复用日记页的 [pagedDiariesProvider]，滑到底自动多加载 30 篇。
/// - 手感：整页用 [BouncingScrollPhysics]，顶部下拉、底部上拉都有
///   回弹；封面是可拉伸的 SliverAppBar（`stretch: true` +
///   `StretchMode.zoomBackground`），顶部下拉时封面会跟着放大、
///   松手弹回——仿朋友圈（my-diary-fakeWechat 的 bindPullToTop）
///   那种“下拉封面放大”的灵动感。Android 默认是 ClampingScroll
///   Physics，滑到头就死死停住，看起来像静态页，所以这里显式指定。
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  static const int _pageSize = 30;
  static const double _coverHeight = 280;

  int _visibleLimit = _pageSize;
  final ScrollController _scrollController = ScrollController();
  bool _changingCover = false;

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
    // 回弹越界时（顶部下拉/底部上拉）不要触发分页：回弹动画会连续产生
    // 多次滚动通知，否则 _visibleLimit 会一次被加很多个 30。
    if (position.outOfRange) return;
    if (position.pixels >= position.maxScrollExtent - 600) {
      setState(() => _visibleLimit += _pageSize);
    }
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
    final diaries = diariesAsync.asData?.value.items;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        // 回弹滚动：顶部下拉、底部上拉都带弹性回弹，松手弹回原位。
        physics: const BouncingScrollPhysics(),
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
              background: GestureDetector(
                onTap: _changeCover,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _CoverImage(profile: profile),
                    // 封面右下角：昵称（白字）+ 头像，与朋友圈一致。
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            profile.displayNickname,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              // 头像本身是圆角方块（radius 8），描边必须跟
                              // 着方块走：之前用了圆形描边，圆圈盖不住方块
                              // 的四个角，看起来像头像下面多个白圈。
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: DiaryTimelineAvatar(
                              profile: profile,
                              size: 72,
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
          ),
          if (profile.displayBio.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  profile.displayBio,
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
                return DiaryTimelineItem(
                  diary: diary,
                  profile: profile,
                  selected: false,
                  isSelectionMode: false,
                  maxVisibleTags: 5,
                  onOpenEditor: (entry, _) => _openPreview(entry),
                  onToggleSelection: (_, _) {},
                  opensLockedCapsulePage: true,
                );
              },
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
