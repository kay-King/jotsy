import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/explore_view_data.dart';

/// 画廊里音频 / 视频格：没有缩略图可画，用一张柔和底色的方格 + 图标 + 文字。
/// 图片格不走这里（仍是 ExploreMediaThumb + 看图页）。点按行为由调用方给
/// （音频开底部播放面板，视频开播放页），格子本身只负责长相与水波纹。
class GalleryMediaTile extends StatelessWidget {
  const GalleryMediaTile({
    super.key,
    required this.item,
    required this.radius,
    required this.onTap,
  });

  final ExploreMediaItem item;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final isAudio = item.kind == GalleryMediaKind.audio;
    // 音频名没有时用“录音”；视频名取数时已算好文件名，仍防空。
    final title = item.displayName?.trim().isNotEmpty == true
        ? item.displayName!.trim()
        : isAudio
        ? l10n.recordingAttachment
        : l10n.galleryFilterVideo;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  isAudio
                      ? Icons.music_note_outlined
                      : Icons.play_circle_outline,
                  size: 28,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (isAudio && item.duration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatDuration(item.duration!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

/// 时长只显示到秒（m:ss），与录音条的口径一致；超长按小时进位到分，不单独列小时。
String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
