import 'package:flutter/material.dart';

import 'expressive_motion.dart';

/// 控件形状与状态的集中定义，保留焦点、键盘、禁用态和语义树。
/// 简约皮肤下按钮用固定小圆角，不再有 MD3 按压时圆角变形的胶囊形态；
/// 不覆盖按钮的语义颜色：tonal、危险操作和第三方编辑器仍可使用自己的色彩角色。
abstract final class ExpressiveControls {
  static final shape = WidgetStateProperty.resolveWith<OutlinedBorder>((
    states,
  ) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  });

  static ButtonStyle button(TextTheme text) => ButtonStyle(
    // 简约皮肤：按钮收紧到 40 高、横向 18 内边距，不用 MD3 的 48 高大块按钮。
    minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    ),
    shape: shape,
    textStyle: WidgetStatePropertyAll(text.labelLarge),
    animationDuration: ExpressiveMotion.fast,
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  static ThemeData apply(ThemeData theme) {
    final colors = theme.colorScheme;
    final style = button(theme.textTheme);
    final textStyle = style.copyWith(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      // 文字按钮（对话框操作、导航绿字按钮）照参考项目用 15–16 档字号，
      // 不跟填充按钮共用 13 的标签字号。
      textStyle: WidgetStatePropertyAll(theme.textTheme.titleMedium),
    );
    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(style: style),
      elevatedButtonTheme: ElevatedButtonThemeData(style: style),
      outlinedButtonTheme: OutlinedButtonThemeData(style: style),
      textButtonTheme: TextButtonThemeData(style: textStyle),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: shape,
          animationDuration: ExpressiveMotion.fast,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // 主操作按钮用实心主色（默认即微信绿）+ 白字，不用 MD3 的浅色容器底。
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        focusElevation: 1,
        hoverElevation: 2,
        highlightElevation: 0,
        // 圆形悬浮按钮（照参考项目）：主色圆钮 + 白图标，不用胶囊形。
        shape: const CircleBorder(),
        extendedTextStyle: theme.textTheme.titleMedium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(style: style),
      // 滑杆回到常规细轨 + 圆形滑块，不用 MD3 的断轨与竖柄造型。
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
        valueIndicatorColor: colors.inverseSurface,
        valueIndicatorTextStyle: theme.textTheme.labelLarge?.copyWith(
          color: colors.onInverseSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        // 未选为浅灰填充（与参考项目的 --fill 一致）；选中按参考项目工具条
        // 标签的做法用实心主色 + 白字，是少数允许强调色大面积出现的位置。
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primary,
        disabledColor: colors.onSurface.withValues(alpha: 0.12),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
        ),
        secondaryLabelStyle: theme.textTheme.labelLarge?.copyWith(
          color: colors.onPrimary,
        ),
        checkmarkColor: colors.onPrimary,
        side: BorderSide.none,
        // 小芯片照参考项目工具条标签：圆角 14 的小胶囊（与大按钮的方角区分）。
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      // 开关按微信/iOS 观感：选中实心主色、未选浅灰轨、白圆钮、无描边。
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.secondaryContainer,
        circularTrackColor: colors.secondaryContainer,
        // 细直条，不用 MD3 的粗轨 + 断口造型。
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(2),
        trackGap: 0,
      ),
    );
  }

  /// ThemeData 没有 BuildContext；在应用 builder 中补上系统减少动画偏好，
  /// 而不是停掉整棵树的 ticker（那会连输入光标和业务动画一起冻结）。
  static ThemeData withoutMotion(ThemeData theme) {
    ButtonStyle stop(ButtonStyle? style) => (style ?? const ButtonStyle())
        .copyWith(animationDuration: Duration.zero);
    return theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: stop(theme.filledButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: stop(theme.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: stop(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: stop(theme.textButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: stop(theme.iconButtonTheme.style),
      ),
      // 框架默认转场（Android 预测性返回、iOS 侧滑）不读取 disableAnimations；
      // 减少动画时所有平台的 MaterialPageRoute 直接切换页面。
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final platform in TargetPlatform.values)
            platform: const _NoMotionPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 减少动画模式下的页面转场：不做任何位移/缩放/淡入，直接显示目标页。
class _NoMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoMotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
