import 'package:flutter/material.dart';

import '../../../core/services/diary_typography.dart';

/// 正文排版的可渲染形态：用户偏好 + 实际使用的字族名。
///
/// 内置字体显式解析为随包的 HarmonyOS Sans SC，与 UI 字体解耦：
/// UI 字体已改走系统字体（fork 的 Salt 风改造），但正文渲染不随之
/// 改变——既有日记的排版观感保持原样，用户想让正文跟随系统字体
/// 时可在字体设置里选「系统字体」。[fontFamily] 为 null 仅剩一种
/// 情况：导入字体尚未注册完成或文件缺失，正文先按主题字体显示。
@immutable
class DiaryTextAppearance {
  const DiaryTextAppearance({required this.typography, this.fontFamily});

  factory DiaryTextAppearance.resolve(
    DiaryTypography typography, {
    String? importedFontFamily,
    required TargetPlatform platform,
  }) {
    return DiaryTextAppearance(
      typography: typography,
      fontFamily: switch (typography.fontId) {
        DiaryTypography.bundledFontId => 'HarmonyOSSansSC',
        DiaryTypography.systemFontId => systemFontFamily(platform),
        _ => importedFontFamily,
      },
    );
  }

  final DiaryTypography typography;
  final String? fontFamily;

  /// 平台系统字体的字族名。Android 上 `sans-serif` 由系统字体配置解析（厂商
  /// 替换过系统字体的 ROM 会得到厂商字体），中文字形经系统回退链补齐；
  /// iOS / macOS 的 `CupertinoSystemText` 是引擎内置的系统字体别名。
  static String systemFontFamily(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => 'CupertinoSystemText',
    TargetPlatform.windows => 'Segoe UI',
    _ => 'sans-serif',
  };

  /// 标题只跟随字体：字号、字重仍由各页面的标题样式决定。
  TextStyle? titleStyle(TextStyle? base) {
    final family = fontFamily;
    if (base == null || family == null) {
      return base;
    }
    return base.copyWith(fontFamily: family);
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryTextAppearance &&
      other.typography == typography &&
      other.fontFamily == fontFamily;

  @override
  int get hashCode => Object.hash(typography, fontFamily);
}
