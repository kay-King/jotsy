import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/explore/controllers/explore_writing_stats_builder.dart';
import 'package:node_diary/ui/explore/models/explore_view_data.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);
  const builder = ExploreWritingStatsBuilder();
  ExploreDiaryOverview entry(
    String id, {
    DateTime? created,
    String text = '',
  }) => ExploreDiaryOverview(
    diaryId: id,
    title: id,
    contentText: text,
    metadata: '{}',
    createdAt: created ?? now,
    updatedAt: created ?? now,
    tags: const <Tag>[],
  );

  test('empty libraries report zeros and no conclusions', () {
    final stats = builder.build(
      const <ExploreDiaryOverview>[],
      imageCounts: const <String, int>{},
      now: now,
    );
    expect(stats.totalWords, 0);
    expect(stats.avgWordsPerDiary, 0);
    expect(stats.firstDiaryAt, isNull);
    expect(stats.recordDays, 0);
    expect(stats.lastDiaryAt, isNull);
    expect(stats.recent7Days, 0);
    expect(stats.longestGapDays, isNull);
    expect(stats.wordsByDay, isEmpty);
    expect(stats.monthWords, everyElement(0));
    expect(stats.trendMonths, hasLength(6));
    expect(stats.trendMonths.map((month) => month.count), everyElement(0));
    expect(stats.bestHour, -1);
    expect(stats.bestWeekday, -1);
    expect(stats.maxSingleWords, 0);
    expect(stats.diariesWithImages, 0);
    expect(stats.totalImages, 0);
    expect(stats.avgImagesPerDiary, 0);
    expect(stats.commaPer100, 0);
    expect(stats.sentenceTone, isNull);
    expect(stats.exclamationCount, 0);
    expect(stats.emojiCount, 0);
  });

  test('totals, days, months, gaps and images aggregate from overviews', () {
    final stats = builder.build(
      [
        entry('agg-today', text: '一二'),
        entry(
          'agg-yesterday',
          created: DateTime(2026, 10, 16, 23),
          text: 'hello world',
        ),
        entry('agg-gap', created: DateTime(2026, 10, 14), text: '字'),
        entry('agg-last-month', created: DateTime(2026, 9, 30), text: '忽略上月'),
      ],
      imageCounts: const <String, int>{'agg-today': 2, 'agg-gap': 1},
      now: now,
    );
    expect(stats.totalWords, 9);
    expect(stats.avgWordsPerDiary, 2);
    expect(stats.recordDays, 4);
    expect(stats.firstDiaryAt, DateTime(2026, 9, 30));
    expect(stats.lastDiaryAt, now);
    expect(stats.recent7Days, 3);
    // 9 月 30 日 → 10 月 14 日空了 13 天，是最长空档。
    expect(stats.longestGapDays, 13);
    expect(stats.wordsByDay[20261017], 2);
    expect(stats.wordsByDay[20260930], 4);
    expect(stats.monthWords[9], 5);
    expect(stats.monthWords[8], 4);
    expect(stats.monthCounts[9], 3);
    expect(stats.monthCounts[8], 1);
    expect(stats.trendMonths.map((month) => (month.month, month.count)), [
      (5, 0),
      (6, 0),
      (7, 0),
      (8, 0),
      (9, 1),
      (10, 3),
    ]);
    expect(stats.trendMonths[4].avgWords, 4);
    expect(stats.trendMonths[5].avgWords, 2);
    expect(stats.hourCounts[12], 1);
    expect(stats.hourCounts[23], 1);
    expect(stats.hourCounts[0], 2);
    // 4 篇 < 5 篇样本门槛，不下“最多几点写”的结论。
    expect(stats.bestHour, -1);
    expect(stats.bestWeekday, -1);
    expect(stats.maxSingleWords, 4);
    expect(stats.diariesWithImages, 2);
    expect(stats.totalImages, 3);
    expect(stats.avgImagesPerDiary, 0.8);
    expect(stats.sentenceTone, ExploreSentenceTone.short);
  });

  test('consecutive days have no gap, a single day has no gap to measure', () {
    final noGap = builder.build(
      [
        entry('gap-a', created: DateTime(2026, 10, 16)),
        entry('gap-b', created: DateTime(2026, 10, 17)),
      ],
      imageCounts: const <String, int>{},
      now: now,
    );
    expect(noGap.longestGapDays, 0);
    final single = builder.build(
      [entry('gap-only', created: DateTime(2026, 10, 17))],
      imageCounts: const <String, int>{},
      now: now,
    );
    expect(single.longestGapDays, isNull);
  });

  test('five entries unlock rhythm conclusions and tone bands', () {
    final stats = builder.build(
      [
        entry('tone-1', created: DateTime(2026, 10, 17, 21), text: '你好，你好，你好'),
        entry('tone-2', created: DateTime(2026, 10, 10, 21), text: '今天真好！'),
        entry('tone-3', created: DateTime(2026, 10, 3, 21), text: '会下雨吗？'),
        entry('tone-4', created: DateTime(2026, 9, 26, 21), text: '想了很久……'),
        entry('tone-5', created: DateTime(2026, 9, 19, 21), text: '开心😀'),
      ],
      imageCounts: const <String, int>{},
      now: now,
    );
    // 五篇都在 21 点：2026-10-17、10-10、10-3 都是周六。
    expect(stats.bestHour, 21);
    expect(stats.bestWeekday, 6);
    expect(stats.hourCounts[21], 5);
    expect(stats.weekdayCounts[6], 5);
    // 逗号密度：全文 2 个逗号 / 28 字（😀 按 UTF-16 算 2 个单位）
    // = 每 100 字 7.1 个，长句流。
    expect(stats.commaPer100, 7.1);
    expect(stats.sentenceTone, ExploreSentenceTone.long);
    expect(stats.exclamationCount, 1);
    expect(stats.questionCount, 1);
    expect(stats.ellipsisCount, 1);
    expect(stats.emojiCount, 1);
  });
}
