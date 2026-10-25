import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/explore/controllers/explore_writing_stats_builder.dart';

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

  test('empty libraries report zeros and nulls', () {
    final stats = builder.build(const <ExploreDiaryOverview>[], now: now);
    expect(stats.totalWords, 0);
    expect(stats.avgWordsPerDiary, 0);
    expect(stats.firstDiaryAt, isNull);
    expect(stats.recordDays, 0);
    expect(stats.lastDiaryAt, isNull);
  });

  test('totals, days and first/last aggregate from overviews', () {
    final stats = builder.build([
      entry('agg-today', text: '一二'),
      entry(
        'agg-yesterday',
        created: DateTime(2026, 10, 16, 23),
        text: 'hello world',
      ),
      entry('agg-gap', created: DateTime(2026, 10, 14), text: '字'),
      entry('agg-last-month', created: DateTime(2026, 9, 30), text: '忽略上月'),
    ], now: now);
    expect(stats.totalWords, 9);
    expect(stats.avgWordsPerDiary, 2);
    // 4 篇落在 4 个不同的日子。
    expect(stats.recordDays, 4);
    expect(stats.firstDiaryAt, DateTime(2026, 9, 30));
    expect(stats.lastDiaryAt, now);
  });

  test('same-day entries count as one record day', () {
    final stats = builder.build([
      entry('same-a', created: DateTime(2026, 10, 17, 9)),
      entry('same-b', created: DateTime(2026, 10, 17, 21)),
    ], now: now);
    expect(stats.recordDays, 1);
    expect(stats.firstDiaryAt, DateTime(2026, 10, 17, 9));
    expect(stats.lastDiaryAt, DateTime(2026, 10, 17, 21));
  });
}
