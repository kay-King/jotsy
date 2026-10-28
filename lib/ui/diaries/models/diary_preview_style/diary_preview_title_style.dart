part of 'diary_preview_style.dart';

/// 标题：显隐、“无标题”占位、字号缩放、字重与对齐。字体跟随正文字体
/// 设置（`DiaryTypography`），这里不另设。
@immutable
class DiaryPreviewTitleStyle {
  const DiaryPreviewTitleStyle({
    this.visible = true,
    this.showUntitled = true,
    this.scale = 1,
    this.weight = DiaryPreviewTitleWeight.heavy,
    this.align = DiaryPreviewAlign.start,
  });

  final bool visible;

  /// 没写标题时显示“无标题”；关闭后这类日记不显示标题行。
  final bool showUntitled;

  /// 相对 headlineSmall 的字号缩放。
  final double scale;
  final DiaryPreviewTitleWeight weight;
  final DiaryPreviewAlign align;

  DiaryPreviewTitleStyle copyWith({
    bool? visible,
    bool? showUntitled,
    double? scale,
    DiaryPreviewTitleWeight? weight,
    DiaryPreviewAlign? align,
  }) {
    return DiaryPreviewTitleStyle(
      visible: visible ?? this.visible,
      showUntitled: showUntitled ?? this.showUntitled,
      scale: scale ?? this.scale,
      weight: weight ?? this.weight,
      align: align ?? this.align,
    );
  }

  static DiaryPreviewTitleStyle _fromJson(Object? raw) {
    const d = DiaryPreviewTitleStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    return DiaryPreviewTitleStyle(
      visible: StyleJson.boolean(json['visible'], d.visible),
      showUntitled: StyleJson.boolean(json['showUntitled'], d.showUntitled),
      scale: StyleJson.number(
        json['scale'],
        d.scale,
        DiaryPreviewStyleLimits.titleScale,
      ),
      weight: StyleJson.enumByName(
        DiaryPreviewTitleWeight.values,
        json['weight'],
        d.weight,
      ),
      align: StyleJson.enumByName(
        DiaryPreviewAlign.values,
        json['align'],
        d.align,
      ),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewTitleStyle();
    final json = <String, Object>{};
    StyleJson.put(json, 'visible', visible, d.visible);
    StyleJson.put(json, 'showUntitled', showUntitled, d.showUntitled);
    StyleJson.put(json, 'scale', scale, d.scale);
    StyleJson.putEnum(json, 'weight', weight, d.weight);
    StyleJson.putEnum(json, 'align', align, d.align);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewTitleStyle &&
        other.visible == visible &&
        other.showUntitled == showUntitled &&
        other.scale == scale &&
        other.weight == weight &&
        other.align == align;
  }

  @override
  int get hashCode => Object.hash(visible, showUntitled, scale, weight, align);
}
