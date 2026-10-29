import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../models/explore_view_data.dart';

/// 画廊里点视频打开的单页：复用日记正文里的 DiaryVideoPlayer（不新写播放器，
/// 全屏按钮也是它自带的）。下方“打开日记”带 diaryId 回画廊页，由画廊页打开
/// 这条视频所在的日记（与看图页长按“打开日记”同一条链路）。
class GalleryVideoPage extends StatelessWidget {
  const GalleryVideoPage({super.key, required this.item});

  final ExploreMediaItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = item.displayName?.trim().isNotEmpty == true
        ? item.displayName!.trim()
        : l10n.galleryFilterVideo;
    return Scaffold(
      appBar: AppTopBar(
        centerTitle: true,
        title: Text(title),
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DiaryVideoPlayer(
              video: DiaryFileAttachment(
                path: item.source,
                name: item.displayName,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(item.diaryId),
              child: Text(l10n.imageViewerOpenDiary),
            ),
          ],
        ),
      ),
    );
  }
}
