import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 正文末尾为「更多」面板额外让出的空间，高度跟随 [extent]。
import 'package:node_diary/app/theme/expressive_motion.dart';

/// 正文末尾为「更多」面板额外让出的空间，高度跟随 [extent]。
///
/// 悬浮工具栏叠在正文之上，正文要靠末尾留白才能把最后几行滚到工具栏上方。
/// - 展开时立即让出：随后的光标揭示（[revealDiaryCaretAbove]）需要滚动范围
///   已经足够，留白若还在慢慢长高，滚动会顶到旧的边界提前停住；
/// - 收起时随面板同速缩回：留白一次性变短会把停在末尾的正文瞬间拉下来，而面板
///   这时还在收拢，看起来像整页跳了一下；逐帧缩短时正文跟着面板平滑落下。
class DiaryToolbarPanelReserve extends StatefulWidget {
  const DiaryToolbarPanelReserve({super.key, required this.extent});

  final ValueListenable<double> extent;

  @override
  State<DiaryToolbarPanelReserve> createState() =>
      _DiaryToolbarPanelReserveState();
}

class _DiaryToolbarPanelReserveState extends State<DiaryToolbarPanelReserve>
    with SingleTickerProviderStateMixin {
  late final AnimationController _height = AnimationController.unbounded(
    vsync: this,
    value: widget.extent.value,
  );

  @override
  void initState() {
    super.initState();
    widget.extent.addListener(_handleExtentChanged);
  }

  @override
  void didUpdateWidget(covariant DiaryToolbarPanelReserve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extent != widget.extent) {
      oldWidget.extent.removeListener(_handleExtentChanged);
      widget.extent.addListener(_handleExtentChanged);
      _height.value = widget.extent.value;
    }
  }

  @override
  void dispose() {
    widget.extent.removeListener(_handleExtentChanged);
    _height.dispose();
    super.dispose();
  }

  void _handleExtentChanged() {
    final target = widget.extent.value;
    if (target >= _height.value) {
      _height.value = target;
      return;
    }
    _height.animateTo(
      target,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.exit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _height,
      builder: (BuildContext context, Widget? child) =>
          SizedBox(height: _height.value),
    );
  }
}

/// 把正文里的光标滚到底部遮挡物上方。
///
/// 悬浮工具栏叠在正文之上，正文视口并不知道底部被遮住了多少。AppFlowy
/// 编辑器在选区变化时自己保证光标可见（这一点与 Quill 不同，不需要手动揭示），
/// 这里只需补偿底部浮层（悬浮工具栏 + 展开的面板）遮住的高度：经编辑器的滚动
/// 服务把内容再往上推 [coveredHeight]，看起来是面板把正文推了上去。编辑器
/// 尚未挂载滚动服务时什么也不做。
///
/// 注意：正文以不可滚动方式嵌在页面滚动容器里时（日记编辑页），光标跟随由
/// `DiaryCaretFollowController` 统一负责，见该控制器的 AppFlowy 迁移。
void revealDiaryCaretAbove(
  EditorState editorState, {
  required double coveredHeight,
  required Duration duration,
}) {
  final scrollService = editorState.service.scrollService;
  if (scrollService == null) {
    return;
  }
  scrollService.scrollTo(
    scrollService.dy + coveredHeight,
    duration: duration,
  );
}
