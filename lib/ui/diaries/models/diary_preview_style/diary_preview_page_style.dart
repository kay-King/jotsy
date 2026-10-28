part of 'diary_preview_style.dart';

/// 页面与顶栏：配色基调、纸张、边距、正文宽度、顶栏、阅读进度与回到顶部。
@immutable
class DiaryPreviewPageStyle {
  const DiaryPreviewPageStyle({
    this.colorSeed = DiaryPreviewColorSeed.app,
    this.paper = DiaryPreviewPaper.theme,
    this.horizontalPadding = 16,
    this.limitWidth = false,
    this.contentWidth = 640,
    this.topBar = DiaryPreviewTopBarMode.floating,
    this.topBarTitle = DiaryPreviewTopBarTitle.label,
    this.showTypographyButton = true,
    this.showEditButton = true,
    this.showShareButton = false,
    this.progress = DiaryPreviewProgress.none,
    this.backToTop = false,
  });

  final DiaryPreviewColorSeed colorSeed;

  final DiaryPreviewPaper paper;
  final double horizontalPadding;

  /// 是否限制正文宽度（平板与横屏时居中排版）。
  final bool limitWidth;
  final double contentWidth;
  final DiaryPreviewTopBarMode topBar;
  final DiaryPreviewTopBarTitle topBarTitle;
  final bool showTypographyButton;
  final bool showEditButton;
  final bool showShareButton;
  final DiaryPreviewProgress progress;
  final bool backToTop;

  DiaryPreviewPageStyle copyWith({
    DiaryPreviewColorSeed? colorSeed,
    DiaryPreviewPaper? paper,
    double? horizontalPadding,
    bool? limitWidth,
    double? contentWidth,
    DiaryPreviewTopBarMode? topBar,
    DiaryPreviewTopBarTitle? topBarTitle,
    bool? showTypographyButton,
    bool? showEditButton,
    bool? showShareButton,
    DiaryPreviewProgress? progress,
    bool? backToTop,
  }) {
    return DiaryPreviewPageStyle(
      colorSeed: colorSeed ?? this.colorSeed,
      paper: paper ?? this.paper,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      limitWidth: limitWidth ?? this.limitWidth,
      contentWidth: contentWidth ?? this.contentWidth,
      topBar: topBar ?? this.topBar,
      topBarTitle: topBarTitle ?? this.topBarTitle,
      showTypographyButton: showTypographyButton ?? this.showTypographyButton,
      showEditButton: showEditButton ?? this.showEditButton,
      showShareButton: showShareButton ?? this.showShareButton,
      progress: progress ?? this.progress,
      backToTop: backToTop ?? this.backToTop,
    );
  }

  static DiaryPreviewPageStyle _fromJson(Object? raw) {
    const d = DiaryPreviewPageStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    return DiaryPreviewPageStyle(
      colorSeed: StyleJson.enumByName(
        DiaryPreviewColorSeed.values,
        json['colorSeed'],
        d.colorSeed,
      ),
      paper: StyleJson.enumByName(
        DiaryPreviewPaper.values,
        json['paper'],
        d.paper,
      ),
      horizontalPadding: StyleJson.number(
        json['horizontalPadding'],
        d.horizontalPadding,
        DiaryPreviewStyleLimits.horizontalPadding,
      ),
      limitWidth: StyleJson.boolean(json['limitWidth'], d.limitWidth),
      contentWidth: StyleJson.number(
        json['contentWidth'],
        d.contentWidth,
        DiaryPreviewStyleLimits.contentWidth,
      ),
      topBar: StyleJson.enumByName(
        DiaryPreviewTopBarMode.values,
        json['topBar'],
        d.topBar,
      ),
      topBarTitle: StyleJson.enumByName(
        DiaryPreviewTopBarTitle.values,
        json['topBarTitle'],
        d.topBarTitle,
      ),
      showTypographyButton: StyleJson.boolean(
        json['showTypographyButton'],
        d.showTypographyButton,
      ),
      showEditButton: StyleJson.boolean(
        json['showEditButton'],
        d.showEditButton,
      ),
      showShareButton: StyleJson.boolean(
        json['showShareButton'],
        d.showShareButton,
      ),
      progress: StyleJson.enumByName(
        DiaryPreviewProgress.values,
        json['progress'],
        d.progress,
      ),
      backToTop: StyleJson.boolean(json['backToTop'], d.backToTop),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewPageStyle();
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'colorSeed', colorSeed, d.colorSeed);
    StyleJson.putEnum(json, 'paper', paper, d.paper);
    StyleJson.put(
      json,
      'horizontalPadding',
      horizontalPadding,
      d.horizontalPadding,
    );
    StyleJson.put(json, 'limitWidth', limitWidth, d.limitWidth);
    StyleJson.put(json, 'contentWidth', contentWidth, d.contentWidth);
    StyleJson.putEnum(json, 'topBar', topBar, d.topBar);
    StyleJson.putEnum(json, 'topBarTitle', topBarTitle, d.topBarTitle);
    StyleJson.put(
      json,
      'showTypographyButton',
      showTypographyButton,
      d.showTypographyButton,
    );
    StyleJson.put(json, 'showEditButton', showEditButton, d.showEditButton);
    StyleJson.put(json, 'showShareButton', showShareButton, d.showShareButton);
    StyleJson.putEnum(json, 'progress', progress, d.progress);
    StyleJson.put(json, 'backToTop', backToTop, d.backToTop);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewPageStyle &&
        other.colorSeed == colorSeed &&
        other.paper == paper &&
        other.horizontalPadding == horizontalPadding &&
        other.limitWidth == limitWidth &&
        other.contentWidth == contentWidth &&
        other.topBar == topBar &&
        other.topBarTitle == topBarTitle &&
        other.showTypographyButton == showTypographyButton &&
        other.showEditButton == showEditButton &&
        other.showShareButton == showShareButton &&
        other.progress == progress &&
        other.backToTop == backToTop;
  }

  @override
  int get hashCode => Object.hash(
    colorSeed,
    paper,
    horizontalPadding,
    limitWidth,
    contentWidth,
    topBar,
    topBarTitle,
    showTypographyButton,
    showEditButton,
    showShareButton,
    progress,
    backToTop,
  );
}
