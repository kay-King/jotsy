import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('AppPlatform text selection menu', () {
    test('widget tests default to Android: mobile with all capabilities', () {
      expect(AppPlatform.isAndroid, isTrue);
      expect(AppPlatform.isMobile, isTrue);
      expect(AppPlatform.isDesktop, isFalse);
      expect(AppPlatform.isMacOS, isFalse);
      expect(AppPlatform.supportsTextShare, isTrue);
      expect(AppPlatform.supportsProcessText, isTrue);
    });

    test('only phones share selected text', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          AppPlatform.supportsTextShare,
          platform == TargetPlatform.android || platform == TargetPlatform.iOS,
          reason: '$platform',
        );
      }
    });

    test('only Android offers process text actions', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          AppPlatform.supportsProcessText,
          platform == TargetPlatform.android,
          reason: '$platform',
        );
      }
    });

    test('desktop platforms are not mobile', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(AppPlatform.isDesktop, isTrue, reason: '$platform');
        expect(AppPlatform.isMobile, isFalse, reason: '$platform');
        expect(AppPlatform.isAndroid, isFalse, reason: '$platform');
      }
    });

    test('macOS is identified', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(AppPlatform.isMacOS, isTrue);
      expect(AppPlatform.isDesktop, isTrue);
    });
  });
}
