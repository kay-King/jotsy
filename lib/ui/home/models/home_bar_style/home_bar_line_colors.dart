import 'package:flutter/material.dart';

import 'home_bar_line_style.dart';
import 'home_bar_style_enums.dart';
import 'home_bar_style_limits.dart';

/// 把 [HomeBarLineStyle] 落到当前主题下的颜色与粗细。纯函数、无副作用；
/// `HomeBarResolvedStyle` 用它解析两条线。
abstract final class HomeBarLineColors {
  /// 不透明的基础颜色（还没乘 [HomeBarLineStyle.opacity]）。
  ///
  /// - 跟随主题：outlineVariant，即改版前的细线；
  /// - 高光：玻璃边缘反光的亮色。浅色主题用最亮的表面色（接近白），深色
  ///   主题用 onSurface——深色下的“亮”是前景色，表面色反而是暗的；
  /// - 主题色：primary。
  static Color base(HomeBarLineStyle line, ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return switch (line.color) {
      HomeBarLineColor.theme => scheme.outlineVariant,
      HomeBarLineColor.highlight =>
        dark ? scheme.onSurface : scheme.surfaceContainerLowest,
      HomeBarLineColor.primary => scheme.primary,
    };
  }

  /// 最终颜色：[base] 乘上夹紧后的不透明度。
  static Color color(HomeBarLineStyle line, ColorScheme scheme) => base(
    line,
    scheme,
  ).withValues(alpha: HomeBarStyleLimits.lineOpacity.clamp(line.opacity));

  /// 夹紧后的粗细：直接构造（而非解码）的样式也可能越界。
  static double width(HomeBarLineStyle line) =>
      HomeBarStyleLimits.lineWidth.clamp(line.width);
}
