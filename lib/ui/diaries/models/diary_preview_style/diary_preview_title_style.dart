part of 'diary_preview_style.dart';

/// 标题：显隐、“无标题”占位、字号缩放、字重与对齐，以及标题区与正文
/// 之间的分隔线和距离。字体跟随正文字体设置（`DiaryTypography`），这里不另设。
@immutable
class DiaryPreviewTitleStyle {
  const DiaryPreviewTitleStyle({
    this.visible = true,
    this.showUntitled = true,
    this.scale = 1,
    this.weight = DiaryPreviewTitleWeight.heavy,
    this.align = DiaryPreviewAlign.start,
    this.divider = false,
    this.bodyGap = defaultBodyGap,
  });

  /// 标题区与正文之间的默认距离：改版前正文区固定的上边距。没有标题区（无
  /// 标题且信息栏不在标题旁）时正文区始终用它，不受 [bodyGap] 影响。
  static const double defaultBodyGap = 14;

  final bool visible;

  /// 没写标题时显示“无标题”；关闭后这类日记不显示标题行。
  final bool showUntitled;

  /// 相对 headlineSmall 的字号缩放。
  final double scale;
  final DiaryPreviewTitleWeight weight;
  final DiaryPreviewAlign align;

  /// 在标题区与正文之间画一条浅色细线（默认关，即改版前）。
  final bool divider;

  /// 标题区下缘到正文的距离；开启 [divider] 时线上、线下各留这么多。范围见
  /// [DiaryPreviewStyleLimits.titleBodyGap]。
  final double bodyGap;

  DiaryPreviewTitleStyle copyWith({
    bool? visible,
    bool? showUntitled,
    double? scale,
    DiaryPreviewTitleWeight? weight,
    DiaryPreviewAlign? align,
    bool? divider,
    double? bodyGap,
  }) {
    return DiaryPreviewTitleStyle(
      visible: visible ?? this.visible,
      showUntitled: showUntitled ?? this.showUntitled,
      scale: scale ?? this.scale,
      weight: weight ?? this.weight,
      align: align ?? this.align,
      divider: divider ?? this.divider,
      bodyGap: bodyGap ?? this.bodyGap,
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
      divider: StyleJson.boolean(json['divider'], d.divider),
      bodyGap: StyleJson.number(
        json['bodyGap'],
        d.bodyGap,
        DiaryPreviewStyleLimits.titleBodyGap,
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
    StyleJson.put(json, 'divider', divider, d.divider);
    StyleJson.put(json, 'bodyGap', bodyGap, d.bodyGap);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewTitleStyle &&
        other.visible == visible &&
        other.showUntitled == showUntitled &&
        other.scale == scale &&
        other.weight == weight &&
        other.align == align &&
        other.divider == divider &&
        other.bodyGap == bodyGap;
  }

  @override
  int get hashCode =>
      Object.hash(visible, showUntitled, scale, weight, align, divider, bodyGap);
}
