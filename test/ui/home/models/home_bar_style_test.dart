import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_behavior.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';

void main() {
  group('HomeBarStyle defaults', () {
    test('match the fork Salt-style solid bar defaults', () {
      const d = HomeBarStyle.defaults;
      expect(d.material, HomeBarMaterial.solid);
      expect(d.glassTopBars, isTrue);
      expect(d.blurSigma, 20);
      expect(d.tintOpacity, 0.72);
      expect(d.tint, HomeBarTint.neutral);
      expect(d.border, isTrue);
      // fork 默认：顶栏发丝线开启（实色顶栏也画），标签间距 2，栏高 60。
      expect(d.topBarHairline, isTrue);
      expect(d.shadow, isTrue);
      expect(d.barHeight, 60);
      expect(d.cornerRadius, 32);
      expect(d.sideMargin, 16);
      expect(d.bottomGap, 12);
      expect(d.fabPlacement, HomeBarFabPlacement.above);
      expect(d.labelMode, HomeBarLabelMode.always);
      expect(d.iconSize, 20);
      expect(d.indicator, HomeBarIndicator.capsule);
      expect(d.labelGap, 2);
      expect(d.blockPadding, 6);
      expect(d.isDefault, isTrue);
      expect(d.toJson(), isEmpty);
    });
  });

  group('HomeBarStyle.fromJson', () {
    test('returns defaults for non-map input', () {
      for (final raw in <Object?>[null, 'x', 3, <Object>[], true]) {
        expect(HomeBarStyle.fromJson(raw), HomeBarStyle.defaults);
      }
    });

    test('decodes each field independently of bad neighbours', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'material': 'glass',
        'glassTopBars': 'yes',
        'blurSigma': 'big',
        'tintOpacity': 0.5,
        'tint': 'rainbow',
        'border': false,
        'topBarHairline': 'on',
        'shadow': 0,
        'barHeight': 70,
        'cornerRadius': null,
        'labelMode': 'selected',
        'indicator': 7,
      });
      expect(style.material, HomeBarMaterial.glass);
      expect(style.glassTopBars, isTrue);
      expect(style.blurSigma, 20);
      expect(style.tintOpacity, 0.5);
      expect(style.tint, HomeBarTint.neutral);
      expect(style.border, isFalse);
      expect(style.topBarHairline, isTrue);
      expect(style.shadow, isTrue);
      expect(style.barHeight, 70);
      expect(style.cornerRadius, 32);
      expect(style.labelMode, HomeBarLabelMode.selected);
      expect(style.indicator, HomeBarIndicator.capsule);
    });

    test('clamps numbers to their limits and rejects NaN', () {
      final high = HomeBarStyle.fromJson(<String, Object?>{
        'blurSigma': 999,
        'tintOpacity': 2,
        'barHeight': 500,
        'cornerRadius': 100,
        'sideMargin': 99,
        'bottomGap': 99,
        'iconSize': 99,
        'labelGap': 40,
        'blockPadding': 40,
      });
      expect(high.blurSigma, HomeBarStyleLimits.blurSigma.max);
      expect(high.tintOpacity, HomeBarStyleLimits.tintOpacity.max);
      expect(high.barHeight, HomeBarStyleLimits.barHeight.max);
      expect(high.cornerRadius, HomeBarStyleLimits.cornerRadius.max);
      expect(high.sideMargin, HomeBarStyleLimits.sideMargin.max);
      expect(high.bottomGap, HomeBarStyleLimits.bottomGap.max);
      expect(high.iconSize, HomeBarStyleLimits.iconSize.max);
      expect(high.labelGap, 12);
      expect(high.blockPadding, 16);

      final low = HomeBarStyle.fromJson(<String, Object?>{
        'blurSigma': -5,
        'tintOpacity': 0,
        'barHeight': 1,
        'iconSize': 1,
        'labelGap': -3,
        'blockPadding': -3,
      });
      expect(low.blurSigma, 0);
      expect(low.tintOpacity, HomeBarStyleLimits.tintOpacity.min);
      expect(low.barHeight, HomeBarStyleLimits.barHeight.min);
      expect(low.iconSize, HomeBarStyleLimits.iconSize.min);
      expect(low.labelGap, 0);
      expect(low.blockPadding, 0);

      final nan = HomeBarStyle.fromJson(<String, Object?>{
        'blurSigma': double.nan,
        'barHeight': double.infinity,
      });
      expect(nan.blurSigma, HomeBarStyle.defaults.blurSigma);
      expect(nan.barHeight, HomeBarStyle.defaults.barHeight);
    });

    test('decodes label gap and block padding tolerantly', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'labelGap': 7,
        'blockPadding': 'wide',
      });
      expect(style.labelGap, 7);
      expect(style.blockPadding, 6);
    });

    test('falls back on unknown enum names', () {
      final style = HomeBarStyle.fromJson(<String, Object?>{
        'material': 'metal',
        'tint': 'neon',
        'labelMode': 'sometimes',
        'indicator': 'glow',
        'fabPlacement': 'left',
      });
      expect(style, HomeBarStyle.defaults);
    });

    test('falls back to neutral for a removed custom tint name', () {
      // 旧 JSON 里的 "tint": "custom" 已无对应枚举值，按未知名回退中性。
      final style = HomeBarStyle.fromJson(<String, Object?>{'tint': 'custom'});
      expect(style.tint, HomeBarTint.neutral);
      expect(style, HomeBarStyle.defaults);
    });
  });

  group('HomeBarStyle.toJson', () {
    test('writes only fields that differ from the defaults', () {
      const style = HomeBarStyle(material: HomeBarMaterial.glass, iconSize: 24);
      expect(style.toJson(), <String, Object>{
        'material': 'glass',
        'iconSize': 24.0,
      });
    });

    test('round-trips every field through JSON text', () {
      const style = HomeBarStyle(
        material: HomeBarMaterial.glass,
        glassTopBars: false,
        blurSigma: 33,
        tintOpacity: 0.4,
        tint: HomeBarTint.theme,
        border: false,
        topBarHairline: true,
        shadow: false,
        barHeight: 72,
        cornerRadius: 12,
        sideMargin: 8,
        bottomGap: 20,
        fabPlacement: HomeBarFabPlacement.inline,
        labelMode: HomeBarLabelMode.never,
        iconSize: 26,
        indicator: HomeBarIndicator.none,
        labelGap: 9,
        blockPadding: 11,
      );
      final decoded = HomeBarStyle.fromJson(
        jsonDecode(jsonEncode(style.toJson())),
      );
      expect(decoded, style);
      expect(decoded.hashCode, style.hashCode);
    });

    test('writes the top bar hairline only when it is turned off', () {
      // fork 默认开启顶栏发丝线：稀疏编码只在关掉时才写该字段。
      const style = HomeBarStyle(topBarHairline: false);
      expect(style.toJson(), <String, Object>{'topBarHairline': false});
      expect(HomeBarStyle.fromJson(style.toJson()), style);
      expect(style, isNot(HomeBarStyle.defaults));
      expect(HomeBarStyle.defaults.copyWith(topBarHairline: false), style);
      expect(const HomeBarStyle(topBarHairline: true).toJson(), isEmpty);
    });

    test('omits default spacing and writes changed spacing', () {
      expect(
        const HomeBarStyle(labelGap: 2, blockPadding: 6).toJson(),
        isEmpty,
      );
      expect(
        const HomeBarStyle(labelGap: 4, blockPadding: 10).toJson(),
        <String, Object>{'labelGap': 4.0, 'blockPadding': 10.0},
      );
    });

  });

  group('HomeBarStyle.withMaterial', () {
    test('keeps the fork default label gap across materials', () {
      // fork 的默认间距已与玻璃紧间距同为 2：换材质不再联动改间距。
      final glass = HomeBarStyle.defaults.withMaterial(HomeBarMaterial.glass);
      expect(glass.material, HomeBarMaterial.glass);
      expect(glass.labelGap, HomeBarStyle.glassLabelGap);
      final solid = glass.withMaterial(HomeBarMaterial.solid);
      expect(solid.labelGap, HomeBarStyle.glassLabelGap);
      expect(solid, HomeBarStyle.defaults);
    });

    test('keeps a label gap the user chose', () {
      const custom = HomeBarStyle(labelGap: 7, blockPadding: 3);
      final glass = custom.withMaterial(HomeBarMaterial.glass);
      expect(glass.labelGap, 7);
      expect(glass.blockPadding, 3);
      expect(glass.withMaterial(HomeBarMaterial.solid).labelGap, 7);
    });

    test('re-selecting the same material changes nothing', () {
      const glass = HomeBarStyle(
        material: HomeBarMaterial.glass,
        labelGap: HomeBarStyle.glassLabelGap,
      );
      expect(glass.withMaterial(HomeBarMaterial.glass), glass);
      expect(
        HomeBarStyle.defaults.withMaterial(HomeBarMaterial.solid),
        HomeBarStyle.defaults,
      );
    });
  });

  group('HomeBarBehavior', () {
    test('defaults to off and encodes sparsely', () {
      expect(HomeBarBehavior.defaults.hideOnScroll, isFalse);
      expect(HomeBarBehavior.defaults.indicatorFollowsSwipe, isFalse);
      expect(HomeBarBehavior.defaults.toJson(), isEmpty);
      expect(
        const HomeBarBehavior(hideOnScroll: true).toJson(),
        <String, Object>{'hideOnScroll': true},
      );
    });

    test('decodes tolerantly and round-trips', () {
      expect(HomeBarBehavior.fromJson('x'), HomeBarBehavior.defaults);
      final behavior = HomeBarBehavior.fromJson(<String, Object?>{
        'hideOnScroll': 'yes',
        'indicatorFollowsSwipe': true,
      });
      expect(behavior.hideOnScroll, isFalse);
      expect(behavior.indicatorFollowsSwipe, isTrue);
      expect(HomeBarBehavior.fromJson(behavior.toJson()), behavior);
      expect(
        behavior.copyWith(hideOnScroll: true),
        const HomeBarBehavior(hideOnScroll: true, indicatorFollowsSwipe: true),
      );
    });
  });
}
