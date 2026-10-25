import 'dart:io';

import 'package:flutter/material.dart';

/// 简洁编辑器的图片九宫格：已选图片缩略图（右上角 × 可移除）+ 未满
/// [maxImages] 张时的“+”格子（满 9 张后“+”消失）。
///
/// 图片是选图时就拷进日记私有目录的稳定路径（草稿要引用它），不是
/// 相册原路径，所以这里只认路径字符串。
///
/// 这里用 Material 描边图标（用户定的方向：操作图标走 Material 描边，
/// 与顶栏图标一致；且预览字体里能正常渲染）。
class SimpleComposerImageGrid extends StatelessWidget {
  const SimpleComposerImageGrid({
    super.key,
    required this.imagePaths,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> imagePaths;
  final int maxImages;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cells = <Widget>[
      for (var i = 0; i < imagePaths.length; i++)
        _ImageCell(path: imagePaths[i], onRemove: () => onRemove(i)),
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
  const _ImageCell({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.expand(
            child: Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Icon(Icons.close, size: 14, color: colorScheme.onSurface),
            ),
          ),
        ),
      ],
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Icon(Icons.add, size: 28, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
