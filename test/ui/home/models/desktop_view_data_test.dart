import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/home/models/desktop_view_data.dart';

void main() {
  final now = DateTime(2026, 10, 25, 12);
  const builder = DesktopDataBuilder();
  ExploreDiaryOverview entry(
    String id, {
    DateTime? created,
    DateTime? updated,
    String text = '',
    String? cover,
  }) => ExploreDiaryOverview(
    diaryId: id,
    title: id,
    contentText: text,
    metadata: '{}',
    createdAt: created ?? now,
    updatedAt: updated ?? created ?? now,
    tags: const <Tag>[],
    cover: cover,
  );

  test('empty libraries report zeros and null latest', () {
    final data = builder.build(const <ExploreDiaryOverview>[], now: now);
    expect(data.totalRecords, 0);
    expect(data.streakDays, 0);
    expect(data.latestDiary, isNull);
    expect(data.totalImages, 0);
  });

  test('totals, streak and latest aggregate from overviews', () {
    final data = builder.build(
      [
        entry('today', text: '今天'),
        entry('yesterday', created: DateTime(2026, 10, 24, 23), text: '昨天'),
        entry('gap', created: DateTime(2026, 10, 22), text: '前天'),
      ],
      now: now,
      totalImages: 8,
    );
    expect(data.totalRecords, 3);
    // 今天 + 昨天连续，10 月 22 日隔了一天（23 日无记录）断开。
    expect(data.streakDays, 2);
    expect(data.latestDiary?.diaryId, 'today');
    expect(data.totalImages, 8);
  });

  test('streak is zero when nothing was written today', () {
    final data = builder.build([
      entry('yesterday', created: DateTime(2026, 10, 24, 23)),
      entry('day-before', created: DateTime(2026, 10, 23, 10)),
    ], now: now);
    expect(data.totalRecords, 2);
    expect(data.streakDays, 0);
    expect(data.latestDiary?.diaryId, 'yesterday');
  });

  test('latest is the newest by createdAt, not list order', () {
    final data = builder.build([
      entry('old-first', created: DateTime(2026, 10, 20)),
      entry('newest', created: DateTime(2026, 10, 25, 9)),
      entry('middle', created: DateTime(2026, 10, 23)),
    ], now: now);
    expect(data.latestDiary?.diaryId, 'newest');
  });

  test('image counting dedupes cover and body images per diary', () {
    // 正文是 Delta JSON：两张正文图 + 封面（其中一张与正文重复）。
    const content =
        '[{"insert":{"image":"img-a"}},{"insert":{"image":"img-b"}}]';
    final refs = <DiaryImageSourceRef>[
      const DiaryImageSourceRef(
        diaryId: 'with-images',
        cover: 'img-a',
        content: content,
      ),
      const DiaryImageSourceRef(
        diaryId: 'cover-only',
        cover: 'img-c',
        content: '[]',
      ),
      const DiaryImageSourceRef(
        diaryId: 'plain-text',
        cover: null,
        content: 'not json',
      ),
    ];
    expect(countDesktopTotalImages(refs), 3);
    expect(countDiaryImages(refs.first), 2);
  });
}
