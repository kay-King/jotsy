import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../utils/relative_time_formatter.dart';
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 概况卡：顶部三个数（日记总数 / 连续记录 / 本月字数）+ 存量三行
/// （累计字数 / 写了多久 / 最近一篇）。
///
/// 顶部三个数原先是独立的 ExploreStatsCard，内容与本卡重叠（都是总览数），
/// 合并到本卡顶部。年度热力图已下线（2026-10-25，用户不想要），
/// 节奏 / 内容两张卡也已下线，只留这张概况卡。
class ExploreOverviewCard extends StatelessWidget {
  const ExploreOverviewCard({
    super.key,
    required this.stats,
    required this.totalRecords,
    required this.streakDays,
    required this.currentMonthWords,
    required this.now,
  });

  final ExploreWritingStats stats;
  final int totalRecords;
  final int streakDays;
  final int currentMonthWords;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: ExploreCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreSectionTitle(
              icon: FontAwesomeIcons.chartColumn,
              title: l10n.statsOverviewTitle,
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: ExploreStatTile(
                    icon: FontAwesomeIcons.bookOpen,
                    label: l10n.autoT0066,
                    value: totalRecords,
                  ),
                ),
                _buildDivider(colorScheme),
                Expanded(
                  child: ExploreStatTile(
                    icon: FontAwesomeIcons.fire,
                    label: l10n.autoT0067,
                    value: streakDays,
                  ),
                ),
                _buildDivider(colorScheme),
                Expanded(
                  child: ExploreStatTile(
                    icon: FontAwesomeIcons.penNib,
                    label: l10n.autoT0068,
                    value: currentMonthWords,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ExploreStatRow(
              label: l10n.statsTotalWords,
              value: l10n.statsTotalWordsValue(
                stats.totalWords,
                stats.avgWordsPerDiary,
              ),
            ),
            ExploreStatRow(
              label: l10n.statsWritingSpan,
              value: stats.firstDiaryAt == null
                  ? '—'
                  : l10n.statsWritingSpanValue(
                      DateFormat.yMMMd(
                        l10n.localeName,
                      ).format(stats.firstDiaryAt!.toLocal()),
                      stats.recordDays,
                    ),
            ),
            ExploreStatRow(
              label: l10n.statsLatestDiary,
              value: stats.lastDiaryAt == null
                  ? '—'
                  : RelativeTimeFormatter.formatUpdatedAt(
                      updatedAt: stats.lastDiaryAt!,
                      now: now,
                      l10n: l10n,
                    ),
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}
