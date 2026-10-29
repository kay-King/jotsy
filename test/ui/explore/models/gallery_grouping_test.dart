import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/explore/models/explore_view_data.dart';

ExploreMediaItem item(String id, DateTime createdAt) => ExploreMediaItem(
  source: id,
  diaryId: id,
  updatedAt: createdAt,
  createdAt: createdAt,
  kind: GalleryMediaKind.image,
);

void main() {
  group('galleryGroupTypeFromRaw', () {
    test('known values parse, unknown falls back to month', () {
      expect(galleryGroupTypeFromRaw('year'), GalleryGroupType.year);
      expect(galleryGroupTypeFromRaw('month'), GalleryGroupType.month);
      expect(galleryGroupTypeFromRaw('day'), GalleryGroupType.day);
      expect(galleryGroupTypeFromRaw('week'), GalleryGroupType.month);
      expect(galleryGroupTypeFromRaw(null), GalleryGroupType.month);
    });
  });

  group('groupGalleryItems', () {
    test('empty input gives no groups', () {
      expect(groupGalleryItems(const [], GalleryGroupType.month), isEmpty);
    });

    test('month view groups by year-month in input order', () {
      final items = [
        item('a', DateTime(2026, 10, 25)),
        item('b', DateTime(2026, 10, 24)),
        item('c', DateTime(2026, 9, 20)),
      ];
      final groups = groupGalleryItems(items, GalleryGroupType.month);
      expect(groups.length, 2);
      expect(groups[0].key, DateTime(2026, 10));
      expect(groups[0].items.map((e) => e.source), ['a', 'b']);
      expect(groups[1].key, DateTime(2026, 9));
      expect(groups[1].items.map((e) => e.source), ['c']);
    });

    test('year view merges months of the same year', () {
      final items = [
        item('a', DateTime(2026, 10, 25)),
        item('b', DateTime(2025, 12, 31)),
        item('c', DateTime(2026, 1, 5)),
      ];
      final groups = groupGalleryItems(items, GalleryGroupType.year);
      expect(groups.length, 2);
      expect(groups[0].key, DateTime(2026));
      expect(groups[0].items.map((e) => e.source), ['a', 'c']);
      expect(groups[1].key, DateTime(2025));
    });

    test('day view splits same-month days', () {
      final items = [
        item('a', DateTime(2026, 10, 25, 21)),
        item('b', DateTime(2026, 10, 25, 9)),
        item('c', DateTime(2026, 10, 24)),
      ];
      final groups = groupGalleryItems(items, GalleryGroupType.day);
      expect(groups.length, 2);
      expect(groups[0].key, DateTime(2026, 10, 25));
      expect(groups[0].items.map((e) => e.source), ['a', 'b']);
      expect(groups[1].key, DateTime(2026, 10, 24));
    });
  });
}
