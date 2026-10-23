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
  final generated = MaterialThemeSchemes.withNeutralSurfaces(
    ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    ),
  );
  // 主色钉回种子色本身：tonalSpot 生成的主色会被稀释成发闷的灰钢蓝
  // （#0470E6 → #435E91），开关、分组标题都跟着发灰，与参照的鲜蓝对不上。
  // 亮色直接用种子色；暗色把种子色提到可在深底上读的明度，色相不变。
  final primary = brightness == Brightness.light
      ? seedColor
      : HSLColor.fromColor(seedColor).withLightness(0.68).toColor();
  return MaterialTheme(
    brightness == Brightness.light
        ? Typography.material2021().black
        : Typography.material2021().white,
  ).theme(generated.copyWith(primary: primary));
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
      // 不再强制内置 HarmonyOSSansSC：UI 字体走系统默认，与参照应用
      // （IdeaMemo 等原生应用）同源，用户换系统字体时界面随之而变。
      // 日记正文字体是 DiaryTypography 的独立设置，不受影响。
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
    );
    final resolvedTextTheme = baseTheme.textTheme
        .merge(textTheme)
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );
    // Salt 风字阶（照 IdeaMemo 的观感）：全部字重压到 w400 常规——用户
    // 的系统字体在 w500 以上会切成粗书法面（或合成假粗），标题显得又
    // 黑又挤；w400 时是干净的细面（设置页副标题即此效果）。层级靠大小
    // 与颜色区分，不靠字重。行高一并放开（标题 1.3、正文 1.5），避免
    // 书法体字面高、行距紧贴的拥挤感。
    final emphasizedTextTheme = resolvedTextTheme.copyWith(
      headlineLarge: resolvedTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 25,
        height: 1.3,
      ),
      headlineMedium: resolvedTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 22,
        height: 1.3,
      ),
      headlineSmall: resolvedTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 20,
        height: 1.3,
      ),
      titleLarge: resolvedTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 18.5,
        height: 1.3,
      ),
      titleMedium: resolvedTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.35,
      ),
      titleSmall: resolvedTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.35,
      ),
      bodyLarge: resolvedTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: resolvedTextTheme.bodyMedium?.copyWith(
        fontSize: 14.5,
        height: 1.5,
      ),
      bodySmall: resolvedTextTheme.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.45,
      ),
      labelLarge: resolvedTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      labelMedium: resolvedTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
      labelSmall: resolvedTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w400,
        fontSize: 11,
      ),
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
