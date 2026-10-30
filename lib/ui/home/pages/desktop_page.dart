import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/controllers/diary_create_entry_flow.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/providers/diary_profile_provider.dart';
import '../../explore/controllers/explore_page_controller.dart';
import '../../explore/models/explore_view_data.dart';
import '../../explore/pages/explore_insight_page.dart';
import '../../explore/pages/explore_memory_page.dart';
import '../../explore/providers/explore_providers.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_entrance.dart';
import '../../settings/pages/desktop_layout_page.dart';
import '../models/desktop_layout/desktop_layout.dart';
import '../providers/desktop_layout_provider.dart';
import '../sections/desktop_header.dart';
import '../sections/desktop_recent.dart';
import '../sections/desktop_tiles.dart';
import '../sections/desktop_write_button.dart';

/// 首页（桌面页）：底栏第一个 Tab。
///
/// 桌面、探索、日历三页合一（只合组合与导航，不动功能逻辑），从上到下
/// 默认四部分：题头（日期 + 按时间变的问候 + 总览数一行）→ 写点什么按钮 →
/// 快捷入口（时间线 / 相册 / 日历 / 标签 / 那年今日 / 情绪与精力趋势，
/// 2 行 3 格，全是点进新页面的入口）→ 最近记录（最近 3 篇 + 查看全部）。
/// 去重原则不变：首页上加了按钮，原来的整卡就不要——概况、那年今日整卡、
/// 情绪趋势整卡、标签云、媒体画廊都不再放首页：概况随那年今日按钮进
/// 概况 + 那年今日页，情绪趋势随按钮进洞察页，标签云、媒体画廊分别由
/// 标签、相册按钮进对应页；题头里的总览数只是一行字，不与概况卡重复。
///
/// 四个区块的顺序与显隐可配（[DesktopLayout]，设置 → 外观与语言 → 首页布局）：
/// 渲染时按布局分成常驻区（题头、写点什么）与数据区（快捷入口、最近记录），
/// 区内保持布局里的相对顺序；跨区拖拽不改变分区，只在区内排序。
///
/// 数据只读：趋势与那年今日的数据 provider 与聚合逻辑照搬原来的探索页
///（exploreDiariesProvider / moodOptionsProvider +
/// ExplorePageController）；题头的总数、连续天数就是探索页统计的同一口径，
/// 最近记录直接取轻量日记流里按创建时间倒序的前 3 篇，图片数复用探索页
/// 的媒体来源 provider。
class DesktopPage extends ConsumerStatefulWidget {
  const DesktopPage({super.key, required this.pageBackgroundColor});

  final Color pageBackgroundColor;

  @override
  ConsumerState<DesktopPage> createState() => _DesktopPageState();
}

class _DesktopPageState extends ConsumerState<DesktopPage> {
  final ExplorePageController _controller = const ExplorePageController();
  List<ExploreDiaryOverview>? _cachedDiariesRef;
  String? _cachedLocaleName;
  String? _cachedDayKey;
  String? _cachedMoodOptionsRaw;
  ExploreViewData? _cachedViewData;

  ExploreViewData _resolveViewData({
    required List<ExploreDiaryOverview> diaries,
    required AppLocalizations l10n,
    required String moodOptionsRaw,
    required List<String> moodOptions,
  }) {
    final day = DateUtils.dateOnly(DateTime.now());
    final dayKey = '${day.year}-${day.month}-${day.day}';
    final shouldRebuild =
        _cachedViewData == null ||
        !identical(diaries, _cachedDiariesRef) ||
        _cachedLocaleName != l10n.localeName ||
        _cachedDayKey != dayKey ||
        _cachedMoodOptionsRaw != moodOptionsRaw;

    if (!shouldRebuild) {
      return _cachedViewData!;
    }

    _cachedViewData = _controller.buildViewData(
      diaries,
      now: DateTime.now(),
      l10n: l10n,
      moodOptions: moodOptions,
    );
    _cachedDiariesRef = diaries;
    _cachedLocaleName = l10n.localeName;
    _cachedDayKey = dayKey;
    _cachedMoodOptionsRaw = moodOptionsRaw;
    return _cachedViewData!;
  }

  /// 最新一篇：按创建时间取最大；没有日记时为 null（口径与原来
  /// DesktopDataBuilder 一致）。
  ExploreDiaryOverview? _latestDiary(List<ExploreDiaryOverview> diaries) {
    if (diaries.isEmpty) {
      return null;
    }
    var latest = diaries.first;
    for (final item in diaries) {
      if (item.createdAt.isAfter(latest.createdAt)) {
        latest = item;
      }
    }
    return latest;
  }

  /// 最近 3 篇：按创建时间倒序截取。
  List<ExploreDiaryOverview> _recentDiaries(
    List<ExploreDiaryOverview> diaries,
  ) {
    final sorted = List<ExploreDiaryOverview>.of(diaries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(3).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final profile = ref.watch(diaryProfileProvider);
    final layout = ref.watch(desktopLayoutProvider);
    final diariesAsync = ref.watch(exploreDiariesProvider);
    final moodOptionsAsync = ref.watch(moodOptionsProvider);
    final moodOptions = moodOptionsAsync.maybeWhen(
      data: (options) => options,
      orElse: () => SettingsService.defaultMoodOptions,
    );
    final moodOptionsRaw = moodOptions.join('\u{1F}');

    // 布局把四个区块按顺序分成两个渲染区（相对顺序不变）：
    // - 常驻区：题头、写点什么（不依赖日记流，首帧即现）；
    // - 数据区：快捷入口、最近记录（等日记流，走原来的加载 / 错误分支）。
    // 跨区拖拽时只在区内相对排序，不会把数据区模块搬到常驻区之前。
    final visible = layout.visibleModuleIds;
    final alwaysModules = <DesktopModuleId>[
      for (final id in visible)
        if (id == DesktopModuleId.header || id == DesktopModuleId.writeButton)
          id,
    ];
    final dataModules = <DesktopModuleId>[
      for (final id in visible)
        if (id == DesktopModuleId.quickEntry || id == DesktopModuleId.recent)
          id,
    ];

    final children = <Widget>[];
    for (var i = 0; i < alwaysModules.length; i++) {
      children.add(
        _buildAlwaysModule(
          alwaysModules[i],
          now: now,
          nickname: profile.displayNickname,
          diariesAsync: diariesAsync,
          l10n: l10n,
          moodOptionsRaw: moodOptionsRaw,
          moodOptions: moodOptions,
        ),
      );
      children.add(const SizedBox(height: 16));
    }
    if (dataModules.isNotEmpty) {
      children.add(
        _buildDataZone(
          context,
          dataModules,
          diariesAsync: diariesAsync,
          now: now,
          l10n: l10n,
          moodOptionsRaw: moodOptionsRaw,
          moodOptions: moodOptions,
        ),
      );
    }
    if (children.isEmpty) {
      // 四个区块全关时给个空态，点一下进布局页重新打开。
      children.add(_DesktopLayoutEmptyState());
    } else if (children.last is SizedBox) {
      // 数据区自带底边距时，去掉常驻区末尾多余的间隔。
      children.removeLast();
    }

    return Scaffold(
      backgroundColor: widget.pageBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: children,
        ),
      ),
    );
  }

  /// 常驻区模块：题头（日期 + 问候 + 总览数一行）/ 写点什么按钮。
  /// 题头不依赖日记数据；总览数要等日记流，加载中先占一行高度。
  Widget _buildAlwaysModule(
    DesktopModuleId id, {
    required DateTime now,
    required String nickname,
    required AsyncValue<List<ExploreDiaryOverview>> diariesAsync,
    required AppLocalizations l10n,
    required String moodOptionsRaw,
    required List<String> moodOptions,
  }) {
    switch (id) {
      case DesktopModuleId.header:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DesktopHeader(now: now, nickname: nickname),
            const SizedBox(height: 6),
            // 总览数要等日记流：加载中先占一行高度，避免内容跳动；统计
            // 口径就是探索页算好的 viewData.stats（总数、连续天数）。
            diariesAsync.maybeWhen(
              data: (diaries) {
                final viewData = _resolveViewData(
                  diaries: diaries,
                  l10n: l10n,
                  moodOptionsRaw: moodOptionsRaw,
                  moodOptions: moodOptions,
                );
                return DesktopStatsLine(
                  totalRecords: viewData.stats.totalRecords,
                  streakDays: viewData.stats.streakDays,
                  latestUpdatedAt: _latestDiary(diaries)?.updatedAt,
                  now: now,
                );
              },
              orElse: () => const SizedBox(height: 18),
            ),
          ],
        );
      case DesktopModuleId.writeButton:
        // 写按钮不依赖日记数据，常驻。
        return const DesktopWriteButton();
      case DesktopModuleId.quickEntry:
      case DesktopModuleId.recent:
        // 数据区模块不在这里渲染，防御性返回空。
        return const SizedBox.shrink();
    }
  }

  /// 数据区：快捷入口 / 最近记录，按布局顺序排。加载 / 错误分支与原来
  /// 一致（骨架屏、错误卡），只是内容区的两个模块顺序可配。
  Widget _buildDataZone(
    BuildContext context,
    List<DesktopModuleId> dataModules, {
    required AsyncValue<List<ExploreDiaryOverview>> diariesAsync,
    required DateTime now,
    required AppLocalizations l10n,
    required String moodOptionsRaw,
    required List<String> moodOptions,
  }) {
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      child: diariesAsync.when(
        // 本地查询通常很快：300ms 内保持空白、内容直接淡入，不再先
        // 闪一帧骨架屏、又在 250ms 交叉淡入里残留成重影；慢查询
        // 才淡入骨架屏。
        loading: () => DelayedLoadingGate(
          key: const ValueKey<String>('home_skeleton'),
          loading: true,
          builder: (context, showSkeleton) => showSkeleton
              ? const ExpressiveEntrance(
                  offset: Offset.zero,
                  duration: ExpressiveMotion.fast,
                  child: _DesktopPageSkeleton(),
                )
              : const SizedBox.shrink(),
        ),
        error: (error, stackTrace) => _DesktopPageErrorCard(
          key: const ValueKey<String>('home_error'),
          message: '$error',
        ),
        data: (diaries) {
          final viewData = _resolveViewData(
            diaries: diaries,
            l10n: l10n,
            moodOptionsRaw: moodOptionsRaw,
            moodOptions: moodOptions,
          );
          final content = <Widget>[];
          for (var i = 0; i < dataModules.length; i++) {
            switch (dataModules[i]) {
              case DesktopModuleId.quickEntry:
                content.add(
                  DesktopTiles(
                    onOpenMemory: () => _openMemoryPage(context, viewData),
                    onOpenInsight: () => _openInsightPage(context, viewData),
                  ),
                );
              case DesktopModuleId.recent:
                content.add(
                  DesktopRecent(recent: _recentDiaries(diaries), now: now),
                );
              case DesktopModuleId.header:
              case DesktopModuleId.writeButton:
                break;
            }
            if (i < dataModules.length - 1) {
              content.add(const SizedBox(height: 16));
            }
          }
          return Column(
            key: const ValueKey<String>('home_content'),
            mainAxisSize: MainAxisSize.min,
            children: content,
          );
        },
      ),
    );
  }

  void _openPreview(
    BuildContext context,
    String diaryId, {
    DiaryPreviewSequence? sequence,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiaryPreviewPage(diaryId: diaryId, sequence: sequence),
      ),
    );
  }

  /// 与首页 FAB 同一条新建流程：有草稿时先弹草稿选择面板。
  void _openCreateToday(BuildContext context) {
    unawaited(runDiaryCreateEntryFlow(context, ref));
  }

  /// 那年今日页：上面是概况、下面是那年今日内容。点卡片里的某篇进
  /// 预览页（带着当年今日的顺序，左右可翻）；没记录时点“补写今天”
  /// 走新建流程——和原来整卡的行为一致。
  void _openMemoryPage(BuildContext context, ExploreViewData viewData) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreMemoryPage(
          viewData: viewData,
          controller: _controller,
          onOpenDiary: (diaryId) {
            _openPreview(
              context,
              diaryId,
              // 只有“那年今日”会打开日记：在这几篇里左右翻。
              sequence: DiaryPreviewSequence(
                ids: <String>[
                  for (final item in viewData.onThisDayDiaries) item.diaryId,
                ],
              ),
            );
          },
          onCreateToday: () => _openCreateToday(context),
        ),
      ),
    );
  }

  /// 情绪与精力趋势页：就是原来首页上那张洞察卡，整卡挪到新页面里。
  void _openInsightPage(BuildContext context, ExploreViewData viewData) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreInsightPage(
          moodWeights30: viewData.moodWeights30,
          energyValues7: viewData.energyValues7,
        ),
      ),
    );
  }
}

class _DesktopPageSkeleton extends StatelessWidget {
  const _DesktopPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.surfaceContainerHigh;
    // 写按钮常驻顶部，骨架只占快捷入口卡的位置。
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _DesktopPageErrorCard extends StatelessWidget {
  const _DesktopPageErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.autoT0059,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 四个区块全关时的空态：点一下进布局页重新打开。
class _DesktopLayoutEmptyState extends ConsumerWidget {
  const _DesktopLayoutEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.desktopLayoutEmptyTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopLayoutEmptySubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final settings = ref.read(settingsServiceProvider).asData?.value;
              if (settings == null) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DesktopLayoutPage(settingsService: settings),
                ),
              );
            },
            child: Text(l10n.desktopLayoutOpenEditor),
          ),
        ],
      ),
    );
  }
}
