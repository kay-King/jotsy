import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card_cover.dart';
import 'package:node_diary/ui/explore/providers/explore_providers.dart';
import 'package:node_diary/ui/home/models/home_tab.dart';
import 'package:node_diary/ui/home/providers/home_tab_request_provider.dart';
import 'package:node_diary/ui/home/widgets/desktop_card.dart';
import 'package:node_diary/utils/relative_time_formatter.dart';

/// 最近记录：一张白卡，标题行 + 查看全部；下面列最近几篇日记。
///
/// 每行：左侧封面小图（有封面时）+ 标题 + 时间 · 图片数 · 可见范围，
/// 跟 moodDiary「我的」页的最近记录排法一致。点某行进预览页；
/// 点“查看全部”切到底栏的日记 Tab（日记列表页）。
/// 图片数复用探索页的媒体来源 provider（封面 + 正文图片去重后计数），
/// 与画廊页同一口径；provider 还在加载时按 0 计（不显示图片数）。
class DesktopRecent extends ConsumerWidget {
  const DesktopRecent({super.key, required this.recent, required this.now});

  /// 最近的日记（调用方已按创建时间倒序、截到 3 篇）。
  final List<ExploreDiaryOverview> recent;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final imageSources = ref.watch(exploreMediaSourcesProvider).asData?.value;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.desktopLatestTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref
                    .read(homeTabRequestProvider.notifier)
                    .request(HomeTab.diaries),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.desktopViewAll,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            _DesktopRecentEmpty(
              onWrite: () async {
                await runDiaryCreateEntryFlow(context, ref);
              },
            )
          else
            for (var i = 0; i < recent.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 14),
              _DesktopRecentRow(
                diary: recent[i],
                imageCount: imageSources?[recent[i].diaryId]?.length ?? 0,
                now: now,
              ),
            ],
        ],
      ),
    );
  }
}

/// 最近记录空态：没有日记时的一句提示 + 写一篇按钮。
class _DesktopRecentEmpty extends StatelessWidget {
  const _DesktopRecentEmpty({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.desktopStatsLineEmpty,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onWrite, child: Text(l10n.navDiaries)),
      ],
    );
  }
}

/// 最近记录的一行：左侧封面小图 + 标题 + 时间 · 图片数 · 仅自己可见。
class _DesktopRecentRow extends StatelessWidget {
  const _DesktopRecentRow({
    required this.diary,
    required this.imageCount,
    required this.now,
  });

  final ExploreDiaryOverview diary;
  final int imageCount;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final cover = diary.cover?.trim();
    final title = diary.title.trim().isNotEmpty
        ? diary.title.trim()
        : diary.contentText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final meta = StringBuffer(
      RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: diary.updatedAt,
        now: now,
        l10n: l10n,
      ),
    );
    if (imageCount > 0) {
      meta.write(' · ${l10n.desktopImagesCount(imageCount)}');
    }
    meta.write(' · ${l10n.desktopOnlyMe}');
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DiaryPreviewPage(diaryId: diary.diaryId),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (cover != null && cover.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DiaryCardCoverImage(
                source: cover,
                width: 64,
                height: 64,
                radius: 8,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurface,
                    ),
                  ),
                if (title.isNotEmpty) const SizedBox(height: 6),
                Text(
                  meta.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
