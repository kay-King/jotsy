import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../utils/relative_time_formatter.dart';
import '../models/explore_view_data.dart';
import '../widgets/explore_shared_widgets.dart';

/// 概况卡：年度写作热力图 + 存量三行。
///
/// 热力图照搬 fakeWechat 的画法：近 53 周 × 7 天，列从周一开始；深浅按
/// 绝对字数分档（0 / 1-99 / 100-299 / 300-699 / 700+），颜色是微信绿
/// 的四档透明度；数据少时整片空格子本身就是信息，不设样本门槛。
/// 默认停在最右（最近的时间），要看更早的横向滑。
class ExploreHeatmapCard extends StatelessWidget {
  const ExploreHeatmapCard({
    super.key,
    required this.stats,
    required this.totalRecords,
    required this.now,
  });

  final ExploreWritingStats stats;
  final int totalRecords;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gap = stats.longestGapDays;
    final subtitle =
        l10n.statsHeatmapNearYear(totalRecords) +
        (gap != null && gap > 0 ? ' · ${l10n.statsHeatmapGap(gap)}' : '');
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
            ExploreChartTitle(
              title: l10n.statsHeatmapTitle,
              subtitle: subtitle,
            ),
            const SizedBox(height: 10),
            _HeatmapGrid(wordsByDay: stats.wordsByDay, now: now),
            const SizedBox(height: 12),
            const _HeatmapLegend(),
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
}

/// 热力图例：色块在上、字数在正下方。
class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  static const List<(int, String)> _levels = <(int, String)>[
    (0, '0'),
    (1, '1-99'),
    (100, '100-299'),
    (300, '300-699'),
    (700, '700+'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    // 图例不用 Row：5 档色块 + 字数标签在 320dp 窄屏放不下，Row 会在右边
    // 溢出 12px（2026-10-25 实测，首页那几个测试渲染探索页时跟着挂）。
    // Wrap 靠右对齐，放得下时还是一行，放不下自动折到第二行，不溢出。
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          l10n.statsHeatmapLegend,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        for (final (words, label) in _levels)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _heatColor(words, colorScheme, isDark),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

Color _heatColor(int words, ColorScheme colorScheme, bool isDark) {
  if (words <= 0) {
    return colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.35 : 0.6,
    );
  }
  const green = Color(0xFF07C160);
  final level = words < 100
      ? 1
      : words < 300
      ? 2
      : words < 700
      ? 3
      : 4;
  return green.withValues(
    alpha: const <double>[0, 0.3, 0.52, 0.76, 1.0][level],
  );
}

/// 53 周热力网格（横向滚动，首帧后停在最右）。
class _HeatmapGrid extends StatefulWidget {
  const _HeatmapGrid({required this.wordsByDay, required this.now});

  final Map<int, int> wordsByDay;
  final DateTime now;

  @override
  State<_HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<_HeatmapGrid> {
  static const double _cellSize = 12;
  static const double _gap = 3;
  static const double _monthLabelHeight = 14;
  static const int _weeks = 53;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final today = DateUtils.dateOnly(widget.now.toLocal());
    // 本周一往前 52 周：列从周一开始，每列 7 天。
    final start = today.subtract(
      Duration(days: (today.weekday - 1) + (_weeks - 1) * 7),
    );
    // 先把 53 列算好（月份标签只在月份变化的那列出现），再一次性渲染；
    // 不把月份判断留在子 widget 的闭包里，避免依赖构建顺序。
    final columns = <Widget>[];
    var lastMonth = -1;
    for (var c = 0; c < _weeks; c++) {
      final weekStart = start.add(Duration(days: c * 7));
      final monthLabel = weekStart.month != lastMonth
          ? DateFormat.MMM(l10n.localeName).format(weekStart)
          : '';
      lastMonth = weekStart.month;
      columns.add(
        Padding(
          padding: EdgeInsets.only(right: c == _weeks - 1 ? 0 : _gap),
          child: Column(
            children: <Widget>[
              SizedBox(
                width: _cellSize,
                height: _monthLabelHeight,
                child: Text(
                  monthLabel,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (var r = 0; r < 7; r++)
                Padding(
                  padding: EdgeInsets.only(top: r == 0 ? 0 : _gap),
                  child: Container(
                    width: _cellSize,
                    height: _cellSize,
                    decoration: BoxDecoration(
                      color: _heatColor(
                        _wordsOn(weekStart.add(Duration(days: r)), today),
                        colorScheme,
                        isDark,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DowLabels(l10n: l10n),
          ...columns,
        ],
      ),
    );
  }

  /// 当天的字数；未来的格子按 0 算（还没到那天）。
  int _wordsOn(DateTime date, DateTime today) {
    if (date.isAfter(today)) {
      return 0;
    }
    final key = date.year * 10000 + date.month * 100 + date.day;
    return widget.wordsByDay[key] ?? 0;
  }
}

/// 左侧星期标签（一 / 三 / 五 / 日，隔行显示）。
class _DowLabels extends StatelessWidget {
  const _DowLabels({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: _HeatmapGridState._monthLabelHeight,
        right: _HeatmapGridState._gap,
      ),
      child: Column(
        children: <Widget>[
          for (var r = 0; r < 7; r++)
            Padding(
              padding: EdgeInsets.only(
                top: r == 0 ? 0 : _HeatmapGridState._gap,
              ),
              child: SizedBox(
                width: 14,
                height: _HeatmapGridState._cellSize,
                child: Text(
                  // 行 0/2/4/6 是周一/三/五/日（列从周一开始）。
                  r % 2 == 0
                      ? weekdayShortLabel((r + 1) % 7, l10n.localeName)
                      : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
