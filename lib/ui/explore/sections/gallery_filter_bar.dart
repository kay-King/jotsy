import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../models/explore_view_data.dart';

/// 媒体画廊顶部的分类筛选条：全部 / 图片 / 音频 / 视频。
///
/// Salt 单选组外观：一条浅灰轨道、选中段是轨道内浮起的白片（带一层柔和
/// 投影），未选段透明底、灰字；图标用 Material 描边（与 moodDiary 参考图
/// 同款的细线图标：网格 / 图片 / 音符 / 胶片）；窄屏下整条可横向滚动，
/// 不挤压标签。选择只改页面内存状态，不写设置键（与正倒序同理：只在本次
/// 打开内生效）。
///
/// 选中白片用 [AnimatedPositioned] 在轨道内平滑滑动到位（时长取
/// [ExpressiveMotion.medium]、曲线取 [ExpressiveMotion.effects]），而不是
/// 直接跳变；文字/图标颜色仍由按钮自身的隐式过渡（[ExpressiveMotion.fast]）
/// 做淡入淡出。
class GalleryFilterBar extends StatefulWidget {
  const GalleryFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final GalleryMediaFilter selected;
  final ValueChanged<GalleryMediaFilter> onSelected;

  @override
  State<GalleryFilterBar> createState() => _GalleryFilterBarState();
}

class _GalleryFilterBarState extends State<GalleryFilterBar> {
  final GlobalKey _stackKey = GlobalKey();

  /// 每段包一层透明 ColoredBox（自身就是 RenderObject，尺寸即按钮整盒），
  /// 量白片位置时用，不影响布局与外观。
  final Map<GalleryMediaFilter, GlobalKey> _segmentKeys = {
    for (final filter in GalleryMediaFilter.values) filter: GlobalKey(),
  };

  /// 白片在 Stack 坐标系里的几何；首帧测量完成前为 null，此时不画白片
  /// （首帧直接以最终值插入，不会闪跳）。
  double? _indicatorLeft;
  double? _indicatorTop;
  double? _indicatorWidth;
  double? _indicatorHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureIndicator());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 语言/主题变化会改变每段宽度，重量一次避免白片错位。
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureIndicator());
  }

  @override
  void didUpdateWidget(covariant GalleryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      // 等本帧布局完成后再量新选中段的位置，AnimatedPositioned 会从旧几何
      // 平滑滑到新几何；快速连点时中途改目标也能自然跟过去。
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureIndicator());
    }
  }

  void _measureIndicator() {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final segmentBox =
        _segmentKeys[widget.selected]?.currentContext?.findRenderObject()
            as RenderBox?;
    if (stackBox == null || segmentBox == null || !stackBox.hasSize) return;
    final offset = segmentBox.localToGlobal(Offset.zero, ancestor: stackBox);
    final size = segmentBox.size;
    if (_indicatorLeft == offset.dx &&
        _indicatorTop == offset.dy &&
        _indicatorWidth == size.width &&
        _indicatorHeight == size.height) {
      return;
    }
    setState(() {
      _indicatorLeft = offset.dx;
      _indicatorTop = offset.dy;
      _indicatorWidth = size.width;
      _indicatorHeight = size.height;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLight = colors.brightness == Brightness.light;
    // 轨道取中性浅灰，白片在浅色下为纯白、深色下为抬升一档的容器色
    // （与 ExpressiveButtonGroup 同口径）。
    final trackColor = isLight
        ? colors.surfaceContainerHigh
        : colors.surfaceContainerLow;
    final indicatorColor = isLight
        ? colors.surfaceContainerLowest
        : colors.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 8, AppSpacing.m, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Stack(
              key: _stackKey,
              children: [
                // 选中白片：画在按钮之下，只透出背景；几何变化时平滑滑动。
                if (_indicatorLeft != null &&
                    _indicatorTop != null &&
                    _indicatorWidth != null &&
                    _indicatorHeight != null)
                  AnimatedPositioned(
                    left: _indicatorLeft,
                    top: _indicatorTop,
                    width: _indicatorWidth,
                    height: _indicatorHeight,
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.medium,
                    ),
                    curve: ExpressiveMotion.effects,
                    child: Material(
                      color: indicatorColor,
                      elevation: 1,
                      shadowColor: const Color(0x24000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final filter in GalleryMediaFilter.values)
                      ColoredBox(
                        key: _segmentKeys[filter],
                        color: Colors.transparent,
                        child: _SegmentButton(
                          filter: filter,
                          selected: widget.selected == filter,
                          onTap: () => widget.onSelected(filter),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单段按钮：背景永远透明（白片由外层 AnimatedPositioned 单独绘制），只
/// 负责自身文字/图标颜色的隐式过渡与点击语义。
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final GalleryMediaFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final (icon, label) = switch (filter) {
      GalleryMediaFilter.all => (
        Icons.grid_view_outlined,
        l10n.galleryFilterAll,
      ),
      GalleryMediaFilter.image => (
        Icons.image_outlined,
        l10n.galleryFilterImage,
      ),
      GalleryMediaFilter.audio => (
        Icons.music_note_outlined,
        l10n.galleryFilterAudio,
      ),
      GalleryMediaFilter.video => (
        Icons.movie_outlined,
        l10n.galleryFilterVideo,
      ),
    };
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: FilledButton(
        onPressed: onTap,
        style: ButtonStyle(
          animationDuration: ExpressiveMotion.duration(
            context,
            ExpressiveMotion.fast,
          ),
          minimumSize: const WidgetStatePropertyAll(Size(48, 36)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return selected ? colors.onSurface : colors.onSurfaceVariant;
          }),
          // 状态层透明：按压不再有 MD3 的色调罩，只剩按钮自身动效。
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
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
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
