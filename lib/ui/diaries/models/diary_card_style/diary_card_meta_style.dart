part of 'diary_card_style.dart';

/// 卡片上的日期、时间与附加信息（心情、天气、地点、精力、字数、媒体）。
/// 两种布局共用；心情与天气放在哪由各模式的 `metaPosition` 决定。
@immutable
class DiaryCardMetaStyle {
  const DiaryCardMetaStyle({
    this.showDate = true,
    this.dateFormat = DiaryCardDateFormat.eyebrow,
    this.showWeekday = true,
    this.showTime = false,
    this.dateSource = DiaryCardDateSource.created,
    this.footerTime = DiaryCardFooterTime.relativeUpdated,
    this.bigDate = false,
    this.inlineDate = false,
    this.mediaBadge = false,
    this.dateAccent = const DiaryCardColorSpec(),
    this.showMood = true,
    this.showWeather = true,
    this.indicatorStyle = DiaryCardIndicatorStyle.stamp,
    this.showLocation = false,
    this.showEnergy = false,
    this.showWordCount = false,
    this.showMedia = false,
  });

  /// 眉线日期；关闭后眉线只剩置顶徽章与（位于眉线时的）心情天气。
  final bool showDate;
  final DiaryCardDateFormat dateFormat;

  /// 日期后附星期；相对时间格式下不适用。
  final bool showWeekday;

  /// 日期后附 HH:mm；相对时间格式下不适用。
  final bool showTime;
  final DiaryCardDateSource dateSource;
  final DiaryCardFooterTime footerTime;

  /// 底栏日期放大号呈现：日期数字放大字号单独成块、旁边附月份与星期
  /// （暖阳预设用）；关闭时日期仍是底栏里的一段小字。
  final bool bigDate;

  /// 日期与标题同行：大日期块贴在标题行左侧、标题与摘要排在右侧
  /// （原版 Vivido 时间线卡片的排法，暖阳预设用；开启时底栏不再画
  /// 日期、也不再单独成行，摘要收进标题行右侧那一列）。
  final bool inlineDate;

  /// 媒体数量改画成右下角的圆角徽章（原版 Vivido 时间线卡片的徽章，
  /// 暖阳预设用）；关闭时媒体数仍走底栏附加信息。
  final bool mediaBadge;

  /// 大日期数字的颜色；来源为 theme 时沿用底栏文字色。
  final DiaryCardColorSpec dateAccent;
  final bool showMood;
  final bool showWeather;
  final DiaryCardIndicatorStyle indicatorStyle;
  final bool showLocation;
  final bool showEnergy;
  final bool showWordCount;

  /// 正文中的图片数量、录音、视频与附件标记。
  final bool showMedia;

  /// 底栏是否有附加信息（地点、精力、字数、媒体）。
  bool get hasFooterExtras =>
      showLocation || showEnergy || showWordCount || showMedia;

  DiaryCardMetaStyle copyWith({
    bool? showDate,
    DiaryCardDateFormat? dateFormat,
    bool? showWeekday,
    bool? showTime,
    DiaryCardDateSource? dateSource,
    DiaryCardFooterTime? footerTime,
    bool? bigDate,
    bool? inlineDate,
    bool? mediaBadge,
    DiaryCardColorSpec? dateAccent,
    bool? showMood,
    bool? showWeather,
    DiaryCardIndicatorStyle? indicatorStyle,
    bool? showLocation,
    bool? showEnergy,
    bool? showWordCount,
    bool? showMedia,
  }) {
    return DiaryCardMetaStyle(
      showDate: showDate ?? this.showDate,
      dateFormat: dateFormat ?? this.dateFormat,
      showWeekday: showWeekday ?? this.showWeekday,
      showTime: showTime ?? this.showTime,
      dateSource: dateSource ?? this.dateSource,
      footerTime: footerTime ?? this.footerTime,
      bigDate: bigDate ?? this.bigDate,
      inlineDate: inlineDate ?? this.inlineDate,
      mediaBadge: mediaBadge ?? this.mediaBadge,
      dateAccent: dateAccent ?? this.dateAccent,
      showMood: showMood ?? this.showMood,
      showWeather: showWeather ?? this.showWeather,
      indicatorStyle: indicatorStyle ?? this.indicatorStyle,
      showLocation: showLocation ?? this.showLocation,
      showEnergy: showEnergy ?? this.showEnergy,
      showWordCount: showWordCount ?? this.showWordCount,
      showMedia: showMedia ?? this.showMedia,
    );
  }

  static DiaryCardMetaStyle _fromJson(Object? raw) {
    const d = DiaryCardMetaStyle();
    final json = _map(raw);
    if (json == null) {
      return d;
    }
    return DiaryCardMetaStyle(
      showDate: _bool(json['showDate'], d.showDate),
      dateFormat: _enumByName(
        DiaryCardDateFormat.values,
        json['dateFormat'],
        d.dateFormat,
      ),
      showWeekday: _bool(json['showWeekday'], d.showWeekday),
      showTime: _bool(json['showTime'], d.showTime),
      dateSource: _enumByName(
        DiaryCardDateSource.values,
        json['dateSource'],
        d.dateSource,
      ),
      footerTime: _enumByName(
        DiaryCardFooterTime.values,
        json['footerTime'],
        d.footerTime,
      ),
      bigDate: _bool(json['bigDate'], d.bigDate),
      inlineDate: _bool(json['inlineDate'], d.inlineDate),
      mediaBadge: _bool(json['mediaBadge'], d.mediaBadge),
      dateAccent: DiaryCardColorSpec._fromJson(
        json['dateAccent'],
        d.dateAccent,
      ),
      showMood: _bool(json['showMood'], d.showMood),
      showWeather: _bool(json['showWeather'], d.showWeather),
      indicatorStyle: _enumByName(
        DiaryCardIndicatorStyle.values,
        json['indicatorStyle'],
        d.indicatorStyle,
      ),
      showLocation: _bool(json['showLocation'], d.showLocation),
      showEnergy: _bool(json['showEnergy'], d.showEnergy),
      showWordCount: _bool(json['showWordCount'], d.showWordCount),
      showMedia: _bool(json['showMedia'], d.showMedia),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryCardMetaStyle();
    final json = <String, Object>{};
    _put(json, 'showDate', showDate, d.showDate);
    _putEnum(json, 'dateFormat', dateFormat, d.dateFormat);
    _put(json, 'showWeekday', showWeekday, d.showWeekday);
    _put(json, 'showTime', showTime, d.showTime);
    _putEnum(json, 'dateSource', dateSource, d.dateSource);
    _putEnum(json, 'footerTime', footerTime, d.footerTime);
    _put(json, 'bigDate', bigDate, d.bigDate);
    _put(json, 'inlineDate', inlineDate, d.inlineDate);
    _put(json, 'mediaBadge', mediaBadge, d.mediaBadge);
    _putObject(
      json,
      'dateAccent',
      dateAccent._toJson(d.dateAccent),
    );
    _put(json, 'showMood', showMood, d.showMood);
    _put(json, 'showWeather', showWeather, d.showWeather);
    _putEnum(json, 'indicatorStyle', indicatorStyle, d.indicatorStyle);
    _put(json, 'showLocation', showLocation, d.showLocation);
    _put(json, 'showEnergy', showEnergy, d.showEnergy);
    _put(json, 'showWordCount', showWordCount, d.showWordCount);
    _put(json, 'showMedia', showMedia, d.showMedia);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardMetaStyle &&
        other.showDate == showDate &&
        other.dateFormat == dateFormat &&
        other.showWeekday == showWeekday &&
        other.showTime == showTime &&
        other.dateSource == dateSource &&
        other.footerTime == footerTime &&
        other.bigDate == bigDate &&
        other.inlineDate == inlineDate &&
        other.mediaBadge == mediaBadge &&
        other.dateAccent == dateAccent &&
        other.showMood == showMood &&
        other.showWeather == showWeather &&
        other.indicatorStyle == indicatorStyle &&
        other.showLocation == showLocation &&
        other.showEnergy == showEnergy &&
        other.showWordCount == showWordCount &&
        other.showMedia == showMedia;
  }

  @override
  int get hashCode => Object.hash(
    showDate,
    dateFormat,
    showWeekday,
    showTime,
    dateSource,
    footerTime,
    bigDate,
    inlineDate,
    mediaBadge,
    dateAccent,
    showMood,
    showWeather,
    indicatorStyle,
    showLocation,
    showEnergy,
    showWordCount,
    showMedia,
  );
}
