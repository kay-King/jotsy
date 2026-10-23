import 'package:flutter/material.dart';

/// 首页悬浮新建按钮（自绘，去 MD3 化）：与底栏的并排新建钮
/// [HomeInlineCreateButton] 同一视觉语言——浅紫圆角方钮、深紫图标、
/// 一层柔和的定制投影。
///
/// 不用原装 FloatingActionButton：没有水波纹、没有 MD3 的状态层与
/// 抬升阴影动画；按压反馈是一次轻微缩放。尺寸与原 FAB 一致（56），
/// 外壳的几何关系不变；点击、长按提示与读屏语义与原按钮相同。
class HomeCreateFab extends StatefulWidget {
  const HomeCreateFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.child,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Widget child;

  /// 与原 FloatingActionButton 相同的边长。
  static const double dimension = 56;

  @override
  State<HomeCreateFab> createState() => _HomeCreateFabState();
}

class _HomeCreateFabState extends State<HomeCreateFab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(16));
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Tooltip(
        message: widget.tooltip,
        excludeFromSemantics: true,
        child: Listener(
          // 只观察按下状态做缩放反馈，不与 InkWell 抢手势。
          onPointerDown: (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: radius,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SizedBox.square(
                dimension: HomeCreateFab.dimension,
                child: Material(
                  color: scheme.primaryContainer,
                  shape: const RoundedRectangleBorder(borderRadius: radius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onPressed,
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    child: IconTheme(
                      data: IconThemeData(color: scheme.onPrimaryContainer),
                      child: Center(child: widget.child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
