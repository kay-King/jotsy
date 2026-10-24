import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';

/// 设置页统一分组卡片组件。
///
/// 职责：
/// - 将设置项收纳为现代 Grouped Inset Island 卡片；
/// - 消除全屏割裂式粗暴 Divider，内部项之间使用优雅微缩进分割线；
/// - 支持可选的分组标题与底部附注。
class SettingsCardGroup extends StatelessWidget {
  const SettingsCardGroup({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String? title;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            // Salt 风分组卡：只靠明度差分层在真机上几乎糊成一片
            // （用户 2026-10-24 反馈），改由浅描边勾形、投影压到几乎
            // 没有。暗色卡与底色差足够，不加投影。
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              // 浅描边勾出卡形（用户 2026-10-24：带一点浅浅的边框）；
              // 与日记卡共用同一支卡片边框色，明暗各一份低透明度。
              border: Border.all(
                color: ExpressiveSurfaces.cardBorderColor(colorScheme),
                width: 1,
              ),
              boxShadow: colorScheme.brightness == Brightness.light
                  ? const <BoxShadow>[
                      // 投影压到几乎没有（用户 2026-10-24）：分层主要靠
                      // 上面的浅描边，这里只留一丝浮感。
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: ExpressiveSurfaces.cardColor(colorScheme),
              borderRadius: BorderRadius.circular(AppRadii.card),
              clipBehavior: Clip.antiAlias,
              // 卡内上下留白，首尾行不贴卡边（照 IdeaMemo 分组卡的透气感）。
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 分组标题在卡内顶部（照 IdeaMemo 设置页）：蓝色小标题，
                    // 与下方第一行之间不画线，靠留白分层。
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          title!,
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1)
                        const SettingsCardGroupDivider(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                footer!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 分组卡片内两项之间的微缩进分割线。
///
/// [SettingsCardGroup] 在相邻子项之间自动插入；子项内部自带的从属行（如
/// 功能管理里日历下方的纪念日）也用它，与分组里的分割线一致，起点改为从属
/// 行的缩进（[indent]），让分割线与它下面的内容对齐。
class SettingsCardGroupDivider extends StatelessWidget {
  const SettingsCardGroupDivider({super.key, this.indent = 16});

  /// 起点缩进；右侧固定 16。
  final double indent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Salt 风分组内不画分割线（照 IdeaMemo 设置页），只保留 1px 的
    // 节奏间距。
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: 16),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: colorScheme.outlineVariant.withValues(alpha: 0),
      ),
    );
  }
}
