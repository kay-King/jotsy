import 'dart:io';

import 'package:flutter/material.dart';

/// 简洁编辑器的图片九宫格：已选图片缩略图 + 未满 [maxImages] 张时的
/// “+”格子（满 9 张后“+”消失）。
///
/// 图片是选图时就拷进日记私有目录的稳定路径（草稿要引用它），不是
/// 相册原路径，所以这里只认路径字符串。
///
/// 点图片进大图预览（[onPreview]），长按删图（[onRemove]）：× 按钮
/// 已去掉，删图只走长按，和朋友圈编辑页的交互一致。
///
/// 这里用 Material 描边图标（用户定的方向：操作图标走 Material 描边，
/// 与顶栏图标一致；且预览字体里能正常渲染）。
class SimpleComposerImageGrid extends StatelessWidget {
  const SimpleComposerImageGrid({
    super.key,
    required this.imagePaths,
    required this.maxImages,
    required this.onAdd,
    required this.onPreview,
    required this.onRemove,
  });

  final List<String> imagePaths;
  final int maxImages;
  final VoidCallback onAdd;
  final void Function(int index) onPreview;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cells = <Widget>[
      for (var i = 0; i < imagePaths.length; i++)
        _ImageCell(
          path: imagePaths[i],
          onTap: () => onPreview(i),
          onLongPress: () => onRemove(i),
        ),
      if (imagePaths.length < maxImages)
        _AddCell(onTap: onAdd, colorScheme: colorScheme),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: cells,
    );
  }
}

class _ImageCell extends StatelessWidget {
  const _ImageCell({
    required this.path,
    required this.onTap,
    required this.onLongPress,
  });

  final String path;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.expand(
          child: Image.file(File(path), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _AddCell extends StatelessWidget {
  const _AddCell({required this.onTap, required this.colorScheme});

  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        // 朋友圈编辑页的“+”格子是虚线框（实线框看着像个按钮，太生硬）。
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: colorScheme.outlineVariant,
            radius: 8,
          ),
          child: Icon(Icons.add, size: 28, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// 虚线圆角框：按边长切分画短线段，圆角处用圆弧逼近。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    // 沿圆角矩形路径按虚线分段画：取路径长度，分段取点连线。
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final total = metrics.length;
    var distance = 0.0;
    while (distance < total) {
      final end = (distance + _dash).clamp(0.0, total);
      canvas.drawPath(metrics.extractPath(distance, end), paint);
      distance = end + _gap;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
