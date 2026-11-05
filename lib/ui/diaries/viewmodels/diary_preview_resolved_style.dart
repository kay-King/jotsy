import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/seeded_theme_cache.dart';
import '../../settings/models/mood_palette.dart';
import '../models/diary_preview_style/diary_preview_style.dart';

/// 预览页样式在当前主题、屏幕与这篇日记下的具体取值。
///
/// 输入：样式、应用主题与种子色、屏幕尺寸、是否减少动画，以及这篇日记的心情
/// 与首个标签色（配色基调用）。输出：页面主题、底色、正文与标题颜色、实际
/// 边距、正文最大宽度与头图高度。纯计算；主题实例经 [SeededThemeCache] 复用。
///
/// 着色规则：
/// - 配色基调不是“跟随应用”、或纸色与应用主题深浅相反时，整页换成由种子色
///   装配的另一套主题（深色纸上是深色主题），信息栏、胶囊、引用条、勾选框等
///   所有语义色一起变化，不会出现深色纸上的深色文字；
/// - 默认样式（跟随应用 + 主题底色）原样返回应用主题，渲染与改版前一致；
/// - 基调为“心情”时，种子色取自心情色板（[MoodPalette]）里这篇日记心情对应
///   的颜色，再按着色强度（[DiaryPreviewPageStyle.colorIntensity]）调整；
/// - “纸张随基调染色”打开、且纸张为主题底色时，底色染上一点种子色；
/// - 正文与标题一律用主题色，不再支持自定义颜色。
@immutable
class DiaryPreviewResolvedStyle {
  const DiaryPreviewResolvedStyle._({
    required this.style,
    required this.theme,
    required this.themed,
    required this.background,
    required this.bodyColor,
    required this.titleColor,
    required this.horizontalPadding,
    required this.maxContentWidth,
    required this.coverHeight,
  });

  /// 内置纸色：（浅色主题，深色主题）。墨色两种主题下都是深色纸。
  static const Map<DiaryPreviewPaper, (int, int)> paperColors =
      <DiaryPreviewPaper, (int, int)>{
        DiaryPreviewPaper.warm: (0xFFFBF7EE, 0xFF24221D),
        DiaryPreviewPaper.sepia: (0xFFF4ECD8, 0xFF2B2620),
        DiaryPreviewPaper.mint: (0xFFE9F3EB, 0xFF1C2620),
        DiaryPreviewPaper.gray: (0xFFF1F1EF, 0xFF1F2022),
        DiaryPreviewPaper.ink: (0xFF1E2126, 0xFF121417),
      };

  /// 标题下分隔线的不透明度（浅色页 / 深色页），见 [titleDividerColor]。
  static const double titleDividerOpacityLight = 0.16;
  static const double titleDividerOpacityDark = 0.2;

  factory DiaryPreviewResolvedStyle.resolve({
    required DiaryPreviewStyle style,
    required ThemeData appTheme,
    required Color appSeed,
    required Size screenSize,
    required bool reduceMotion,
    required MoodPalette moodPalette,
    String? moodEmoji,
    int? firstTagColor,
  }) {
    final page = style.page;
    final appBrightness = appTheme.brightness;
    final paper = _paperColor(page, appBrightness);
    final pageBrightness = paper == null
        ? appBrightness
        : ThemeData.estimateBrightnessForColor(paper);
    Color? seed = switch (page.colorSeed) {
      DiaryPreviewColorSeed.app => null,
      DiaryPreviewColorSeed.mood => _moodColor(moodEmoji, moodPalette),
      DiaryPreviewColorSeed.tag =>
        firstTagColor == null ? null : Color(firstTagColor),
    };
    if (seed != null && page.colorSeed == DiaryPreviewColorSeed.mood) {
      seed = _applyIntensity(seed, page.colorIntensity);
    }
    final themed = seed != null || pageBrightness != appBrightness;
    final theme = themed
        ? SeededThemeCache.of(
            seed ?? appSeed,
            pageBrightness,
            reduceMotion: reduceMotion,
          )
        : appTheme;
    var background = paper ?? theme.colorScheme.surface;
    if (paper == null && page.tintPaper && seed != null) {
      // 纸张随基调染色：只在纸张为主题底色时，把一点种子色叠到底色上；
      // 深色主题下染色稍浓，保证看得出。
      final light = pageBrightness == Brightness.light;
      background = Color.alphaBlend(
        seed.withValues(alpha: light ? 0.06 : 0.10),
        background,
      );
    }

    final width = screenSize.width;
    final maxContentWidth = page.limitWidth ? page.contentWidth : null;
    final available = maxContentWidth == null
        ? width
        : math.min(width, maxContentWidth);
    final roomForPadding =
        (available - DiaryPreviewStyleLimits.minTextWidth) / 2;
    final horizontalPadding = math.max(
      0.0,
      math.min(page.horizontalPadding, roomForPadding),
    );

    return DiaryPreviewResolvedStyle._(
      style: style,
      theme: theme,
      themed: themed,
      background: background,
      // 正文与标题不再支持自定义颜色，一律用主题色。
      bodyColor: null,
      titleColor: null,
      horizontalPadding: horizontalPadding,
      maxContentWidth: maxContentWidth != null && maxContentWidth < width
          ? maxContentWidth
          : null,
      coverHeight: math.min(
        style.cover.height,
        screenSize.height * DiaryPreviewStyleLimits.coverMaxScreenFraction,
      ),
    );
  }

  final DiaryPreviewStyle style;

  /// 页面主题；[themed] 为 false 时就是应用主题本身。
  final ThemeData theme;
  final bool themed;

  /// 页面底色（纸色，或主题 surface）。
  final Color background;

  /// 正文颜色；始终为 null，表示用主题正文色。
  final Color? bodyColor;

  /// 标题颜色；始终为 null，表示用主题色。
  final Color? titleColor;

  /// 实际左右边距（窄屏上为正文留出至少
  /// [DiaryPreviewStyleLimits.minTextWidth]）。
  final double horizontalPadding;

  /// 正文最大宽度；不限制或屏幕本来就更窄时为 null。
  final double? maxContentWidth;

  /// 头图框高度（最高为屏高的
  /// [DiaryPreviewStyleLimits.coverMaxScreenFraction]）。
  final double coverHeight;

  /// 标题下分隔线的颜色：正文色按 [titleDividerOpacityLight] /
  /// [titleDividerOpacityDark] 降低不透明度。
  ///
  /// 为什么不直接用 `outlineVariant`：它是主题里的固定色调，落在自定义纸色
  /// （尤其是中间调的纸）上可能和纸几乎同色；正文色已经保证了与纸的对比度，
  /// 按比例淡化后在任何纸色、染过的纸、背景遮罩与玻璃上都“浅而可见”，色相
  /// 也跟着正文色走。半透明而不预先叠到 [background] 上：页面让位给
  /// 背景图时线下面并不是纸色。
  Color get titleDividerColor {
    final ink = bodyColor ?? theme.colorScheme.onSurface;
    return ink.withValues(
      alpha: theme.brightness == Brightness.light
          ? titleDividerOpacityLight
          : titleDividerOpacityDark,
    );
  }

  static Color? _paperColor(DiaryPreviewPageStyle page, Brightness brightness) {
    final light = brightness == Brightness.light;
    final preset = paperColors[page.paper];
    if (preset == null) {
      return null;
    }
    return Color(light ? preset.$1 : preset.$2);
  }

  static Color? _moodColor(String? moodEmoji, MoodPalette moodPalette) {
    return moodPalette.colorForSymbol(moodEmoji);
  }

  /// 着色强度：柔和去饱和并提亮（与改版前观感接近），原色不动，鲜明加饱和。
  static Color _applyIntensity(
    Color color,
    DiaryPreviewColorIntensity intensity,
  ) {
    switch (intensity) {
      case DiaryPreviewColorIntensity.original:
        return color;
      case DiaryPreviewColorIntensity.vivid:
        final hsl = HSLColor.fromColor(color);
        return hsl
            .withSaturation((hsl.saturation * 1.3).clamp(0.0, 1.0))
            .toColor();
      case DiaryPreviewColorIntensity.soft:
        final hsl = HSLColor.fromColor(color);
        return hsl
            .withSaturation(hsl.saturation * 0.45)
            .withLightness(
              (hsl.lightness + (1.0 - hsl.lightness) * 0.3).clamp(0.0, 1.0),
            )
            .toColor();
    }
  }
}
