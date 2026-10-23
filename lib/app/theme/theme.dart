import "package:flutter/material.dart";

import 'expressive_controls.dart';
import 'expressive_surfaces.dart';

part 'theme_color_schemes.dart';

/// 由种子色装配应用的亮/暗主题：种子色只决定强调色，表面一律中性灰阶。
///
/// 应用外壳与设置页里的明暗预览共用同一装配，预览看到的就是切换主题后的
/// 真实效果。从种子生成的配色会给表面染上种子色调（MD3 观感的主要来源），
/// 故装配后统一经 [MaterialThemeSchemes.withNeutralSurfaces] 换成简约灰阶，
/// 页面呈现“白底 + 白卡片细线分层”的扁平效果，种子色只体现在按钮、开关等强调处。
ThemeData buildSeededAppTheme(Color seedColor, Brightness brightness) {
  return MaterialTheme(
    brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white,
  ).theme(
    MaterialThemeSchemes.withNeutralSurfaces(
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      ),
    ),
  );
}

/// 应用 Material 3 Expressive 主题装配器。
///
/// 职责：
/// - 承载不同亮暗/对比度下的 `ColorScheme` 入口；
/// - 统一输出 `ThemeData`；
/// - 将大体积配色常量拆到独立文件，保持本文件聚焦在“装配逻辑”。
class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() => MaterialThemeSchemes.lightScheme;
  ThemeData light() => theme(lightScheme());

  static ColorScheme lightMediumContrastScheme() =>
      MaterialThemeSchemes.lightMediumContrastScheme;
  ThemeData lightMediumContrast() => theme(lightMediumContrastScheme());

  static ColorScheme lightHighContrastScheme() =>
      MaterialThemeSchemes.lightHighContrastScheme;
  ThemeData lightHighContrast() => theme(lightHighContrastScheme());

  static ColorScheme darkScheme() => MaterialThemeSchemes.darkScheme;
  ThemeData dark() => theme(darkScheme());

  static ColorScheme darkMediumContrastScheme() =>
      MaterialThemeSchemes.darkMediumContrastScheme;
  ThemeData darkMediumContrast() => theme(darkMediumContrastScheme());

  static ColorScheme darkHighContrastScheme() =>
      MaterialThemeSchemes.darkHighContrastScheme;
  ThemeData darkHighContrast() => theme(darkHighContrastScheme());

  ThemeData theme(ColorScheme colorScheme) {
    // 页面画布统一取 colorScheme.surface：简约皮肤下它是中性浅灰，
    // 纯白卡片在其上分层，换主题色时底色保持中性、只有强调色变化。
    final scaffoldBg = ExpressiveSurfaces.pageBackground(colorScheme);
    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamily: 'HarmonyOSSansSC',
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
    );
    final resolvedTextTheme = baseTheme.textTheme
        .merge(textTheme)
        .apply(
          fontFamily: 'HarmonyOSSansSC',
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );
    // 简约皮肤不做大号粗体标题：整体字号比 MD3 规范收小一档，标题与标签
    // 统一用常规/中等字重，靠大小与颜色分层级，而不是靠加粗加大。
    // 组件主题仍集中在这里装配，第三方 Material 控件也会继承。
    final emphasizedTextTheme = resolvedTextTheme.copyWith(
      headlineLarge: resolvedTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 26,
      ),
      headlineMedium: resolvedTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 23,
      ),
      headlineSmall: resolvedTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 20,
      ),
      titleLarge: resolvedTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 19,
      ),
      titleMedium: resolvedTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      titleSmall: resolvedTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 13.5,
      ),
      bodyLarge: resolvedTextTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: resolvedTextTheme.bodyMedium?.copyWith(fontSize: 13.5),
      bodySmall: resolvedTextTheme.bodySmall?.copyWith(fontSize: 11.5),
      labelLarge: resolvedTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      labelMedium: resolvedTextTheme.labelMedium?.copyWith(fontSize: 11.5),
      labelSmall: resolvedTextTheme.labelSmall?.copyWith(fontSize: 10.5),
    );
    return ExpressiveSurfaces.apply(
      ExpressiveControls.apply(
        baseTheme.copyWith(textTheme: emphasizedTextTheme),
      ),
    );
  }

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
