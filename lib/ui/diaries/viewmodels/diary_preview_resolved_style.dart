import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/seeded_theme_cache.dart';
import '../../../core/services/settings_service.dart';
import '../../widgets/mood_band_palette.dart';
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

  factory DiaryPreviewResolvedStyle.resolve({
    required DiaryPreviewStyle style,
    required ThemeData appTheme,
    required Color appSeed,
    required Size screenSize,
    required bool reduceMotion,
    required List<String> moodOptions,
    String? moodEmoji,
    int? firstTagColor,
  }) {
    final page = style.page;
    final appBrightness = appTheme.brightness;
    final paper = _paperColor(page, appBrightness);
    final pageBrightness = paper == null
        ? appBrightness
        : ThemeData.estimateBrightnessForColor(paper);
    final seed = switch (page.colorSeed) {
      DiaryPreviewColorSeed.app => null,
      DiaryPreviewColorSeed.mood => _moodColor(
        appTheme.colorScheme,
        moodEmoji,
        moodOptions,
      ),
      DiaryPreviewColorSeed.tag =>
        firstTagColor == null ? null : Color(firstTagColor),
    };
    final themed = seed != null || pageBrightness != appBrightness;
    final theme = themed
        ? SeededThemeCache.of(
            seed ?? appSeed,
            pageBrightness,
            reduceMotion: reduceMotion,
          )
        : appTheme;
    final background = paper ?? theme.colorScheme.surface;

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

  static Color? _paperColor(DiaryPreviewPageStyle page, Brightness brightness) {
    final light = brightness == Brightness.light;
    final preset = paperColors[page.paper];
    if (preset == null) {
      return null;
    }
    return Color(light ? preset.$1 : preset.$2);
  }

  static Color? _moodColor(
    ColorScheme scheme,
    String? moodEmoji,
    List<String> moodOptions,
  ) {
    final mood = moodEmoji?.trim();
    if (mood == null || mood.isEmpty) {
      return null;
    }
    final weight = SettingsService.buildMoodWeightMap(moodOptions)[mood];
    if (weight == null) {
      return null;
    }
    return MoodBandPalette.color(
      scheme,
      MoodBandPalette.bandForWeight(weight),
    ).withValues(alpha: 1);
  }
}
