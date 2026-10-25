import '../../../core/database/app_database.dart';
import '../../../utils/text_stats.dart';
import '../models/explore_view_data.dart';

/// 写作统计聚合器（纯函数，无 IO）。
///
/// 只算概况卡三行要的字段（累计字数 / 平均 / 第一次 / 天数 / 最近一篇）。
/// 节奏 / 内容两张卡与概况里的热力图已下线（2026-10-25），月度、小时、
/// 星期、走势、配图、句式、标点、按天字数、最长空档这些聚合都已删掉。
/// 字数一律经 [DiaryWordCounts]（[TextStats] 口径），与本月字数等既有
/// 统计一致。
class ExploreWritingStatsBuilder {
  const ExploreWritingStatsBuilder();

  ExploreWritingStats build(
    List<ExploreDiaryOverview> diaries, {
    required DateTime now,
  }) {
    var totalWords = 0;
    final dayKeys = <int>{};
    DateTime? firstDiaryAt;
    DateTime? lastDiaryAt;
    for (final item in diaries) {
      totalWords += DiaryWordCounts.of(
        diaryId: item.diaryId,
        updatedAt: item.updatedAt,
        text: item.contentText,
      );
      final created = item.createdAt.toLocal();
      dayKeys.add(created.year * 10000 + created.month * 100 + created.day);
      if (firstDiaryAt == null || created.isBefore(firstDiaryAt)) {
        firstDiaryAt = created;
      }
      if (lastDiaryAt == null || created.isAfter(lastDiaryAt)) {
        lastDiaryAt = created;
      }
    }

    return ExploreWritingStats(
      totalWords: totalWords,
      avgWordsPerDiary: diaries.isEmpty
          ? 0
          : (totalWords / diaries.length).round(),
      firstDiaryAt: firstDiaryAt,
      recordDays: dayKeys.length,
      lastDiaryAt: lastDiaryAt,
    );
  }
}
