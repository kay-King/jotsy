import 'package:flutter/material.dart';

import '../models/diary_code_block/diary_code_block_style.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import 'diary_text_appearance.dart';

// 代码块（与行内代码）在某个正文位置的可渲染形态：配色、字体、块容器的
// 排布数据与行内代码样式。
//
// 输入：代码块样式设置、正文外观、导入字体的字族名，以及正文位置的主题
// （取明暗与配色）。
// 输出：不可变的 [DiaryCodeBlockLook]，每次构建现算（配色有缓存，其余是
// 少量 TextStyle / BoxDecoration）。
// 副作用：无。
//
// 明暗分两套：代码块跟随设置（可固定深色），行内代码嵌在正文里，始终按
// 正文所在页面的明暗取色，否则浅色页面上的行内代码会变成一块块深色底。
//
// AppFlowy 迁移说明：原来这里直接装出 Quill 的 `DefaultTextBlockStyle` /
// `InlineCodeStyle` 交给 Quill 渲染；现在只输出纯 Flutter 数据
// （[DiaryCodeBlockContainerStyle] / [DiaryCodeInlineStyle]），由 AppFlowy
// 块组件与只读渲染各自取用，不再依赖 flutter_quill。

/// 代码块容器的排布数据：文字样式、上下外边距与装饰（底色、圆角、边框）。
///
/// 原来是 `quill.DefaultTextBlockStyle` 携带的信息；AppFlowy 时代块组件
/// 自己按这份数据排布（标题栏占上外边距，见 [DiaryCodeBlockLook.headerExtent]）。
@immutable
class DiaryCodeBlockContainerStyle {
  const DiaryCodeBlockContainerStyle({
    required this.textStyle,
    required this.topMargin,
    required this.bottomMargin,
    this.decoration,
  });

  /// 代码文字样式（字族、字号、行距与正文字色）。
  final TextStyle textStyle;

  /// 上外边距：块间距 + 标题栏高度（无标题栏时只有块间距）。
  final double topMargin;

  /// 下外边距：块间距。
  final double bottomMargin;

  /// 容器装饰：底色、圆角与边框（是否画边框、标题栏是否接上边，见解析逻辑）。
  final BoxDecoration? decoration;
}

/// 行内代码的样式：各字阶的文字样式、背景色与圆角。
///
/// 原来是 `quill.InlineCodeStyle` 携带的信息；字段名与原来一致，AppFlowy
/// 只读渲染直接取用。
@immutable
class DiaryCodeInlineStyle {
  const DiaryCodeInlineStyle({
    this.style,
    this.header1,
    this.header2,
    this.header3,
    this.backgroundColor,
    this.radius = DiaryCodeBlockLook.inlineRadius,
  });

  final TextStyle? style;
  final TextStyle? header1;
  final TextStyle? header2;
  final TextStyle? header3;
  final Color? backgroundColor;
  final Radius radius;
}

/// 代码块在正文位置解析出的外观。
@immutable
class DiaryCodeBlockLook {
  const DiaryCodeBlockLook._({
    required this.style,
    required this.palette,
    required this.inlinePalette,
    required this.codeTextStyle,
    required this.blockStyle,
    required this.inlineStyle,
  });

  /// 标题栏（语言名 + 复制）的高度；画在代码块上方的外边距里。
  static const double headerHeight = 32;

  /// 代码块与上下正文之间的间距。
  static const double blockGap = 8;

  /// 行内代码的圆角。
  static const Radius inlineRadius = Radius.circular(4);

  /// 原来 Quill 默认行内代码在 h1–h3 中的字号（`DefaultStyles.getInstance`），
  /// 再乘代码字号倍数。
  static const List<double> _inlineHeadingSizes = <double>[32, 22, 18];

  /// 按设置与正文位置的主题解析。[context] 必须在正文位置（预览页的纸张
  /// 主题之下），“跟随应用”的明暗才会跟着纸张走。
  static DiaryCodeBlockLook resolve(
    BuildContext context, {
    required DiaryCodeBlockStyle style,
    required DiaryTextAppearance appearance,
    String? importedFontFamily,
  }) {
    final theme = Theme.of(context);
    final appBrightness = theme.brightness;
    final brightness = switch (style.brightness) {
      DiaryCodeBrightness.system => appBrightness,
      DiaryCodeBrightness.light => Brightness.light,
      DiaryCodeBrightness.dark => Brightness.dark,
    };
    final palette = DiaryCodeThemes.palette(
      style.theme,
      brightness,
      theme.colorScheme,
    );
    final inlinePalette = DiaryCodeThemes.palette(
      style.theme,
      appBrightness,
      theme.colorScheme,
    );

    final mono = monospaceFamily(theme.platform);
    final family = switch (style.fontId) {
      kDiaryCodeFontMono => mono,
      // null = 沿用主题正文字体：TextStyle.merge 不覆盖行样式里的字族。
      kDiaryCodeFontBody => appearance.fontFamily,
      _ => importedFontFamily ?? mono,
    };
    // 等宽字体大多没有中文字形：缺字先回落正文字体（与周围正文同一套
    // 中文字形），再交给系统回退链。正文用主题字体时字族名为 null，取主题
    // 正文样式里的字族。
    final bodyFamily =
        appearance.fontFamily ?? theme.textTheme.bodyLarge?.fontFamily;
    final fallback = <String>[
      if (family != mono) mono,
      if (bodyFamily != null && bodyFamily != family) bodyFamily,
    ];

    final fontSize = appearance.typography.fontSize * style.fontScale;
    final codeTextStyle = TextStyle(
      color: palette.foreground,
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
      height: style.lineHeight,
      letterSpacing: 0,
    );

    final radius = Radius.circular(style.radius);
    final headerExtent = style.header ? headerHeight : 0.0;
    final borderSide = BorderSide(color: palette.border, width: 0.8);
    final blockStyle = DiaryCodeBlockContainerStyle(
      textStyle: codeTextStyle,
      // 上外边距里留出标题栏的位置（标题栏由代码块组件另画），装饰只画
      // 内容区，因此有标题栏时只有下边两个角是圆的，与标题栏拼成一整块；
      // 边框也只画左右下三边，上边由标题栏的边框接上，两者之间不画分隔线。
      topMargin: blockGap + headerExtent,
      bottomMargin: blockGap,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: style.header
            ? BorderRadius.vertical(bottom: radius)
            : BorderRadius.all(radius),
        border: !style.border
            ? null
            : style.header
            ? Border(left: borderSide, right: borderSide, bottom: borderSide)
            : Border.fromBorderSide(borderSide),
      ),
    );

    final inlineText = TextStyle(
      color: inlinePalette.inlineForeground,
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
    );
    TextStyle heading(int level) => inlineText.copyWith(
      fontSize: _inlineHeadingSizes[level] * style.fontScale,
      fontWeight: FontWeight.w500,
    );
    final inlineStyle = DiaryCodeInlineStyle(
      style: inlineText,
      header1: heading(0),
      header2: heading(1),
      header3: heading(2),
      backgroundColor: inlinePalette.inlineBackground,
    );

    return DiaryCodeBlockLook._(
      style: style,
      palette: palette,
      inlinePalette: inlinePalette,
      codeTextStyle: codeTextStyle,
      blockStyle: blockStyle,
      inlineStyle: inlineStyle,
    );
  }

  /// 平台的系统等宽字族。Android 上 `monospace` 由系统字体配置解析
  /// （Quill 默认的 `Roboto Mono` 在 Android 上并不存在）。
  static String monospaceFamily(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 'Menlo',
    TargetPlatform.windows => 'Consolas',
    TargetPlatform.android ||
    TargetPlatform.linux ||
    TargetPlatform.fuchsia => 'monospace',
  };

  final DiaryCodeBlockStyle style;

  /// 代码块配色（按设置的明暗）。
  final DiaryCodePalette palette;

  /// 行内代码配色（按正文所在页面的明暗）。
  final DiaryCodePalette inlinePalette;

  /// 代码块文字样式：字族、字号、行距与正文字色。
  final TextStyle codeTextStyle;

  /// 代码块容器的排布数据（外边距与装饰）。
  final DiaryCodeBlockContainerStyle blockStyle;

  /// 行内代码样式。
  final DiaryCodeInlineStyle inlineStyle;

  bool get lineNumbers => style.lineNumbers;

  bool get autoDetect => style.autoDetect;

  bool get header => style.header;

  /// 标题栏占用的上外边距；关闭标题栏时为 0。
  double get headerExtent => style.header ? headerHeight : 0;
}
