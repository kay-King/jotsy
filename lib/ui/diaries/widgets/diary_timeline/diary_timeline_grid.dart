import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/image_viewer_page.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../diary_card/diary_card_cover.dart';

/// 时间线九宫格：正文图片（封面优先、去重，最多 9 张），朋友圈式排布。
///
/// - 1 张：180 圆角方块；2/4 张：2 列；其余：3 列；行内左对齐；
/// - 点按经 [openImageViewer] 打开看图页（共享元素飞入），不提供“打开日记”
///   （日记就在下面一层，见 image_viewer_page 的 onOpenDiary 约定）。
class DiaryTimelineGrid extends StatelessWidget {
  const DiaryTimelineGrid({
    super.key,
    required this.sources,
    required this.diaryId,
  });

  final List<String> sources;
  final String diaryId;

  static const int maxImages = 9;
  static const double _gap = 4;
  static const double _tileRadius = 4;
  static const double _singleTileSize = 180;

  Object _heroTag(String source) =>
      ImageViewerHeroTag('diary_timeline', '$diaryId::$source');

  @override
  Widget build(BuildContext context) {
    final images = sources.take(maxImages).toList(growable: false);
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = images.length;
        final columns = count == 1
            ? 1
            : (count == 2 || count == 4)
            ? 2
            : 3;
        final tile = count == 1
            ? math.min(_singleTileSize, width)
            : (width - _gap * (columns - 1)) / columns;
        final rows = <Widget>[];
        for (var start = 0; start < count; start += columns) {
          final rowItems = images.sublist(
            start,
            math.min(start + columns, count),
          );
          rows.add(
            Row(
              children: <Widget>[
                for (var i = 0; i < rowItems.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: _gap),
                  SizedBox(
                    width: tile,
                    height: tile,
                    child: _tile(context, rowItems[i], start + i, tile),
                  ),
                ],
              ],
            ),
          );
          if (start + columns < count) {
            rows.add(const SizedBox(height: _gap));
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }

  Widget _tile(BuildContext context, String source, int index, double tile) {
    final tag = _heroTag(source);
    return Builder(
      builder: (cellContext) => ImageViewerHeroSource(
        tag: tag,
        borderRadius: BorderRadius.circular(_tileRadius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(_tileRadius),
            onTap: () => openImageViewer(
              cellContext,
              items: <ImageViewerItem>[
                for (final itemSource in sources.take(maxImages))
                  ImageViewerItem(source: itemSource, diaryId: diaryId),
              ],
              initialIndex: index,
              hero: ImageViewerHero.capture(cellContext, tag: tag),
            ),
            child: DiaryCardCoverImage(
              source: source,
              width: tile,
              height: tile,
              radius: _tileRadius,
            ),
          ),
        ),
      ),
    );
  }
}
