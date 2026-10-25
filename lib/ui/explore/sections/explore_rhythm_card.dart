import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 节奏卡：什么时候写（月 / 6 个月走势 / 小时 / 星期几）+ 近 7 天 / 最长空档。
///
/// 月度柱按字数画高（1 篇 800 字和 1 篇 20 字不能一样高），篇数只作注脚；
/// 走势是整页唯一回答“我写得怎么样”的图（近 6 个月平均每篇字数）；
/// 时段图只给形状、结论写在标题右侧。
class ExploreRhythmCard extends StatelessWidget {
  const ExploreRhythmCard({super.key, required this.stats, required this.now});

  final ExploreWritingStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final year = now.toLocal().year;
    final yearCount = stats.monthCounts.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final maxMonthWords = stats.monthWords.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    return RepaintBoundary(
      child: ExploreCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExploreSectionTitle(
              icon: FontAwesomeIcons.clock,
              title: l10n.statsRhythmTitle,
            ),
            const SizedBox(height: 14),
            ExploreChartTitle(
              title: l10n.statsMonthWordsTitle(year),
              subtitle: l10n.statsMonthPeak(maxMonthWords, yearCount),
            ),
            const SizedBox(height: 8),
            ExploreVerticalBars(
              values: stats.monthWords,
              labels: <String>[for (var m = 1; m <= 12; m++) '$m'],
              valueLabels: <String>[
                for (final words in stats.monthWords)
                  words == 0 ? '' : _compactNumber(words),
              ],
              height: 132,
            ),
            const SizedBox(height: 20),
            ExploreChartTitle(
              title: l10n.statsTrendTitle,
              subtitle: _trendNote(l10n, stats.trendMonths),
            ),
            const SizedBox(height: 8),
            _TrendChart(months: stats.trendMonths, now: now),
            const SizedBox(height: 20),
            ExploreChartTitle(
              title: l10n.statsRhythmChartTitle,
              subtitle: _rhythmNote(l10n, stats),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.statsRhythmDay,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ExploreVerticalBars(
              values: stats.hourCounts,
              labels: <String>[
                for (var h = 0; h < 24; h++) h % 3 == 0 ? '$h' : '',
              ],
              height: 92,
              topIndex: stats.bestHour,
              dimOthers: true,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.statsRhythmWeek,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ExploreVerticalBars(
              values: stats.weekdayCounts,
              labels: <String>[
                for (var i = 0; i < 7; i++)
                  weekdayShortLabel(i, l10n.localeName),
              ],
              height: 92,
              topIndex: stats.bestWeekday,
              dimOthers: true,
            ),
            const SizedBox(height: 16),
            ExploreStatRow(
              label: l10n.statsRecent7Days,
              value: l10n.statsRecent7DaysValue(stats.recent7Days),
            ),
            ExploreStatRow(
              label: l10n.statsLongestGap,
              value: stats.longestGapDays == null
                  ? '—'
                  : stats.longestGapDays == 0
                  ? l10n.statsNoGap
                  : l10n.statsDaysValue(stats.longestGapDays!),
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }

  /// 走势注：本月与上月都有数据时比平均字数；只有零星数据时不写注；
  /// 6 个月里一篇都没有时提示再写几篇。
  String? _trendNote(AppLocalizations l10n, List<ExploreTrendMonth> months) {
    if (months.length != 6) {
      return l10n.statsTrendEmpty;
    }
    final current = months[5];
    final previous = months[4];
    if (current.count > 0 && previous.count > 0) {
      final diff = current.avgWords - previous.avgWords;
      if (diff == 0) {
        return l10n.statsTrendEqual;
      }
      return diff > 0 ? l10n.statsTrendMore(diff) : l10n.statsTrendLess(-diff);
    }
    if (months.any((month) => month.count > 0)) {
      return null;
    }
    return l10n.statsTrendEmpty;
  }

  /// 时段结论直接写在标题右侧：图给形状、文字给答案。
  String _rhythmNote(AppLocalizations l10n, ExploreWritingStats stats) {
    if (stats.bestHour >= 0 && stats.bestWeekday >= 0) {
      final hour = l10n.statsHourLabel(stats.bestHour);
      final weekday = DateFormat.E(
        l10n.localeName,
      ).format(DateTime.utc(2024, 1, 7 + stats.bestWeekday));
      return l10n.statsRhythmBest('$hour · $weekday');
    }
    return l10n.statsRhythmMore;
  }

  /// 柱顶数字：≥1000 字时写成 1.2k 这类紧凑写法。
  static String _compactNumber(int value) {
    if (value < 1000) {
      return '$value';
    }
    final compact = (value / 100).round() / 10;
    return compact == compact.truncateToDouble()
        ? '${compact.truncate()}k'
        : '${compact}k';
  }
}

/// 近 6 个月平均每篇字数的折线图：点用 bottom 定位、线用 y（距顶部）定
/// 位，两套坐标要换算（bottom = avg/max*82，正好是 100-y 的比例）。
/// 数值直接标在点的上方。
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.months, required this.now});

  final List<ExploreTrendMonth> months;
  final DateTime now;

  static const double _plotHeight = 88;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final resolved = months.length == 6 ? months : _zeroMonths(now);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxAvg = resolved.fold<int>(
          1,
          (max, month) => month.avgWords > max ? month.avgWords : max,
        );
        // 顶部留 18 给数值标签，底部留 4；点在两者之间按比例落位。
        Offset point(int index) {
          final month = resolved[index];
          final x = (index + 0.5) / 6 * width;
          final y = 18 + (1 - month.avgWords / maxAvg) * (_plotHeight - 22);
          return Offset(x, y);
        }

        final points = <Offset>[for (var i = 0; i < 6; i++) point(i)];
        return Column(
          children: <Widget>[
            SizedBox(
              height: _plotHeight,
              child: Stack(
                children: <Widget>[
                  CustomPaint(
                    size: Size(width, _plotHeight),
                    painter: _TrendLinePainter(points, colorScheme.primary),
                  ),
                  for (var i = 0; i < 6; i++) ...<Widget>[
                    Positioned(
                      left: points[i].dx - 3,
                      top: points[i].dy - 3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (resolved[i].count > 0)
                      Positioned(
                        left: points[i].dx - 20,
                        top: points[i].dy - 18,
                        width: 40,
                        child: Text(
                          '${resolved[i].avgWords}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                for (final month in resolved)
                  Expanded(
                    child: Text(
                      DateFormat.MMM(
                        l10n.localeName,
                      ).format(DateTime(month.year, month.month)),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<ExploreTrendMonth> _zeroMonths(DateTime now) {
    final localNow = now.toLocal();
    return <ExploreTrendMonth>[
      for (var back = 5; back >= 0; back--)
        ExploreTrendMonth(
          year: DateTime(localNow.year, localNow.month - back).year,
          month: DateTime(localNow.year, localNow.month - back).month,
          count: 0,
          avgWords: 0,
        ),
    ];
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter(this.points, this.color);

  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
