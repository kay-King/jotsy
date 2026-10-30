import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/delayed_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';
import 'package:node_diary/ui/widgets/image_viewer_page.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/audio_embed_codec.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../controllers/explore_media_gallery_controller.dart';
import '../models/explore_view_data.dart';
import '../sections/gallery_filter_bar.dart';
import '../sections/gallery_layout_sheet.dart';
import '../sections/gallery_media_tile.dart';
import '../widgets/explore_shared_widgets.dart';
import 'gallery_video_page.dart';

/// 探索页“媒体画廊”全量浏览页。
///
/// 职责边界：
/// - 监听页面控制器的分页结果，滚动触底时请求续载；
/// - 负责网格渲染与图片查看页跳转；看图页长按“打开日记”打开图片所在
///   的日记（叠在看图页之上，返回时回到刚才那张图）；
/// - 不负责日记聚合统计（保持与 ExplorePageController 解耦）。
///
/// 分组只按视图粒度（年/月/日）分段，不筛掉任何照片（ente 的 GroupType
/// 做法）；布局（视图与每行数量）持久化，正倒序只在本次打开内生效。
class ExploreMediaGalleryPage extends ConsumerStatefulWidget {
  const ExploreMediaGalleryPage({super.key});

  @override
  ConsumerState<ExploreMediaGalleryPage> createState() =>
      _ExploreMediaGalleryPageState();
}

class _ExploreMediaGalleryPageState
    extends ConsumerState<ExploreMediaGalleryPage> {
  static const double _prefetchExtent = 720;

  final ScrollController _scrollController = ScrollController();
  late final ExploreMediaGalleryController _controller;

  /// 布局：分组粒度与每行数量持久化（设置服务里按边界收敛），
  /// 正倒序与分类筛选只在本次打开内生效。
  GalleryGroupType _groupType = GalleryGroupType.month;
  int _columns = 3;
  bool _sortAsc = false;
  GalleryMediaFilter _mediaFilter = GalleryMediaFilter.all;
  bool _layoutLoaded = false;

  List<ExploreMediaItem> get _mediaItems => _controller.items;
  bool get _isLoading => _controller.isLoading;
  bool get _hasMore => _controller.hasMore;
  String? get _errorMessage =>
      _controller.hasError ? context.l10n.galleryLoadFailed : null;

  /// 分类过滤 + 排序后的展示列表（按创建时间排；看图页也在这个列表的图片
  /// 子集里翻）。分类只在内存里筛，不重新取数；切到具体分类时先把剩下的
  /// 全加载完（见 _selectMediaFilter），否则还没加载到的月份会漏掉。
  List<ExploreMediaItem> get _displayItems {
    final kind = _mediaFilter.kind;
    final filtered = kind == null
        ? _mediaItems
        : _mediaItems.where((item) => item.kind == kind);
    final sorted = List<ExploreMediaItem>.of(filtered);
    sorted.sort(
      (a, b) => _sortAsc
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt),
    );
    return sorted;
  }

  void _selectMediaFilter(GalleryMediaFilter filter) {
    if (filter == _mediaFilter) {
      return;
    }
    setState(() => _mediaFilter = filter);
    // 过滤要对完整集合才有意义：切到具体分类时把剩下的全加载完，
    // 否则还没加载到的月份会漏掉（与正序同理，见 controller.loadAll）。
    if (filter != GalleryMediaFilter.all) {
      unawaited(_controller.loadAll());
    }
  }

  /// 当前分类下的空态文案：图片沿用旧文案，其余按分类区分。
  String _emptyText(AppLocalizations l10n) => switch (_mediaFilter) {
    GalleryMediaFilter.all => l10n.galleryEmptyMedia,
    GalleryMediaFilter.image => l10n.autoT0055,
    GalleryMediaFilter.audio => l10n.galleryEmptyAudio,
    GalleryMediaFilter.video => l10n.galleryEmptyVideo,
  };

  /// 当前分类下的“已到底”文案：图片沿用旧文案，其余按分类区分。
  String _noMoreText(AppLocalizations l10n) => switch (_mediaFilter) {
    GalleryMediaFilter.all => l10n.galleryNoMoreMedia,
    GalleryMediaFilter.image => l10n.autoT0057,
    GalleryMediaFilter.audio => l10n.galleryNoMoreAudio,
    GalleryMediaFilter.video => l10n.galleryNoMoreVideo,
  };

  void _selectGroupType(GalleryGroupType type) {
    if (type == _groupType) {
      return;
    }
    setState(() => _groupType = type);
    unawaited(_persistGroupType(type));
  }

  void _selectColumns(int columns) {
    if (columns == _columns) {
      return;
    }
    setState(() => _columns = columns);
    unawaited(_persistColumns(columns));
  }

  void _selectSort(bool ascending) {
    setState(() => _sortAsc = ascending);
    // 正序只对完整集合有意义：还没加载完就把剩下的全加载完，否则
    // 还没加载到的照片排不准。
    if (ascending && _hasMore) {
      unawaited(_controller.loadAll());
    }
  }

  Future<void> _persistGroupType(GalleryGroupType type) async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setGalleryGroupTypeRaw(type.name);
  }

  Future<void> _persistColumns(int columns) async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setGalleryColumns(columns);
  }

  /// 设置服务就绪后把持久化的布局读进来（首帧先按默认月视图 3 列画，
  /// 读到后再换一次——设置只在启动时加载一次，不会反复横跳）。
  void _applyLayoutSettings(SettingsService settings) {
    if (_layoutLoaded) {
      return;
    }
    _layoutLoaded = true;
    final groupType = galleryGroupTypeFromRaw(settings.galleryGroupTypeRaw);
    final columns = settings.galleryColumns;
    if (groupType == _groupType && columns == _columns) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _groupType = groupType;
        _columns = columns;
      });
    });
  }

  void _openLayoutSheet() {
    unawaited(
      showGalleryLayoutSheet(
        context,
        groupType: _groupType,
        columns: _columns,
        sortAsc: _sortAsc,
        onSelectGroupType: _selectGroupType,
        onSelectColumns: _selectColumns,
        onSelectSort: _selectSort,
      ),
    );
  }

  /// 分段标题：年视图“2026年”、月视图“2026年10月”、日视图“2026年10月25日”。
  /// 张数不显示：网格里一眼能数出来（2026-10-25 用户反馈）。
  String _groupTitle(AppLocalizations l10n, DateTime key) {
    return switch (_groupType) {
      GalleryGroupType.year => DateFormat.y(l10n.localeName).format(key),
      GalleryGroupType.month => DateFormat.yMMM(l10n.localeName).format(key),
      GalleryGroupType.day => DateFormat.yMMMMd(l10n.localeName).format(key),
    };
  }

  @override
  void initState() {
    super.initState();
    _controller = ExploreMediaGalleryController(
      database: ref.read(appDatabaseProvider),
    )..addListener(_handleGalleryChanged);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleGalleryChanged)
      ..dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 设置服务只在启动时加载一次；就绪后把持久化的布局读进来（只读一次，
    // _applyLayoutSettings 自己用 _layoutLoaded 门控）。
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings != null) {
      _applyLayoutSettings(settings);
    }
    return Scaffold(
      appBar: AppTopBar(
        centerTitle: true,
        title: Text(l10n.autoT0054),
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      // 分类条固定在顶部（不跟网格一起滚）；下方首次加载 → 网格 / 空态 /
      // 错误之间交叉淡入，而不是硬切；网格内追加分页时 key 不变，不会重复淡入。
      body: Column(
        children: <Widget>[
          GalleryFilterBar(
            selected: _mediaFilter,
            onSelected: _selectMediaFilter,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    // 展示列表（已按分类过滤）：空时先区分“还在加载”与“真的没有”。
    // 首次加载在首帧之后才发起，此前 isLoading 仍为 false：把“还没加载过”也
    // 当作加载中，避免先闪一帧空态；切到具体分类后 loadAll 在途时同样不闪
    // 空态。本地查询通常很快，指示器延迟出现。
    final displayItems = _displayItems;
    final neverLoaded = _hasMore && _errorMessage == null;
    if (displayItems.isEmpty && (_isLoading || neverLoaded)) {
      return const DelayedLoadingIndicator(key: ValueKey<String>('loading'));
    }
    if (displayItems.isEmpty && _errorMessage != null) {
      return Center(
        key: const ValueKey<String>('error'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _loadMore,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (displayItems.isEmpty) {
      return Center(
        key: const ValueKey<String>('empty'),
        child: Text(
          _emptyText(l10n),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    // 到这里展示列表非空：按分组粒度分段画网格，底栏跟加载状态走。
    final groups = groupGalleryItems(displayItems, _groupType);
    final slivers = <Widget>[];
    var offset = 0;
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final baseIndex = offset;
      offset += group.items.length;
      slivers.add(
        SliverToBoxAdapter(
          child: _GroupHeader(
            title: _groupTitle(l10n, group.key),
            // ⋮ 只放在第一段标题行右边：它是整页的布局菜单，不是某一段
            // 的操作；每段都放会把时间线挤满（2026-10-25 用户反馈）。
            showMenu: i == 0,
            onOpenMenu: _openLayoutSheet,
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final displayIndex = baseIndex + index;
              return _buildCell(
                context,
                displayItems[displayIndex],
                displayIndex,
              );
            }, childCount: group.items.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
          ),
        ),
      );
    }
    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            12,
            AppSpacing.m,
            AppSpacing.xl,
          ),
          child: _GalleryFooter(
            isLoading: _isLoading,
            hasMore: _hasMore,
            errorMessage: _errorMessage,
            endText: _noMoreText(l10n),
            onRetry: _loadMore,
          ),
        ),
      ),
    );
    return CustomScrollView(
      key: const ValueKey<String>('grid'),
      controller: _scrollController,
      slivers: slivers,
    );
  }

  /// 单个格：图片是缩略图 + 看图页，音频 / 视频是图标格 + 各自的播放入口。
  /// 图片缩略图本身不透明，水波纹需画在叠于其上的透明 Material 上。
  /// Builder 提供格子自己的 context：点按时从这里抓取已绘制的缩略图
  /// 作为看图页的飞入画面（delegate 的 context 是整个网格）。
  Widget _buildCell(
    BuildContext context,
    ExploreMediaItem item,
    int displayIndex,
  ) {
    if (item.kind != GalleryMediaKind.image) {
      return GalleryMediaTile(
        item: item,
        radius: _thumbRadius,
        onTap: () => item.kind == GalleryMediaKind.audio
            ? _openAudioSheet(item)
            : _openVideoPage(item),
      );
    }
    return Builder(
      builder: (cellContext) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ImageViewerHeroSource(
            tag: _heroTag(item.source),
            borderRadius: BorderRadius.circular(_thumbRadius),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.biggest.shortestSide;
                return ExploreMediaThumb(
                  source: item.source,
                  width: side,
                  height: side,
                  radius: _thumbRadius,
                );
              },
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(_thumbRadius),
              onTap: () => _openViewer(displayIndex, cellContext),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter < _prefetchExtent) {
      _loadMore();
    }
  }

  void _handleGalleryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadMore() => _controller.loadMore();

  static const double _thumbRadius = 12;

  static Object _heroTag(String source) =>
      ImageViewerHeroTag('explore_gallery', source);

  /// 打开看图页：缩略图以共享元素展开成原图，返回时飞回原格子。每张图带上
  /// 所在日记，长按面板可直接打开它；看图页只在图片子集里翻——全部筛选下
  /// 展示列表里可能混着音频 / 视频，先只取图片，初始下标换算到图片子集里。
  void _openViewer(int initialIndex, BuildContext cellContext) {
    final displayItems = _displayItems;
    final item = displayItems[initialIndex];
    final images = displayItems
        .where((entry) => entry.kind == GalleryMediaKind.image)
        .toList(growable: false);
    openImageViewer(
      context,
      items: images
          .map(
            (entry) =>
                ImageViewerItem(source: entry.source, diaryId: entry.diaryId),
          )
          .toList(growable: false),
      initialIndex: images.indexOf(item),
      hero: ImageViewerHero.capture(cellContext, tag: _heroTag(item.source)),
      onOpenDiary: (String diaryId) => unawaited(_openDiary(diaryId)),
    );
  }

  /// 音频格点开：底部面板里放日记正文同款 DiaryAudioPlayer（不新写播放器），
  /// 面板里“打开日记”带 diaryId 回来，画廊页再打开那篇日记。
  Future<void> _openAudioSheet(ExploreMediaItem item) async {
    final l10n = context.l10n;
    final title = item.displayName?.trim().isNotEmpty == true
        ? item.displayName!.trim()
        : l10n.recordingAttachment;
    final diaryId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
              DiaryAudioPlayer(
                recording: DiaryAudioAttachment(
                  path: item.source,
                  duration: item.duration ?? Duration.zero,
                  name: item.displayName,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.of(sheetContext).pop(item.diaryId),
                child: Text(l10n.imageViewerOpenDiary),
              ),
            ],
          ),
        ),
      ),
    );
    if (diaryId != null && mounted) {
      unawaited(_openDiary(diaryId));
    }
  }

  /// 视频格点开：单独一页放日记正文同款 DiaryVideoPlayer（不新写播放器），
  /// 页里“打开日记”带 diaryId 回来，画廊页再打开那篇日记。
  Future<void> _openVideoPage(ExploreMediaItem item) async {
    final diaryId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => GalleryVideoPage(item: item)),
    );
    if (diaryId != null && mounted) {
      unawaited(_openDiary(diaryId));
    }
  }

  /// 看图页长按“打开日记”：预览页压在看图页之上（单篇入口，不左右翻），
  /// 返回时回到刚才那张图。在预览页删除日记时给 4 秒撤销，撤销即从回收站
  /// 恢复；提示落在返回后的看图页上。
  Future<void> _openDiary(String diaryId) async {
    final database = ref.read(appDatabaseProvider);
    final result = await Navigator.of(context).push<DiaryPreviewResult?>(
      MaterialPageRoute<DiaryPreviewResult?>(
        builder: (BuildContext context) => DiaryPreviewPage(diaryId: diaryId),
      ),
    );
    final deletedId = result?.diaryId;
    if (deletedId == null || !mounted) {
      return;
    }
    final l10n = context.l10n;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(l10n.autoT0075),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(label: l10n.commonUndo, onPressed: () {}),
      ),
    );
    if (reason == SnackBarClosedReason.action) {
      await database.restoreDiary(deletedId, touchUpdatedAt: false);
    }
  }
}

class _GalleryFooter extends StatelessWidget {
  const _GalleryFooter({
    required this.isLoading,
    required this.hasMore,
    required this.errorMessage,
    required this.endText,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;

  /// “已到底”文案：按当前分类区分（图片沿用旧文案，音频 / 视频 / 全部各有文案）。
  final String endText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final Widget content;
    if (isLoading) {
      content = const DelayedLoadingIndicator(
        key: ValueKey<String>('footer_loading'),
      );
    } else if (errorMessage != null) {
      content = Center(
        key: const ValueKey<String>('footer_error'),
        child: TextButton(onPressed: onRetry, child: Text(l10n.autoT0056)),
      );
    } else if (!hasMore) {
      content = Center(
        key: const ValueKey<String>('footer_end'),
        child: Text(
          endText,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    } else {
      content = const SizedBox.shrink(key: ValueKey<String>('footer_idle'));
    }
    // 指示器、重试与“已到底”之间淡入淡出，而不是硬切。
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      child: content,
    );
  }
}

/// 分段标题行：标题在左，第一段标题行右边再放一个 ⋮（整页的布局菜单）。
/// 张数不写在标题里，网格里一眼能数出来。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.showMenu,
    required this.onOpenMenu,
  });

  final String title;
  final bool showMenu;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 16, AppSpacing.m, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (showMenu)
            IconButton(
              tooltip: context.l10n.autoT0145,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: onOpenMenu,
              icon: const Icon(Icons.more_vert, size: 18),
            ),
        ],
      ),
    );
  }
}
