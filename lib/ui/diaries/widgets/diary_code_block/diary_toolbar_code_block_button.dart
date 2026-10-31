import 'dart:ui' show lerpDouble;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 悬浮工具栏上的「代码块」按钮。
///
/// - 输入：正文编辑器状态、面板是否正为它打开（[panelOpen]）、点按回调；
/// - 输出：只有 [onPressed]，转为代码块还是打开面板由工具栏决定；
/// - 外观与颜色按钮一致（32dp 可见、40dp 触控区、14dp 图标）：光标在代码块
///   里或面板为它打开时，经 [ExpressiveStateBlend] 过渡到已选中工具的
///   primaryContainer 小圆角方形。
///
/// 只在按钮内监听选区：光标进出代码块时只有按钮自己重建，不牵动整条工具栏。
class DiaryToolbarCodeBlockButton extends StatelessWidget {
  const DiaryToolbarCodeBlockButton({
    super.key,
    required this.editorState,
    required this.panelOpen,
    required this.tooltip,
    required this.onPressed,
  });

  final EditorState editorState;
  final bool panelOpen;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: editorState.selectionNotifier,
      builder: (BuildContext context, Widget? child) {
        final selected = panelOpen || diarySelectionInCodeBlock(editorState);
        return Semantics(
          selected: selected,
          child: ExpressiveStateBlend(
            active: selected,
            builder: (BuildContext context, double t, Widget? child) =>
                _buildButton(context, t),
          ),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, double t) {
    final colors = Theme.of(context).colorScheme;
    final foreground = Color.lerp(
      colors.onSurface,
      colors.onPrimaryContainer,
      t,
    )!;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: kDiaryToolbarButtonConstraints,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
          final pressed = states.contains(WidgetState.pressed);
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              pressed ? lerpDouble(12, 8, t)! : lerpDouble(16, 12, t)!,
            ),
          );
        }),
        backgroundColor: WidgetStatePropertyAll<Color>(
          colors.primaryContainer.withValues(alpha: t),
        ),
        foregroundColor: WidgetStatePropertyAll<Color>(foreground),
        iconColor: WidgetStatePropertyAll<Color>(foreground),
      ),
      icon: SizedBox.square(
        dimension: 32,
        child: Center(
          child: FaIcon(FontAwesomeIcons.fileCode, size: 14, color: foreground),
        ),
      ),
    );
  }
}
