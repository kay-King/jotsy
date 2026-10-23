import 'package:flutter/material.dart';

/// 自绘开关（Salt 风，B 档去 MD3 化）：胶囊轨道 + 白色圆钮（带一层
/// 柔和投影），开 = 主色蓝、关 = 中性浅灰；圆钮滑动动画 180ms。
///
/// 与原装 Switch 的契约一致：[value] 受控、点按或横拖松手后经
/// [onChanged] 回报新值；[onChanged] 为 null 时是禁用态（整体变淡、
/// 不响应）。不画 MD3 开关的轨道描边、状态层与按钮内图标。
class SaltSwitch extends StatefulWidget {
  const SaltSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 轨道尺寸（比 SaltUI 的 40×22 略大，保证触达面积）。
  static const double trackWidth = 46;
  static const double trackHeight = 28;
  static const double thumbDiameter = 22;
  static const double _padding = (trackHeight - thumbDiameter) / 2;

  @override
  State<SaltSwitch> createState() => _SaltSwitchState();
}

class _SaltSwitchState extends State<SaltSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: widget.value ? 1 : 0,
  );

  /// 横拖中的临时位置（0..1），null 表示不在拖动。
  double? _dragPosition;

  @override
  void didUpdateWidget(SaltSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _dragPosition == null) {
      _controller.animateTo(widget.value ? 1 : 0, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _position => _dragPosition ?? _controller.value;

  void _toggle() {
    widget.onChanged?.call(!widget.value);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final travel =
        SaltSwitch.trackWidth -
        SaltSwitch.thumbDiameter -
        2 * SaltSwitch._padding;
    setState(() {
      _dragPosition =
          ((_dragPosition ?? _controller.value) + details.delta.dx / travel)
              .clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final target = _position >= 0.5;
    setState(() => _dragPosition = null);
    if (target != widget.value) {
      widget.onChanged?.call(target);
    }
    _controller.animateTo(target ? 1 : 0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null;
    final onColor = scheme.primary;
    final offColor = scheme.brightness == Brightness.light
        ? const Color(0xFFE3E5E8)
        : scheme.surfaceContainerHighest;
    final travel =
        SaltSwitch.trackWidth -
        SaltSwitch.thumbDiameter -
        2 * SaltSwitch._padding;
    return Semantics(
      toggled: widget.value,
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          onHorizontalDragUpdate: enabled ? _handleDragUpdate : null,
          onHorizontalDragEnd: enabled ? _handleDragEnd : null,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _position;
              return Container(
                width: SaltSwitch.trackWidth,
                height: SaltSwitch.trackHeight,
                decoration: BoxDecoration(
                  color: Color.lerp(offColor, onColor, t),
                  borderRadius: BorderRadius.circular(
                    SaltSwitch.trackHeight / 2,
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(SaltSwitch._padding + travel * t, 0),
                    child: Container(
                      width: SaltSwitch.thumbDiameter,
                      height: SaltSwitch.thumbDiameter,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
