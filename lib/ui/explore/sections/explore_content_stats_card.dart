import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 内容卡：在写什么（只看得到“写了什么”，不解释“为什么”）。
///
/// - 最长一篇：单篇字数之最；
/// - 配图：带图篇数与图片总数合并成一行（原来两行说的是同一件事）；
/// - 句式习惯：每 100 字几个逗号（短句派 / 长句派的分水岭），注脚是
///   ！？…… / 表情里最多的三项。
class ExploreContentStatsCard extends StatelessWidget {
  const ExploreContentStatsCard({super.key, required this.stats});

  final ExploreWritingStats stats;

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
              icon: FontAwesomeIcons.fileLines,
              title: l10n.statsContentTitle,
            ),
            const SizedBox(height: 14),
            ExploreStatRow(
              label: l10n.statsLongestDiary,
              value: stats.maxSingleWords == 0
                  ? '—'
                  : l10n.statsLongestDiaryValue(stats.maxSingleWords),
            ),
            ExploreStatRow(
              label: l10n.statsImages,
              value: stats.totalImages == 0
                  ? '—'
                  : l10n.statsImagesValue(
                      stats.diariesWithImages,
                      stats.totalImages,
                      _oneDecimal(stats.avgImagesPerDiary),
                    ),
            ),
            ExploreStatRow(
              label: l10n.statsSentenceStyle,
              value: stats.sentenceTone == null
                  ? '—'
                  : l10n.statsSentenceValue(
                      _oneDecimal(stats.commaPer100),
                      _toneWord(l10n, stats.sentenceTone!),
                    ),
              footnote: _marksFootnote(l10n, stats),
              showDivider: false,
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.circleInfo,
                  size: 11,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.statsLocalOnly,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _toneWord(AppLocalizations l10n, ExploreSentenceTone tone) {
    return switch (tone) {
      ExploreSentenceTone.long => l10n.statsToneLong,
      ExploreSentenceTone.plain => l10n.statsTonePlain,
      ExploreSentenceTone.short => l10n.statsToneShort,
    };
  }

  /// 注脚：！？…… / 表情里最多的三项（样本不足只写个数，不写“次”）。
  String? _marksFootnote(AppLocalizations l10n, ExploreWritingStats stats) {
    final marks =
        <(String, int)>[
            ('！', stats.exclamationCount),
            ('？', stats.questionCount),
            ('……', stats.ellipsisCount),
            (l10n.statsMarkEmoji, stats.emojiCount),
          ].where((mark) => mark.$2 > 0).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    if (marks.isEmpty) {
      return null;
    }
    return marks.take(3).map((mark) => '${mark.$1} ×${mark.$2}').join(' · ');
  }

  /// 一位小数：3.0 写成 3，不写 3.0。
  static String _oneDecimal(double value) {
    return value == value.truncateToDouble() ? '${value.truncate()}' : '$value';
  }
}
