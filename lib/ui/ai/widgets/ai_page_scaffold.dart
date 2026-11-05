import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_top_bar.dart';
import 'ai_tap_outside_unfocus.dart';

/// AI 模块各二级页共用的外壳：`<` 返回、按表单宽度居中的滚动列表
/// （滚动视图铺满，留白在两侧）。
///
/// fork 适配（上游 9c985b05 用 `AppPageBackground` / `AppPageBackdrop` /
/// `FormWidth` / `AppBackgroundArea`，fork 没有背景与材质系统）：
/// - 页面底色直接用主题 surface（与 fork 其他设置子页一致）；
/// - 表单宽度 720 与两侧留白换算按上游 `FormWidth` 的算法就地实现
///  （`max(16, (可用宽 − 720) / 2) − 16`，手机上为 0，布局不变）；
/// - [area] 保留：对话、回顾等不在设置里的页面传 [AiPageArea.other]
///   （上游是 `AppBackgroundArea.other`，集成时按此名改）；目前不影响
///   绘制，背景系统合入 fork 后再接回。
enum AiPageArea {
  /// 设置区域（默认）。
  settings,

  /// 设置之外的 AI 页面（对话、回顾等）。
  other,
}

class AiPageScaffold extends StatelessWidget {
  const AiPageScaffold({
    super.key,
    required this.title,
    this.children = const <Widget>[],
    this.bodyBuilder,
    this.actions = const <Widget>[],
    this.area = AiPageArea.settings,
    this.floatingActionButton,
    this.onWillPopGuard,
  });

  final String title;
  final List<Widget> children;

  /// 自定义主体（如需要整页可拖动排序的列表）；给出时忽略 [children]。
  /// [padding] 是按表单宽度算好的内边距。
  final Widget Function(BuildContext context, EdgeInsets padding)? bodyBuilder;
  final List<Widget> actions;
  final AiPageArea area;
  final Widget? floatingActionButton;

  /// 返回前的拦截（如“放弃未保存的修改？”）；返回 true 才离开。
  final Future<bool> Function()? onWillPopGuard;

  /// 表单内容列的最大宽度（上游 `AppContentWidth.form`）。
  static const double contentMaxWidth = 720;

  @override
  Widget build(BuildContext context) {
    final guard = onWillPopGuard;
    Widget page = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: floatingActionButton,
      appBar: AppTopBar(
        title: Text(title),
        actions: actions,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 上游 FormWidth.extra：滚动视图两侧补的内边距；子项自带 16
          // 边距（SettingsCardGroup），手机上为 0。
          final side = math.max(
            0.0,
            (constraints.maxWidth - contentMaxWidth) / 2 - 16,
          );
          final padding = EdgeInsets.fromLTRB(side, 12, side, 32);
          final builder = bodyBuilder;
          if (builder != null) return builder(context, padding);
          return ListView(padding: padding, children: children);
        },
      ),
    );
    if (guard != null) {
      page = PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await guard()) navigator.pop(result);
        },
        child: page,
      );
    }
    // 点输入框以外的地方即收起键盘：设置页里的输入框多，手机上默认点外面
    // 不取消焦点，收起键盘后再点别的会把键盘带回来（见 AiTapOutsideUnfocus）。
    return AiTapOutsideUnfocus(child: page);
  }
}

/// 设置分组里通往下一级的一行：前置 16 的图标、标题、可选副标题、`>`。
class AiNavTile extends StatelessWidget {
  const AiNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final FaIconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleAlignment: ListTileTitleAlignment.center,
      leading: FaIcon(icon, size: 16, color: colors.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ?trailing,
          if (trailing != null) const SizedBox(width: 8),
          FaIcon(
            FontAwesomeIcons.angleRight,
            size: 14,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 行尾的小标记胶囊（“已停用”“已改写”等）。
class AiBadge extends StatelessWidget {
  const AiBadge(this.label, {super.key, this.error = false});

  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = error
        ? colors.onErrorContainer
        : colors.onSurfaceVariant;
    final background = error
        ? colors.errorContainer
        : colors.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// 页面内容卡片的统一外壳。
///
/// fork 适配：上游 `AppCardSurface` 的经典分支（fork 没有背景与材质系统，
/// 玻璃分支不存在），用 fork 自己的表面 token 复刻——圆角 + 描边 + 静止
/// 投影的 Container 套 Material，内容画在一层 Material 上、水波纹照常。
/// 注意 Container 会把描边宽度算进内边距，内容比外框内缩一个描边宽，
/// 不要“顺手”改成 `Material(shape: … side: …)`。
class AiCardSurface extends StatelessWidget {
  const AiCardSurface({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.card)),
    this.color,
    this.border,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
    this.padding,
    required this.child,
  });

  final BorderRadius borderRadius;

  /// 底色；默认 `ExpressiveSurfaces.cardColor`（亮色纯白）。
  final Color? color;

  /// 描边；默认 `ExpressiveSurfaces.cardBorderSide`，传
  /// [BorderSide.none] 不画。
  final BorderSide? border;

  /// 是否画投影：`AppEffects.restingCardShadow`（fork 扁平皮肤下为 null）。
  final bool shadow;

  final Clip clipBehavior;

  /// 内容的内边距（画在表面之内）。
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final side = border ?? ExpressiveSurfaces.cardBorderSide(scheme);
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        boxShadow: shadow ? AppEffects.restingCardShadow(scheme) : null,
      ),
      child: Material(
        color: color ?? ExpressiveSurfaces.cardColor(scheme),
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: content,
      ),
    );
  }
}
