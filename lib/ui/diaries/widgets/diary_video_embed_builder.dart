import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:video_player/video_player.dart';

/// 正文视频的 AppFlowy 块组件：注册到 `video` 类型节点的渲染器。
///
/// 数据解析与 UI 与 Quill 时代一致：节点 attributes（`url`）经
/// [DiaryFileAttachment] 解析后交给 [DiaryVideoPlayer] 渲染。
class DiaryVideoEmbedBuilder extends BlockComponentBuilder {
  DiaryVideoEmbedBuilder({
    this.playerFactory,
    this.exportService = const VideoExportService(),
  });

  final VideoPlayerController Function(String source)? playerFactory;
  final VideoExportService exportService;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryVideoBlockWidget(
      key: node.key,
      node: node,
      playerFactory: playerFactory,
      exportService: exportService,
    );
  }
}

class _DiaryVideoBlockWidget extends BlockComponentStatelessWidget {
  const _DiaryVideoBlockWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
    this.playerFactory,
    this.exportService = const VideoExportService(),
  });

  final VideoPlayerController Function(String source)? playerFactory;
  final VideoExportService exportService;

  @override
  Widget build(BuildContext context) {
    final video = DiaryFileAttachment.tryDecode(node.attributes);
    if (video == null) {
      return Text(
        context.l10n.videoPlaybackFailed,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryVideoPlayer(
      key: ValueKey(video.path),
      video: video,
      player: playerFactory?.call(video.path),
      exportService: exportService,
    );
  }
}
