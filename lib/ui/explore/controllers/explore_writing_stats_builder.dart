import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';
import '../models/explore_view_data.dart';

/// 写作统计聚合器（纯函数，无 IO）。
///
/// 输入探索页概览（已含纯文本与创建时间）与配图计数（日记 id → 图片数），
/// 输出概况 / 节奏 / 内容三段数据。口径照搬 fakeWechat 统计页：
/// - 热力图按绝对字数分档（1 / 100 / 300 / 700），不按相对排名——颜色
///   必须能对上字数；
/// - 月度柱按字数画高，篇数只作注脚；
/// - “最多几点 / 星期几写”低于 5 篇不下结论；
/// - 最长空档是唯一的坚持度指标，用中性词“空档”，不叫“断更”。
///
/// 字数一律经 [DiaryWordCounts]（[TextStats] 口径），与本月字数等既有
/// 统计一致；标点密度按原文字符数算，逐篇计数求和，不把全文拼成一个
/// 大字符串。
class ExploreWritingStatsBuilder {
  const ExploreWritingStatsBuilder();

  /// 分布类结论（几点写 / 星期几写）的最低样本量。
  static const int sampleMinimum = 5;

  /// 句式习惯档位阈值：每 100 字逗号数。
  static const double _longSentenceThreshold = 6;
  static const double _plainSentenceThreshold = 3;

  ExploreWritingStats build(
    List<ExploreDiaryOverview> diaries, {
    required Map<String, int> imageCounts,
    required DateTime now,
  }) {
    // 每篇字数只算一次，之后各段复用。
    final wordsPerDiary = <int>[];
    var totalWords = 0;
    var maxSingleWords = 0;
    var totalChars = 0;
    var commaCount = 0;
    var exclamationCount = 0;
    var questionCount = 0;
    var ellipsisCount = 0;
    var emojiCount = 0;
    for (final item in diaries) {
      final count = DiaryWordCounts.of(
        diaryId: item.diaryId,
        updatedAt: item.updatedAt,
        text: item.contentText,
      );
      wordsPerDiary.add(count);
      totalWords += count;
      if (count > maxSingleWords) {
        maxSingleWords = count;
      }
      totalChars += item.contentText.length;
      commaCount += _countMatches(_commaPattern, item.contentText);
      exclamationCount += _countMatches(_exclamationPattern, item.contentText);
      questionCount += _countMatches(_questionPattern, item.contentText);
      ellipsisCount += _countMatches(_ellipsisPattern, item.contentText);
      emojiCount += _countMatches(_emojiPattern, item.contentText);
    }

    final localNow = now.toLocal();
    final today = DateUtils.dateOnly(localNow);
    int dayKey(DateTime date) =>
        date.year * 10000 + date.month * 100 + date.day;

    // 按天 / 月 / 小时 / 星期几聚合（全部按本地时间）。
    final wordsByDay = <int, int>{};
    final monthWords = List<int>.filled(12, 0);
    final monthCounts = List<int>.filled(12, 0);
    final hourCounts = List<int>.filled(24, 0);
    final weekdayCounts = List<int>.filled(7, 0);
    DateTime? firstDiaryAt;
    DateTime? lastDiaryAt;
    var recent7Days = 0;
    final weekAgo = today.subtract(const Duration(days: 6));
    for (var i = 0; i < diaries.length; i++) {
      final item = diaries[i];
      final created = item.createdAt.toLocal();
      final key = dayKey(created);
      wordsByDay.update(
        key,
        (value) => value + wordsPerDiary[i],
        ifAbsent: () => wordsPerDiary[i],
      );
      if (created.year == localNow.year) {
        monthWords[created.month - 1] += wordsPerDiary[i];
        monthCounts[created.month - 1] += 1;
      }
      hourCounts[created.hour] += 1;
      weekdayCounts[created.weekday % 7] += 1;
      if (firstDiaryAt == null || created.isBefore(firstDiaryAt)) {
        firstDiaryAt = created;
      }
      if (lastDiaryAt == null || created.isAfter(lastDiaryAt)) {
        lastDiaryAt = created;
      }
      if (!created.isBefore(weekAgo)) {
        recent7Days += 1;
      }
    }

    // 最长空档：相邻两个有记录的日子之间空了多少天。
    int? longestGapDays;
    if (wordsByDay.length >= 2) {
      final days = wordsByDay.keys.map(_dateFromDayKey).toList()..sort();
      var gapMax = 0;
      for (var i = 1; i < days.length; i++) {
        final gap = days[i].difference(days[i - 1]).inDays - 1;
        if (gap > gapMax) {
          gapMax = gap;
        }
      }
      longestGapDays = gapMax;
    }

    // 近 6 个月平均每篇字数走势（含本月，由早到晚）。
    final trendMonths = <ExploreTrendMonth>[];
    for (var back = 5; back >= 0; back--) {
      final month = DateTime(localNow.year, localNow.month - back);
      var count = 0;
      var words = 0;
      for (var i = 0; i < diaries.length; i++) {
        final created = diaries[i].createdAt.toLocal();
        if (created.year == month.year && created.month == month.month) {
          count += 1;
          words += wordsPerDiary[i];
        }
      }
      trendMonths.add(
        ExploreTrendMonth(
          year: month.year,
          month: month.month,
          count: count,
          avgWords: count == 0 ? 0 : (words / count).round(),
        ),
      );
    }

    // 分布结论：样本不足不下结论；并列时取靠前的。
    final enough = diaries.length >= sampleMinimum;
    final bestHour = enough ? _pickBin(hourCounts) : -1;
    final bestWeekday = enough ? _pickBin(weekdayCounts) : -1;

    // 配图：只按本次概览里出现的日记算，与总数同一口径。
    var diariesWithImages = 0;
    var totalImages = 0;
    for (final item in diaries) {
      final count = imageCounts[item.diaryId] ?? 0;
      if (count > 0) {
        diariesWithImages += 1;
      }
      totalImages += count;
    }

    // 句式习惯：每 100 字几个逗号（正常化，不受篇幅影响）。
    final commaPer100 = totalChars == 0
        ? 0.0
        : (commaCount / totalChars * 1000).round() / 10;
    final ExploreSentenceTone? sentenceTone = totalChars == 0
        ? null
        : commaPer100 > _longSentenceThreshold
        ? ExploreSentenceTone.long
        : commaPer100 >= _plainSentenceThreshold
        ? ExploreSentenceTone.plain
        : ExploreSentenceTone.short;

    return ExploreWritingStats(
      totalWords: totalWords,
      avgWordsPerDiary: diaries.isEmpty
          ? 0
          : (totalWords / diaries.length).round(),
      firstDiaryAt: firstDiaryAt,
      recordDays: wordsByDay.length,
      lastDiaryAt: lastDiaryAt,
      recent7Days: recent7Days,
      longestGapDays: longestGapDays,
      wordsByDay: wordsByDay,
      monthWords: monthWords,
      monthCounts: monthCounts,
      trendMonths: trendMonths,
      hourCounts: hourCounts,
      weekdayCounts: weekdayCounts,
      bestHour: bestHour,
      bestWeekday: bestWeekday,
      maxSingleWords: maxSingleWords,
      diariesWithImages: diariesWithImages,
      totalImages: totalImages,
      avgImagesPerDiary: diaries.isEmpty
          ? 0
          : (totalImages / diaries.length * 10).round() / 10,
      commaPer100: commaPer100,
      sentenceTone: sentenceTone,
      exclamationCount: exclamationCount,
      questionCount: questionCount,
      ellipsisCount: ellipsisCount,
      emojiCount: emojiCount,
    );
  }

  /// 取分布里最高的那一格（并列时取靠前的），全 0 返回 -1。
  int _pickBin(List<int> bin) {
    var bestIndex = -1;
    var bestValue = 0;
    for (var i = 0; i < bin.length; i++) {
      if (bin[i] > bestValue) {
        bestValue = bin[i];
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int _countMatches(RegExp pattern, String text) =>
      pattern.allMatches(text).length;

  /// 日键还原为日期：用 UTC 零点算天数差，避开本地夏令时边界上 23/25
  /// 小时那天把相邻两天算成 0 天的问题。
  DateTime _dateFromDayKey(int key) =>
      DateTime.utc(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  static final RegExp _commaPattern = RegExp(r'[，,]');
  static final RegExp _exclamationPattern = RegExp('！');
  static final RegExp _questionPattern = RegExp('？');

  /// 省略号按“出现次数”数：连续的 …… 算 1 次（按字符数会把一个“……”
  /// 数成 2 次）；西文三个点以上同样算 1 次。
  static final RegExp _ellipsisPattern = RegExp(r'…+|\.{3,}');

  /// 表情：Unicode 属性转义覆盖笑脸 / 手势 / 动物 / ❤ 等绝大多数 emoji。
  /// 分析器不认 Extended_Pictographic 这个属性名，但 Dart 运行时在
  /// unicode: true 下支持它（与 text_stats 的 \p{L} 同一机制）。
  static final RegExp _emojiPattern = RegExp(
    // ignore: valid_regexps
    r'\p{Extended_Pictographic}',
    unicode: true,
  );
}
