import 'package:flutter/material.dart';

import '../../app/theme/expressive_motion.dart';

/// 单选连接按钮组：输入选项/当前值，输出用户选择，不保存业务状态。
/// 利用原生按钮保留键盘、焦点与 disabled 行为；窄屏和大字体时改为纵向
/// 排列，避免固定横排挤掉标签。
///
/// 外观为 Salt 轨道式（B 档去 MD3 化）：一条浅灰轨道，选中段是轨道内
/// 浮起的白色圆角片（带一层柔和投影），未选段透明底、灰字；不用 MD3
/// 分段按钮的描边、选中勾与独立胶囊。
class ExpressiveButtonGroup<T> extends StatelessWidget {
  const ExpressiveButtonGroup({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.minSegmentWidth = 104,
    this.dense = false,
  }) : assert(segments.length > 0),
       assert(selected.length == 1);

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;

  /// 每段横排所需的最小宽度，放不下时改为纵向连接。默认按较长的标签估算；
  /// 标签很短（两三个字）时可调小，避免窄屏下无谓地堆成三行。
  final double minSegmentWidth;

  /// 紧凑横排：36dp 高、每段按标签自身宽度排列、始终不改为纵向，用于放进
  /// 固定高度的一行（如编辑器颜色面板的 40dp 表头）。宽度可能不够时由调用方
  /// 整体缩放（如 `FittedBox`），标签不省略。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLight = colors.brightness == Brightness.light;
    // 轨道取中性浅灰，选中片在浅色下为纯白、深色下为抬升一档的容器色。
    final trackColor = isLight
        ? colors.surfaceContainerHigh
        : colors.surfaceContainerLow;
    final selectedColor = isLight
        ? colors.surfaceContainerLowest
        : colors.surfaceContainerHighest;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            !dense &&
            (constraints.maxWidth < segments.length * minSegmentWidth ||
                MediaQuery.textScalerOf(context).scale(14) > 20);
        final children = <Widget>[];
        for (var index = 0; index < segments.length; index++) {
          final segment = segments[index];
          final isSelected = selected.contains(segment.value);
          final button = Semantics(
            selected: isSelected,
            inMutuallyExclusiveGroup: true,
            child: FilledButton(
              onPressed: onSelectionChanged != null && segment.enabled
                  ? () => onSelectionChanged!({segment.value})
                  : null,
              style: ButtonStyle(
                animationDuration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                minimumSize: WidgetStatePropertyAll(
                  dense ? const Size(48, 36) : const Size(48, 40),
                ),
                tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
                padding: WidgetStatePropertyAll(
                  dense
                      ? const EdgeInsets.symmetric(horizontal: 12)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return Colors.transparent;
                  }
                  return isSelected ? selectedColor : Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return null;
                  return isSelected
                      ? colors.onSurface
                      : colors.onSurfaceVariant;
                }),
                // 状态层透明：按压不再有 MD3 的色调罩，只剩按钮自身动效。
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                elevation: WidgetStatePropertyAll(isSelected ? 1 : 0),
                shadowColor: const WidgetStatePropertyAll(Color(0x24000000)),
                shape: const WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (segment.icon != null) ...[
                    segment.icon!,
                    const SizedBox(width: 8),
                  ],
                  // 紧凑横排的宽度不受限（按标签排列），不能用 Flexible。
                  if (segment.label != null)
                    dense ? segment.label! : Flexible(child: segment.label!),
                ],
              ),
            ),
          );
          children.add(stacked || dense ? button : Expanded(child: button));
        }
        final inner = stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              )
            : Row(
                mainAxisSize: dense ? MainAxisSize.min : MainAxisSize.max,
                children: children,
              );
        return FocusTraversalGroup(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(padding: const EdgeInsets.all(2), child: inner),
          ),
        );
      },
    );
  }
}
