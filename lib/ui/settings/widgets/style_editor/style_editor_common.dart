import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/style_library/saved_style.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../controllers/style_draft_controller.dart';

// 样式编辑页（卡片样式、预览页样式、代码块样式）各标签页共用的外壳、预览
// 明暗按钮、撤销提示与命名对话框。

/// 预览明暗切换：只换预览的明暗（[StyleDraftController.
/// previewBrightness]），不改应用主题；图标显示点按后会切到的那一种。
///
/// Salt 悬浮风：白底圆 32、无边框、轻微阴影、图标 16，与顶栏其它按钮同式。
/// 三处共用：卡片页工具条、预览页工具条、代码块页顶栏操作。
class StylePreviewBrightnessButton extends StatelessWidget {
  const StylePreviewBrightnessButton({super.key, required this.controller});

  final StyleDraftController<Object?, Object?> controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brightness =
        controller.previewBrightness ?? Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    return SizedBox(
      width: 32,
      height: 32,
      child: DecoratedBox(
        // 与脚手架白圆按钮同式：白底圆 + 柔和阴影，不加描边（描边会让
        // 按钮发灰、显小气）。
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: isLight
                ? l10n.styleEditorPreviewDark
                : l10n.styleEditorPreviewLight,
            onPressed: () => controller.previewBrightness = isLight
                ? Brightness.dark
                : Brightness.light,
            icon: FaIcon(
              isLight ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
              size: 16,
            ),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

/// 标签页内容：分组卡片之间留 16 的竖向间距，底部让出系统手势区。
class StyleEditorTabList extends StatelessWidget {
  const StyleEditorTabList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // 被嵌进选项整页（[StyleEditorEmbeddedScope]）时：自己不再滚动，
    // 只按内容撑开、随外层一起滚；内外边距由整页的区块负责。
    // 被嵌进底部矮面板（compact）时：分组间距再收紧一档；面板里第一
    // 个分组还贴掉顶部留白（[StyleEditorFirstGroupScope]），面板标题
    // 与第一分组之间不空一大段。其它分组不动。
    final embedded = StyleEditorEmbeddedScope.of(context);
    final compact = StyleEditorEmbeddedScope.compactOf(context);
    final bottomInset = embedded ? 0.0 : MediaQuery.paddingOf(context).bottom;
    // 首个分组是否贴顶：没有包 scope 时默认 true（面板里的直接 tab）；
    // MergedTab 给非首个子 tab 包 false，免得拼起来的分类中间也被贴掉。
    final flushFirst = StyleEditorFirstGroupScope.maybeOf(context) ?? true;
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: embedded
          ? EdgeInsets.zero
          : EdgeInsets.fromLTRB(0, 16, 0, 24 + bottomInset),
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: compact ? 6 : 16),
          StyleEditorFirstGroupScope(
            flush: i == 0 && flushFirst,
            child: children[i],
          ),
        ],
      ],
    );
  }
}

/// 面板里第一个分组是否贴掉顶部留白（[SettingsCardGroup] 读它）。
///
/// 由 [StyleEditorTabList] 给每个孩子包一层：首个孩子继承外层值（没有
/// 外层时默认 true，即面板里的直接 tab），其余孩子一律 false；
/// [StyleEditorMergedTab] 给非首个子 tab 包 false，拼起来的分类中间
/// 不会被贴掉。只在 compact（底部矮面板）时生效，整页设置不受影响。
class StyleEditorFirstGroupScope extends InheritedWidget {
  const StyleEditorFirstGroupScope({
    super.key,
    required this.flush,
    required super.child,
  });

  final bool flush;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StyleEditorFirstGroupScope>()
          ?.flush ??
      false;

  static bool? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StyleEditorFirstGroupScope>()
      ?.flush;

  @override
  bool updateShouldNotify(StyleEditorFirstGroupScope oldWidget) =>
      flush != oldWidget.flush;
}

/// 两个或更多原标签页拼成一个分类：上下排列，分组间距与
/// [StyleEditorTabList] 一致（面板里 6、整页里 16）。
///
/// 只在面板与选项整页里用——两者都包 [StyleEditorEmbeddedScope]，各 tab
/// 在里面不自己滚动、按内容撑开，拼起来就是一个更长的分类；各 tab 的选项
/// 内容与回调一字不动。不要单独用在别处（没包 EmbeddedScope 时里面的
/// ListView 会高度无界）。
class StyleEditorMergedTab extends StatelessWidget {
  const StyleEditorMergedTab({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final compact = StyleEditorEmbeddedScope.compactOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: compact ? 6 : 16),
          // 只有第一个子 tab 的首分组可以贴顶（[StyleEditorFirstGroupScope]），
          // 其余子 tab 的首分组仍是普通分组间距，拼起来的分类中间不被贴掉。
          StyleEditorFirstGroupScope(flush: i == 0, child: children[i]),
        ],
      ],
    );
  }
}

/// 标记样式编辑的 tab 页被嵌进选项整页或底部矮面板：此时 [StyleEditorTabList]
/// 不再自己滚动，只按内容撑开、随外层一起滚。
///
/// 各 tab 页内部不改，整页/面板在外层包一层这个即可。
/// [compact] 为 true 时（底部矮面板）分组间距收紧一档。
class StyleEditorEmbeddedScope extends InheritedWidget {
  const StyleEditorEmbeddedScope({
    super.key,
    required super.child,
    this.compact = false,
  });

  final bool compact;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StyleEditorEmbeddedScope>() !=
      null;

  static bool compactOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StyleEditorEmbeddedScope>()
          ?.compact ??
      false;

  @override
  bool updateShouldNotify(StyleEditorEmbeddedScope oldWidget) =>
      compact != oldWidget.compact;
}

/// 阅读软件风药丸按钮组：离散选项用药丸，不用分段控件。与
/// [ExpressiveButtonGroup] 同一套 segments/selected/onSelectionChanged
/// 口径（单选或未选），样式 tab 直接替换即可；只改呈现、不改选项与回调。
///
/// 选中：Salt 蓝底白字；未选中：白底、深灰字、浅灰边。多个药丸自动换行
/// 排布。只借阅读软件的感觉，不照搬它的红色选中态。
class StylePillGroup<T> extends StatelessWidget {
  const StylePillGroup({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  }) : assert(segments.length > 0),
       assert(selected.length <= 1);

  final List<ButtonSegment<T>> segments;

  /// 当前选中（0 或 1 个）；预设未命中任何内置项时为空。
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final segment in segments)
          _StylePill<T>(
            segment: segment,
            selected: selected.contains(segment.value),
            onTap: onSelectionChanged == null || !segment.enabled
                ? null
                : () => onSelectionChanged!({segment.value}),
          ),
      ],
    );
  }
}

class _StylePill<T> extends StatelessWidget {
  const _StylePill({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final ButtonSegment<T> segment;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? Colors.white : scheme.onSurface;
    final enabled = segment.enabled && onTap != null;
    final pill = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: selected ? null : Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (segment.icon != null) ...<Widget>[
                  IconTheme(
                    data: IconThemeData(size: 14, color: foreground),
                    child: segment.icon!,
                  ),
                  const SizedBox(width: 4),
                ],
                // 用 merge 而不用新建 DefaultTextStyle：新建会盖掉上层
                // 的字族（测试里 CJK 注册在 Roboto 字族下），预设名会画
                // 成方框；merge 只改字号/字重/颜色，保留字族。
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: foreground,
                  ),
                  child: segment.label ?? const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      child: enabled ? pill : Opacity(opacity: 0.5, child: pill),
    );
  }
}

/// 阅读软件风数值行：标题与「— 滑杆 ＋ 数值」在一行。
///
/// 与 [SettingsSliderTile] 同样的回调口径：拖动中经 [onChanged] 即时
/// 预览，松手经 [onChangeEnd] 提交；取值按 [divisions] 吸附到步进。
/// 两端的 — ＋ 按一步进加减，点按即提交（先 [onChanged] 再
/// [onChangeEnd]，与滑块松手同一口径）。
class StyleSliderRow extends StatelessWidget {
  const StyleSliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    required this.onChangeEnd,
    this.subtitle,
    this.nested = false,
  });

  final String title;
  final String? subtitle;

  /// 是否为上一行的从属项：与 `SettingsSwitchTile.nested` 相同的缩进。
  final bool nested;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) valueLabel;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final clamped = value.clamp(min, max).toDouble();
    final step = divisions > 0 ? (max - min) / divisions : 0.0;
    final canChange = onChanged != null;
    void stepBy(double delta) {
      if (!canChange) {
        return;
      }
      final next = (clamped + delta).clamp(min, max).toDouble();
      onChanged!(next);
      onChangeEnd?.call(next);
    }

    final titleStyle =
        theme.listTileTheme.titleTextStyle ?? theme.textTheme.titleMedium;
    final titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: nested
          ? titleStyle?.merge(
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            )
          : titleStyle,
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        // 与 SettingsSwitchTile.nestedIndent 同值，避免再引一个文件。
        nested ? 40 : 16,
        8,
        16,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(flex: 2, child: titleWidget),
              const SizedBox(width: 4),
              _StepButton(
                icon: FontAwesomeIcons.minus,
                enabled: canChange && clamped > min,
                onPressed: () => stepBy(-step),
              ),
              Expanded(
                flex: 5,
                child: SliderTheme(
                  data: SliderTheme.of(
                    context,
                  ).copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
                  child: Slider(
                    value: clamped,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                    semanticFormatterCallback: valueLabel,
                  ),
                ),
              ),
              _StepButton(
                icon: FontAwesomeIcons.plus,
                enabled: canChange && clamped < max,
                onPressed: () => stepBy(step),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  valueLabel(clamped),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: theme.listTileTheme.subtitleTextStyle,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final FaIconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: FaIcon(icon, size: 14),
        style: IconButton.styleFrom(
          minimumSize: const Size(28, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// 可撤销的操作提示（套用、重置、导入、删除）。经
/// [HomeHintVisibilityScope.showTrackedSnackBar] 展示，`persist: false` 让它
/// 到时关闭（读屏等场景也一样），与日记列表的撤销提示一致。
Future<void> showStyleEditorUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) async {
  const duration = Duration(seconds: 4);
  var undone = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(message),
      duration: duration,
      persist: false,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () {
          undone = true;
        },
      ),
    ),
  );
  if (undone || reason == SnackBarClosedReason.action) {
    onUndo();
  }
}

/// 普通提示（复制成功、导入失败等）。
void showStyleEditorMessage(BuildContext context, String message) {
  HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(message)),
  );
}

/// 输入样式名称；取消或名字为空时返回 null。
Future<String?> showStyleEditorNameDialog(
  BuildContext context, {
  required String title,
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _StyleNameDialog(title: title, initialName: initialName),
  );
}

/// 命名对话框：TextField 的 controller 跟随对话框生命周期释放，关闭动画期间
/// 仍可能重建，不能在 showDialog 返回后立刻 dispose。
class _StyleNameDialog extends StatefulWidget {
  const _StyleNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_StyleNameDialog> createState() => _StyleNameDialogState();
}

class _StyleNameDialogState extends State<_StyleNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = SavedStyles.normalizeName(_controller.text);
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        contextMenuBuilder: appTextContextMenuBuilder,
        controller: _controller,
        autofocus: true,
        maxLength: SavedStyles.maxNameLength,
        decoration: InputDecoration(labelText: l10n.styleEditorNameLabel),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          onPressed: _submit,
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
