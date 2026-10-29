import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_button_group.dart';
import '../models/explore_view_data.dart';

/// 媒体画廊顶部的分类筛选条：全部 / 图片 / 音频 / 视频。
///
/// Salt 单选组（复用 ExpressiveButtonGroup 紧凑横排）：一条浅灰轨道、选中段
/// 是轨道内浮起的白片，不用 MD3 分段按钮的描边与选中勾。图标用 Material
/// 描边（与 moodDiary 参考图同款的细线图标：网格 / 图片 / 音符 / 胶片）；
/// 窄屏下整条可横向滚动，不挤压标签。选择只改页面内存状态，不写设置键
/// （与正倒序同理：只在本次打开内生效）。
class GalleryFilterBar extends StatelessWidget {
  const GalleryFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final GalleryMediaFilter selected;
  final ValueChanged<GalleryMediaFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 8, AppSpacing.m, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ExpressiveButtonGroup<GalleryMediaFilter>(
          dense: true,
          segments: <ButtonSegment<GalleryMediaFilter>>[
            ButtonSegment<GalleryMediaFilter>(
              value: GalleryMediaFilter.all,
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(l10n.galleryFilterAll),
            ),
            ButtonSegment<GalleryMediaFilter>(
              value: GalleryMediaFilter.image,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(l10n.galleryFilterImage),
            ),
            ButtonSegment<GalleryMediaFilter>(
              value: GalleryMediaFilter.audio,
              icon: const Icon(Icons.music_note_outlined, size: 18),
              label: Text(l10n.galleryFilterAudio),
            ),
            ButtonSegment<GalleryMediaFilter>(
              value: GalleryMediaFilter.video,
              icon: const Icon(Icons.movie_outlined, size: 18),
              label: Text(l10n.galleryFilterVideo),
            ),
          ],
          selected: <GalleryMediaFilter>{selected},
          onSelectionChanged: (selected) => onSelected(selected.single),
        ),
      ),
    );
  }
}
