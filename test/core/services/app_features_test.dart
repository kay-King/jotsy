import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_features.dart';

void main() {
  group('AppFeatures.decode', () {
    test('falls back to defaults for missing or unreadable values', () {
      for (final raw in <String?>[null, '', '   ', '{not json', '[1,2]', '7']) {
        expect(AppFeatures.decode(raw), AppFeatures.defaults, reason: raw);
      }
    });

    test('reads each field on its own and ignores unknown keys', () {
      final features = AppFeatures.decode(
        jsonEncode(<String, Object?>{
          'desktop': false,
          'notebooks': false,
          'anniversaries': null,
          'templates': 0,
          'timeCapsules': false,
          'swipeArchive': 'off',
          'futureFeature': false,
        }),
      );

      expect(
        features,
        const AppFeatures(
          desktop: false,
          notebooks: false,
          timeCapsules: false,
        ),
      );
    });
  });

  group('AppFeatures.encode', () {
    test('stores nothing for the defaults', () {
      expect(AppFeatures.defaults.encode(), isNull);
      expect(const AppFeatures().encode(), isNull);
    });

    test('round-trips every non-default combination field', () {
      const features = AppFeatures(
        desktop: false,
        anniversaries: false,
        templates: false,
        swipeArchive: false,
      );
      final raw = features.encode();

      expect(raw, isNotNull);
      expect((jsonDecode(raw!) as Map).keys, <String>[
        'desktop',
        'notebooks',
        'anniversaries',
        'templates',
        'timeCapsules',
        'swipeArchive',
      ]);
      expect(AppFeatures.decode(raw), features);
    });
  });

  group('AppFeatures.anniversariesEnabled', () {
    test('only follows the anniversaries toggle', () {
      expect(AppFeatures.defaults.anniversariesEnabled, isTrue);
      expect(
        const AppFeatures(anniversaries: false).anniversariesEnabled,
        isFalse,
      );
      expect(
        const AppFeatures(
          desktop: false,
          anniversaries: false,
        ).anniversariesEnabled,
        isFalse,
      );
    });
  });

  group('AppFeatures value semantics', () {
    test('copyWith changes only the given fields', () {
      final next = AppFeatures.defaults.copyWith(notebooks: false);

      expect(next, const AppFeatures(notebooks: false));
      expect(next.copyWith(), next);
      expect(next.copyWith(notebooks: true), AppFeatures.defaults);
    });

    test('equal values share a hash code', () {
      const a = AppFeatures(notebooks: false, timeCapsules: false);
      const b = AppFeatures(timeCapsules: false, notebooks: false);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == AppFeatures.defaults, isFalse);
    });
  });
}
