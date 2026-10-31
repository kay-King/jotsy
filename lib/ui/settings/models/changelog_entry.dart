import 'package:flutter/foundation.dart';

/// 一条版本更新记录。
///
/// [highlights] 是卡片上直接展示的版本要点；[details] 是点“展开全部”后看到
/// 的完整内容（Markdown 子集，由 `ReleaseNotesView` 渲染）。两种语言各存一份，
/// 按界面语言选择，中文为默认。
@immutable
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.highlightsZh,
    required this.highlightsEn,
    required this.detailsZh,
    required this.detailsEn,
  });

  /// 版本号，如 `v0.10.0`。
  final String version;

  final List<String> highlightsZh;
  final List<String> highlightsEn;
  final String detailsZh;
  final String detailsEn;

  List<String> highlightsFor(String languageCode) =>
      languageCode == 'en' ? highlightsEn : highlightsZh;

  String detailsFor(String languageCode) =>
      languageCode == 'en' ? detailsEn : detailsZh;
}
