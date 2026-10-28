import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_style.dart';

final _light = ColorScheme.fromSeed(seedColor: Colors.teal);
final _dark = ColorScheme.fromSeed(
  seedColor: Colors.teal,
  brightness: Brightness.dark,
);

HomeBarResolvedStyle _resolve(HomeBarStyle style, ColorScheme scheme) =>
    HomeBarResolvedStyle.resolve(style, scheme);

HomeBarStyle _withBorder(HomeBarLineStyle line) =>
    HomeBarPreset.glass.style.copyWith(borderLine: line);

void main() {
  group('line colors', () {
    test('defaults resolve to the outline variant at each line opacity', () {
      final glass = HomeBarPreset.glass.style;
      for (final scheme in <ColorScheme>[_light, _dark]) {
        final resolved = _resolve(glass, scheme);
        expect(
          resolved.borderColor,
          scheme.outlineVariant.withValues(alpha: 0.6),
        );
        expect(resolved.borderWidth, 1.0);
        expect(
          resolved.hairlineColor,
          scheme.outlineVariant.withValues(alpha: 0.35),
        );
        expect(resolved.hairlineWidth, 0.6);
      }
    });

    test('each color source per brightness', () {
      Color border(HomeBarLineColor color, ColorScheme scheme) => _resolve(
        _withBorder(
          HomeBarLineStyle.borderDefaults.copyWith(color: color, opacity: 1),
        ),
        scheme,
      ).borderColor;

      expect(border(HomeBarLineColor.theme, _light), _light.outlineVariant);
      expect(border(HomeBarLineColor.theme, _dark), _dark.outlineVariant);
      expect(
        border(HomeBarLineColor.highlight, _light),
        _light.surfaceContainerLowest,
      );
      expect(border(HomeBarLineColor.highlight, _dark), _dark.onSurface);
      expect(border(HomeBarLineColor.primary, _light), _light.primary);
      expect(border(HomeBarLineColor.primary, _dark), _dark.primary);
    });

    test('opacity is applied and both values are clamped', () {
      final half = _resolve(
        _withBorder(
          HomeBarLineStyle.borderDefaults.copyWith(
            color: HomeBarLineColor.primary,
            opacity: 0.5,
          ),
        ),
        _light,
      );
      expect(half.borderColor, _light.primary.withValues(alpha: 0.5));

      final wild = _resolve(
        HomeBarPreset.glass.style.copyWith(
          borderLine: const HomeBarLineStyle(opacity: 0, width: 9),
          topBarLine: const HomeBarLineStyle(opacity: 4, width: 0),
        ),
        _light,
      );
      expect(wild.borderColor.a, closeTo(0.10, 0.002));
      expect(wild.borderWidth, HomeBarStyleLimits.lineWidth.max);
      expect(wild.hairlineColor.a, 1);
      expect(wild.hairlineWidth, HomeBarStyleLimits.lineWidth.min);
    });

    test('line changes alter the resolved style', () {
      final glass = HomeBarPreset.glass.style;
      final base = _resolve(glass, _light);
      final wider = _resolve(
        glass.copyWith(
          topBarLine: HomeBarLineStyle.topBarDefaults.copyWith(width: 1.2),
        ),
        _light,
      );
      expect(wider, isNot(base));
      expect(wider.hashCode, isNot(base.hashCode));
      expect(_resolve(glass, _light), base);
    });

    test('lines are drawn only while their switches are on', () {
      final glass = HomeBarPreset.glass.style;
      expect(_resolve(glass, _light).border, isTrue);
      expect(_resolve(glass.copyWith(border: false), _light).border, isFalse);
      // fork：发丝线默认开启，关掉开关才不画。
      expect(_resolve(glass, _light).topBarHairline, isTrue);
      expect(
        _resolve(glass.copyWith(topBarHairline: false), _light).topBarHairline,
        isFalse,
      );
      // 底栏描边仍只属于玻璃栏；顶栏发丝线在实色栏上同样绘制（fork）。
      final solid = _resolve(
        HomeBarStyle.defaults.copyWith(
          topBarHairline: true,
          borderLine: HomeBarLineStyle.borderDefaults.copyWith(width: 3),
        ),
        _light,
      );
      expect(solid.border, isFalse);
      expect(solid.topBarHairline, isTrue);
    });

    test('the clear preset resolves to a highlight rim', () {
      final clear = _resolve(HomeBarPreset.clear.style, _light);
      expect(
        clear.borderColor,
        _light.surfaceContainerLowest.withValues(alpha: 0.7),
      );
      expect(
        _resolve(HomeBarPreset.clear.style, _dark).borderColor,
        _dark.onSurface.withValues(alpha: 0.7),
      );
    });
  });
}
