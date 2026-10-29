import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/database/audio_embed_codec.dart';
import '../../../core/database/file_embed_codec.dart';
import '../models/explore_view_data.dart';

/// 提取器找到的一条媒体：类型 + 可播 / 可看的路径 + 展示信息。
/// 音频的展示名与时长取自正文音频节点（没有时为空）；视频的展示名是文件名；
/// 图片只有路径，格子里不画文字。
typedef ExploreMediaSource = ({
  GalleryMediaKind kind,
  String source,
  String? displayName,
  Duration? duration,
});

/// 探索页内容提取器。
///
/// 职责边界：
/// - 解析 metadata.context；
/// - 提供摘要文案与媒体资源提取；
/// - 不参与任何统计聚合逻辑。
class ExploreContentExtractor {
  const ExploreContentExtractor();

  Map<String, dynamic>? parseContext(String metadata) {
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final context = decoded['context'];
      if (context is! Map<String, dynamic>) {
        return null;
      }
      return context;
    } catch (_) {
      return null;
    }
  }

  String summaryFromText(
    String contentText, {
    String emptyFallback = 'Recorded an entry',
  }) {
    final text = contentText.replaceAll('\n', ' ').trim();
    if (text.isNotEmpty) {
      return text;
    }
    return emptyFallback;
  }

  String summaryText(
    Diary diary, {
    String emptyFallback = 'Recorded an entry',
  }) {
    return summaryFromText(diary.contentText, emptyFallback: emptyFallback);
  }

  String? resolveOverviewMediaSource(ExploreDiaryOverview overview) {
    final cover = overview.cover?.trim();
    if (cover != null && cover.isNotEmpty) {
      return cover;
    }
    return null;
  }

  /// 封面优先，随后按正文顺序收集全部媒体（图片 / 音频 / 视频）；
  /// 同一来源只保留第一次出现的类型（封面永远算图片）。
  List<ExploreMediaSource> resolveTypedMediaSources(Diary diary) =>
      resolveTypedMediaSourcesFrom(cover: diary.cover, content: diary.content);

  /// 同 [resolveTypedMediaSources]，输入为封面与正文原文（不必持有整篇日记）。
  List<ExploreMediaSource> resolveTypedMediaSourcesFrom({
    required String? cover,
    required String content,
  }) {
    final found = <String, ExploreMediaSource>{};
    final trimmedCover = cover?.trim();
    if (trimmedCover != null && trimmedCover.isNotEmpty) {
      found[trimmedCover] = (
        kind: GalleryMediaKind.image,
        source: trimmedCover,
        displayName: null,
        duration: null,
      );
    }
    final raw = content.trim();
    if (raw.isNotEmpty) {
      try {
        _collectMediaFromNode(jsonDecode(raw), found);
      } on FormatException {
        // 旧记录可能保存纯文本或损坏的 JSON，正文解析失败仍保留独立封面。
      }
    }
    return found.values.toList(growable: false);
  }

  /// 封面优先，随后按正文顺序收集全部图片；同一来源只保留一次。
  /// 日记本统计与探索概览只认图片，走这里（不改它们的口径）。
  List<String> resolveMediaSources(Diary diary) =>
      resolveMediaSourcesFrom(cover: diary.cover, content: diary.content);

  /// 同 [resolveMediaSources]，输入为封面与正文原文（不必持有整篇日记，
  /// 如日记本统计页只查这两列）。
  List<String> resolveMediaSourcesFrom({
    required String? cover,
    required String content,
  }) {
    return resolveTypedMediaSourcesFrom(cover: cover, content: content)
        .where((media) => media.kind == GalleryMediaKind.image)
        .map((media) => media.source)
        .toList(growable: false);
  }

  void _collectMediaFromNode(
    Object? node,
    Map<String, ExploreMediaSource> found,
  ) {
    if (node is List) {
      for (final item in node) {
        _collectMediaFromNode(item, found);
      }
      return;
    }
    if (node is! Map) {
      return;
    }

    final insert = node['insert'];
    if (insert is Map) {
      final image = insert['image'];
      if (image is String && image.trim().isNotEmpty) {
        final source = image.trim();
        found.putIfAbsent(
          source,
          () => (
            kind: GalleryMediaKind.image,
            source: source,
            displayName: null,
            duration: null,
          ),
        );
      }
      // 标准 Quill 视频直接存路径字符串；文件附件式视频存 JSON（path/url），
      // 都经 DiaryFileAttachment 认出来，只取路径，名字后算。
      final video = insert['video'];
      if (video != null) {
        final attachment = DiaryFileAttachment.tryDecode(video);
        if (attachment != null) {
          final source = attachment.path;
          found.putIfAbsent(
            source,
            () => (
              kind: GalleryMediaKind.video,
              source: source,
              displayName: attachment.displayName,
              duration: null,
            ),
          );
        }
      }
      // 自定义音频嵌入的数据是再编码一层的 JSON 字符串（path/durationMs/
      // name/waveform），经 DiaryAudioAttachment 解出路径、名字与时长。
      final audio = insert['audio'];
      if (audio != null) {
        final attachment = DiaryAudioAttachment.tryDecode(audio);
        if (attachment != null) {
          final source = attachment.path;
          found.putIfAbsent(
            source,
            () => (
              kind: GalleryMediaKind.audio,
              source: source,
              displayName: attachment.name,
              duration: attachment.duration,
            ),
          );
        }
      }
    }

    // 旧版 AppFlowy 的嵌套节点：type + attributes.url，图片与视频都认。
    final type = node['type'];
    if (type == 'image' || type == 'video') {
      final attributes = node['attributes'];
      if (attributes is Map) {
        final url = attributes['url'];
        if (url is String && url.trim().isNotEmpty) {
          final source = url.trim();
          final kind = type == 'video'
              ? GalleryMediaKind.video
              : GalleryMediaKind.image;
          found.putIfAbsent(
            source,
            () => (
              kind: kind,
              source: source,
              displayName: kind == GalleryMediaKind.video
                  ? DiaryFileAttachment(path: source).displayName
                  : null,
              duration: null,
            ),
          );
        }
      }
    }

    // 同时兼容 Quill Delta 和旧版 AppFlowy 的嵌套节点。
    _collectMediaFromNode(node['children'], found);
    _collectMediaFromNode(node['root'], found);
  }
}
