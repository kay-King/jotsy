import 'package:flutter/material.dart';

/// 阴影策略：简约皮肤整体扁平，静止卡片不带投影、只靠底色与细边框分层；
/// 只有真正悬浮的面板保留一层很淡的投影，避免与页面完全贴死看不清边界。
class AppEffects {
  const AppEffects._();

  static List<BoxShadow> softShadow(ColorScheme colors) => [
    BoxShadow(
      color: colors.shadow.withValues(
        alpha: colors.brightness == Brightness.dark ? 0.24 : 0.08,
      ),
      offset: const Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// 静止态卡片（设置分组、日历面板、时间线条目、探索卡片）的投影。
  ///
  /// 扁平皮肤下恒为 null：卡片与页面底的区分交给表面灰阶与卡片细边框。
  static List<BoxShadow>? restingCardShadow(ColorScheme colors) => null;
}
