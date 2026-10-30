import 'dart:convert';

const String diaryAudioEmbedType = 'audio';

/// Audio embeds store a managed file path, duration, optional display name,
/// and normalized waveform samples, never recognized text.
class DiaryAudioAttachment {
  const DiaryAudioAttachment({
    required this.path,
    required this.duration,
    this.name,
    this.waveform = const <double>[],
  });

  final String path;
  final Duration duration;
  final String? name;
  final List<double> waveform;

  DiaryAudioAttachment copyWith({
    String? path,
    Duration? duration,
    String? name,
    List<double>? waveform,
  }) {
    return DiaryAudioAttachment(
      path: path ?? this.path,
      duration: duration ?? this.duration,
      name: name ?? this.name,
      waveform: waveform ?? this.waveform,
    );
  }

  String encode() => jsonEncode(<String, Object?>{
    'path': path,
    'durationMs': duration.inMilliseconds,
    if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
    if (waveform.isNotEmpty)
      'waveform': waveform
          .map((w) => double.parse(w.toStringAsFixed(2)))
          .toList(),
  });

  static DiaryAudioAttachment? tryDecode(Object? data) {
    Object? value = data;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is! Map) return null;
    final pathValue = value['path'];
    if (pathValue is! String) return null;
    final path = pathValue.trim();
    if (path.isEmpty) return null;
    final milliseconds = value['durationMs'];
    final nameRaw = value['name'];
    final name = nameRaw is String && nameRaw.trim().isNotEmpty
        ? nameRaw.trim()
        : null;
    final waveformRaw = value['waveform'];
    final waveform = <double>[];
    if (waveformRaw is List) {
      for (final item in waveformRaw) {
        if (item is num && item.isFinite) {
          waveform.add(item.toDouble().clamp(0.0, 1.0));
        }
      }
    }
    return DiaryAudioAttachment(
      path: path,
      duration: Duration(
        milliseconds: milliseconds is num && milliseconds.isFinite
            ? milliseconds.toInt().clamp(0, 86400000)
            : 0,
      ),
      name: name,
      waveform: waveform,
    );
  }
}

/// 音频嵌入的编解码（Quill Delta 时代）。
///
/// 注意：[extractDiaryAudioPaths] 已迁移到
/// `diary_blocks/diary_blocks_media.dart`（块文档版本，兼容三代存储格式），
/// 这里不再保留旧版，避免与新版冲突。
