import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../app/theme/app_effects.dart';
import '../../widgets/long_image/long_image_cover_alignment.dart';
import '../../widgets/long_image/long_image_policy.dart';

/// 探索页通用卡片容器。
///
/// 提供 [onTap] 时整张卡可点：墨水画在卡片自身的 Material 上并按 24dp 圆角
/// 裁切。外包透明 Material + InkWell 的做法会被不透明的卡片表面盖住，按下去
/// 看不到任何反馈。
class ExploreCard extends StatelessWidget {
  const ExploreCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
        color: ExpressiveSurfaces.cardColor(colorScheme),
        clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: const EdgeInsets.all(18), child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: const EdgeInsets.all(18), child: child),
              ),
      ),
    );
  }
}

/// 探索页模块标题（彩色徽章图标 + 标题文案）。
class ExploreSectionTitle extends StatelessWidget {
  const ExploreSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  final FaIconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // mainAxisSize.min：标题行只占内容宽。默认的 max 会让它在父 Row
    // （媒体画廊卡标题行、日历区块标题行那种“标题 + Spacer + 尾部按钮”
    // 的结构）里把整行宽度都占走，尾部按钮再叠上去就横向溢出。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: FaIcon(
            icon,
            size: 13,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        // Flexible + ellipsis：标题放在有界宽度的父 Row 里（日历区块标题行
        // “月份 + Spacer + 完整日历”）时，月份名太长可以收起来而不是把
        // 整行顶溢出；平时标题短时和原来一样。
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// 顶部看板单项。
///
/// 数字在首次出现时从 0 递增到实际值（long + effects），之后数据变化时从当前值
/// 补间到新值，而不是每次重建都重播；等宽数字避免递增时宽度抖动，读屏只读
/// 最终值。减少动画时直接显示。
class ExploreStatTile extends StatelessWidget {
  const ExploreStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.format,
  });

  final FaIconData icon;
  final String label;
  final int value;

  /// 数字的写法（如千分位、“3 年 2 个月”）；递增过程中的每个中间值同样经它
  /// 格式化。null 时写整数。
  final String Function(int value)? format;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(icon, size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: format?.call(value) ?? '$value',
          child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.long,
              ),
              curve: ExpressiveMotion.effects,
              builder: (BuildContext context, double animated, Widget? _) {
                return Text(
                  format?.call(animated.round()) ?? '${animated.round()}',
                  // 格式化后的文字（“3 年 2 个月”）可能比纯数字长，窄屏下
                  // 收成一行省略，不把格子撑高。
                  maxLines: format == null ? null : 1,
                  overflow: format == null ? null : TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 媒体缩略图（支持本地与网络）。
class ExploreMediaThumb extends StatelessWidget {
  const ExploreMediaThumb({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String source;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final resolvedWidth = _resolveFiniteDimension(
          explicit: width,
          constrained: constraints.maxWidth,
        );
        final resolvedHeight = _resolveFiniteDimension(
          explicit: height,
          constrained: constraints.maxHeight,
        );
        final dpr = MediaQuery.devicePixelRatioOf(context);
        // 仅按缩略图容器长边给解码器一个缓存目标（另一边只给安全上限，按比例
        // 解码，长图不会被压扁），避免按容器宽高把图片缩进容器后再 cover 裁切
        // 发糊。实际填充仍交给 BoxFit.cover 裁切，长图顶部对齐。
        final cacheExtent = _cacheExtent(
          resolvedWidth >= resolvedHeight ? resolvedWidth : resolvedHeight,
          dpr,
        );
        final cacheWidth = resolvedWidth >= resolvedHeight ? cacheExtent : null;
        final cacheHeight = resolvedWidth < resolvedHeight ? cacheExtent : null;
        final uri = Uri.tryParse(source);
        final isRemote =
            uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        final image = CoverCroppedImage(
          image: boundedImageProvider(
            isRemote ? NetworkImage(source) : FileImage(File(source)),
            width: cacheWidth,
            height: cacheHeight,
          ),
          width: width,
          height: height,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: width,
            height: height,
            color: colorScheme.surfaceContainer,
            child: image,
          ),
        );
      },
    );
  }

  double _resolveFiniteDimension({
    required double explicit,
    required double constrained,
  }) {
    if (explicit.isFinite && explicit > 0) {
      return explicit;
    }
    if (constrained.isFinite && constrained > 0) {
      return constrained;
    }
    return 0;
  }

  int? _cacheExtent(double displayExtent, double devicePixelRatio) {
    if (!displayExtent.isFinite || displayExtent <= 0) {
      return null;
    }
    final effectiveRatio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 1.0;
    final extent = (displayExtent * effectiveRatio).round();
    return extent > 0 ? extent : null;
  }
}

/// 卡片内二级图表标题（标题 + 右侧灰色副标题）。
class ExploreChartTitle extends StatelessWidget {
  const ExploreChartTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        // 标题也要包 Flexible 收成一行省略：英文标题很长（实测
        // "Words per entry over the last 6 months" 524px），不包的话
        // 340 宽的卡片里直接溢出 192px（2026-10-25 首页测试）。
        // Flexible 先拿自己要的宽度，副标题拿剩下的，两边都不溢出。
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle!,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 统计行：左侧灰色标签，右侧数值（可带一行灰色注脚）。
class ExploreStatRow extends StatelessWidget {
  const ExploreStatRow({
    super.key,
    required this.label,
    required this.value,
    this.footnote,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final String? footnote;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      value,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (footnote != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        footnote!,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
      ],
    );
  }
}

/// 纵向柱状图（月度字数 / 写作时段共用）。
///
/// 每列自上而下：顶部数值 → 柱子（在浅色轨道里从底部长出）→ 底部标签。
/// [valueLabels] 为空时不画顶部数值；[topIndex] 指向分布里最高的一格，
/// [dimOthers] 为真时其余有值的柱子半透明（只突出最高格，见节奏图）。
class ExploreVerticalBars extends StatelessWidget {
  const ExploreVerticalBars({
    super.key,
    required this.values,
    required this.labels,
    required this.height,
    this.valueLabels,
    this.topIndex = -1,
    this.dimOthers = false,
  });

  final List<int> values;
  final List<String> labels;
  final double height;
  final List<String>? valueLabels;
  final int topIndex;
  final bool dimOthers;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    const labelHeight = 14.0;
    final trackHeight = height - labelHeight * 2;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: labelHeight,
                      child: OverflowBox(
                        // 窄列里文案 intrinsic 宽（两位数约 11px）会比列宽还大，
                        // 不给 Text 放宽约束的话段落会被压到列宽，第二位数字
                        // 画不出来（实测：24 列时 "12" 只剩 "1"）。
                        // OverflowBox 让文案按自身宽度排布、居中溢出，不裁剪。
                        maxWidth: 48,
                        alignment: Alignment.center,
                        child: Text(
                          valueLabels != null && i < valueLabels!.length
                              ? valueLabels![i]
                              : '',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: values[i] == 0
                            ? const SizedBox.shrink()
                            : Container(
                                height: (values[i] / maxValue * trackHeight)
                                    .clamp(2.0, trackHeight)
                                    .toDouble(),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: dimOthers && i != topIndex
                                        ? 0.55
                                        : 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(
                      height: labelHeight,
                      child: OverflowBox(
                        // 同上：窄列里两位数刻度（"12"/"15"……）需要比列宽
                        // 更大的排布宽度，否则第二位数字画不出来。
                        maxWidth: 48,
                        alignment: Alignment.center,
                        child: Text(
                          i < labels.length ? labels[i] : '',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 星期几的单字简称（热力图左侧与星期分布柱共用）。
///
/// [weekdayIndex] 按 0 为周日计。中文取 “周X” 的后一个字（一 / 二 …），
/// 英文取首字母（S / M …）；其余语言同样取短名的首字母。
String weekdayShortLabel(int weekdayIndex, String localeName) {
  // 2024-01-07 是周日，以它为基准推算任意星期几的短名。
  final name = DateFormat.E(
    localeName,
  ).format(DateTime.utc(2024, 1, 7 + weekdayIndex));
  if (localeName.startsWith('zh')) {
    return name.length > 1 ? name.substring(1) : name;
  }
  return name.isNotEmpty ? name.substring(0, 1) : name;
}
