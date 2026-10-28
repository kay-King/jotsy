import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/models/home_bar_style/home_bar_style.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/settings_reveal.dart';
import 'home_bar_style_common.dart';
import 'home_bar_style_labels.dart';

/// 材质页的“描边”分组（只在玻璃下出现，由材质页包在 Reveal 里）：底栏
/// 描边与顶栏分隔线两个开关，各自打开后展开颜色、不透明度与粗细。
///
/// 整个分组只有一项：分组按位置复用子项并在子项之间插分割线，若把有条件
/// 出现的顶栏分隔线作为单独的项，它收起时仍会留下一条分割线。所有有条件
/// 的行都放在位置固定的 [SettingsReveal] 槽里，下面的行不会因上面的行出现
/// 而错位复用、补播开关动画。
class HomeBarStyleOutlineGroup extends StatelessWidget {
  const HomeBarStyleOutlineGroup({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    return SettingsCardGroup(
      title: l10n.homeBarStyleOutlineGroup,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeBarStyleBorder,
              subtitle: l10n.homeBarStyleBorderSubtitle,
              value: style.border,
              onChanged: (bool v) =>
                  controller.commitWith((s) => s.copyWith(border: v)),
            ),
            SettingsReveal(
              visible: style.border,
              child: _LineOptions(
                controller: controller,
                line: style.borderLine,
                read: (s) => s.borderLine,
                write: (s, line) => s.copyWith(borderLine: line),
              ),
            ),
            // 顶栏分隔线只在“顶栏也用玻璃”打开时有意义（那个开关在上面的
            // 材质分组里），关掉时连同它的从属行一起收起。
            SettingsReveal(
              visible: style.glassTopBars,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SettingsCardGroupDivider(),
                  SettingsSwitchTile(
                    title: l10n.homeBarStyleTopBarHairline,
                    subtitle: l10n.homeBarStyleTopBarHairlineSubtitle,
                    value: style.topBarHairline,
                    onChanged: (bool v) => controller.commitWith(
                      (s) => s.copyWith(topBarHairline: v),
                    ),
                  ),
                  SettingsReveal(
                    visible: style.topBarHairline,
                    child: _LineOptions(
                      controller: controller,
                      line: style.topBarLine,
                      read: (s) => s.topBarLine,
                      write: (s, line) => s.copyWith(topBarLine: line),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 一条线的从属行：颜色来源、不透明度、粗细。
///
/// [read] / [write] 指向样式里的哪条线；滑块经 `homeBarSlider` 拖动中只改
/// 草稿、松手才写入，所以每次都从传入的最新样式里读出这条线再改。
class _LineOptions extends StatelessWidget {
  const _LineOptions({
    required this.controller,
    required this.line,
    required this.read,
    required this.write,
  });

  final HomeBarStyleEditorController controller;
  final HomeBarLineStyle line;
  final HomeBarLineStyle Function(HomeBarStyle style) read;
  final HomeBarStyle Function(HomeBarStyle style, HomeBarLineStyle line) write;

  HomeBarStyle _edit(
    HomeBarStyle style,
    HomeBarLineStyle Function(HomeBarLineStyle line) update,
  ) => write(style, update(read(style)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        settingsNestedDivider,
        SettingsChoiceTile(
          nested: true,
          title: l10n.homeBarStyleLineColor,
          child: ExpressiveButtonGroup<HomeBarLineColor>(
            minSegmentWidth: 72,
            segments: <ButtonSegment<HomeBarLineColor>>[
              for (final color in HomeBarLineColor.values)
                ButtonSegment<HomeBarLineColor>(
                  value: color,
                  label: Text(homeBarLineColorLabel(l10n, color)),
                ),
            ],
            selected: <HomeBarLineColor>{line.color},
            onSelectionChanged: (Set<HomeBarLineColor> v) =>
                controller.commitWith(
                  (s) => _edit(s, (l) => l.copyWith(color: v.single)),
                ),
          ),
        ),
        settingsNestedDivider,
        homeBarSlider(
          nested: true,
          controller: controller,
          title: l10n.homeBarStyleOpacity,
          range: HomeBarStyleLimits.lineOpacity,
          value: line.opacity,
          valueLabel: (double v) =>
              l10n.diaryCardStyleValuePercent('${(v * 100).round()}'),
          snap: (double v) => (v * 100).round() / 100,
          apply: (s, v) => _edit(s, (l) => l.copyWith(opacity: v)),
        ),
        settingsNestedDivider,
        homeBarSlider(
          nested: true,
          controller: controller,
          title: l10n.homeBarStyleLineWidth,
          range: HomeBarStyleLimits.lineWidth,
          value: line.width,
          valueLabel: (double v) =>
              l10n.diaryCardStyleValueDp(v.toStringAsFixed(1)),
          snap: (double v) => (v * 10).round() / 10,
          apply: (s, v) => _edit(s, (l) => l.copyWith(width: v)),
        ),
      ],
    );
  }
}
