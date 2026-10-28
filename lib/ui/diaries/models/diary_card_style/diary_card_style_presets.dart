import 'diary_card_style.dart';

/// 内置预设的标识；名称、说明与图标由设置页按 id 解析（模型层不含文案）。
enum DiaryCardPresetId {
  classic,
  compact,
  magazine,
  minimal,
  gallery,
  sticky,
  journal,
  mood,
  memo,
}

/// 内置的卡片样式预设。
///
/// 套用预设即把当前样式整体替换为预设值（之后可继续微调）；[classic] 就是
/// 默认样式。标签显示数量是独立设置，预设不改动它。
abstract final class DiaryCardPresets {
  static const Map<DiaryCardPresetId, DiaryCardStyle> styles =
      <DiaryCardPresetId, DiaryCardStyle>{
        DiaryCardPresetId.classic: DiaryCardStyle.defaults,
        DiaryCardPresetId.compact: _compact,
        DiaryCardPresetId.magazine: _magazine,
        DiaryCardPresetId.minimal: _minimal,
        DiaryCardPresetId.gallery: _gallery,
        DiaryCardPresetId.sticky: _sticky,
        DiaryCardPresetId.journal: _journal,
        DiaryCardPresetId.mood: _mood,
        DiaryCardPresetId.memo: _memo,
      };

  static DiaryCardStyle styleOf(DiaryCardPresetId id) => styles[id]!;

  /// 与 [style] 完全相同的第一个预设；不是任何预设时为 null。
  static DiaryCardPresetId? match(DiaryCardStyle style) {
    for (final entry in styles.entries) {
      if (entry.value == style) {
        return entry.key;
      }
    }
    return null;
  }

  /// 紧凑：小封面、单行摘要、收紧的间距，一屏能看到更多日记。
  static const _compact = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(cornerRadius: 18),
    typography: DiaryCardTypography(titleScale: 0.9),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.start,
      coverSide: 84,
      coverRadius: 12,
      coverHeight: 160,
      coverGap: 12,
      paddingH: 14,
      paddingV: 10,
      cardGap: 6,
      elementGap: 4,
      previewMaxLines: 1,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 112,
      coverGap: 10,
      paddingH: 12,
      paddingV: 10,
      cardGap: 6,
      elementGap: 4,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 杂志：通栏大图、放大的标题与宽松行距，完整日期。
  /// （2026-10-25 用户拿另一款日记 App 对比后定：竖版通栏大图 +
  /// 大字 + 宽松间距更高级；封面高 200、标题 1.1 倍、正文全字号，
  /// 是之前默认改版那一版的样子，现在收进杂志预设，经典小图保留。）
  static const _magazine = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 20,
      shadow: DiaryCardShadowStyle.soft,
    ),
    typography: DiaryCardTypography(
      titleScale: 1.1,
      previewScale: 1.0,
      lineHeight: DiaryCardLineHeight.relaxed,
    ),
    content: DiaryCardContentStyle(tagStyle: DiaryCardTagStyle.plain),
    meta: DiaryCardMetaStyle(dateFormat: DiaryCardDateFormat.full),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 200,
      coverDivider: false,
      coverGap: 14,
      paddingH: 18,
      paddingV: 16,
      elementGap: 8,
      previewMaxLines: 3,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 180,
      coverDivider: false,
      coverGap: 10,
      paddingH: 14,
      paddingV: 14,
      elementGap: 6,
      previewMaxLines: 4,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 极简：只留文字，去掉封面、描边、阴影与心情天气。
  static const _minimal = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 16,
      borderWidth: 0,
      shadow: DiaryCardShadowStyle.none,
    ),
    typography: DiaryCardTypography(titleWeight: DiaryCardTitleWeight.medium),
    content: DiaryCardContentStyle(
      tagStyle: DiaryCardTagStyle.dot,
      pinnedBadge: DiaryCardPinnedBadge.iconOnly,
    ),
    meta: DiaryCardMetaStyle(
      showMood: false,
      showWeather: false,
      footerTime: DiaryCardFooterTime.hidden,
    ),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.hidden,
      coverHeight: 160,
      coverGap: 14,
      paddingH: 16,
      paddingV: 16,
      elementGap: 6,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.hidden,
      coverHeight: 140,
      coverGap: 10,
      paddingH: 14,
      paddingV: 14,
      elementGap: 5,
      previewMaxLines: 4,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 画廊：照片优先。列表为多图拼贴的通栏封面，瀑布流以封面作卡片背景。
  static const _gallery = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 22,
      shadow: DiaryCardShadowStyle.floating,
    ),
    content: DiaryCardContentStyle(collage: true),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 200,
      coverDivider: false,
      coverGap: 14,
      paddingH: 16,
      paddingV: 14,
      elementGap: 6,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.cover,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.background,
      coverHeight: 252,
      coverGap: 10,
      // 底板半透明度：0.85 时底板几乎不透白，照片当背景却只剩顶部
      // 一截能看，底部像贴了一条白带。降到 0.4，照片透过底板仍清
      // 晰，文字也有浅底衬着可读。
      scrim: 0.4,
      paddingH: 12,
      paddingV: 12,
      elementGap: 4,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.cover,
    ),
  );

  /// 便签：暖黄纸面、顶部色条与小圆角，封面像夹在纸上的照片。
  static const _sticky = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 6,
      background: DiaryCardColorSpec(
        source: DiaryCardColorSource.custom,
        light: 0xFFFFF4B8,
        strength: 1,
      ),
      borderWidth: 0,
      accentBar: DiaryCardAccentBar.top,
      accentWidth: 6,
      accentColor: DiaryCardColorSpec(
        source: DiaryCardColorSource.custom,
        light: 0xFFF2B33D,
        strength: 1,
      ),
      shadow: DiaryCardShadowStyle.floating,
    ),
    content: DiaryCardContentStyle(tagStyle: DiaryCardTagStyle.plain),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.end,
      coverSide: 88,
      coverShape: DiaryCardCoverShape.portrait,
      coverRadius: 4,
      coverHeight: 160,
      coverGap: 14,
      paddingH: 16,
      paddingV: 16,
      elementGap: 6,
      previewMaxLines: 3,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverRadius: 4,
      coverHeight: 120,
      coverInset: true,
      coverGap: 10,
      paddingH: 12,
      paddingV: 14,
      elementGap: 5,
      previewMaxLines: 4,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );

  /// 手账：起始边主色条，没有封面时用大号日期块占位。
  static const _journal = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 18,
      accentBar: DiaryCardAccentBar.start,
    ),
    content: DiaryCardContentStyle(
      coverFallback: DiaryCardCoverFallback.dateBlock,
    ),
    meta: DiaryCardMetaStyle(showTime: true),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.start,
      coverSide: 96,
      coverRadius: 14,
      coverHeight: 160,
      coverGap: 14,
      paddingH: 16,
      paddingV: 14,
      elementGap: 6,
      previewMaxLines: 2,
      metaPosition: DiaryCardMetaPosition.eyebrow,
    ),
  );

  /// 心情色：卡片底色、描边随当天心情变化，没有封面时显示心情块。
  static const _mood = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      background: DiaryCardColorSpec(
        source: DiaryCardColorSource.mood,
        strength: 0.16,
      ),
      borderWidth: 1.2,
      borderColor: DiaryCardColorSpec(
        source: DiaryCardColorSource.mood,
        strength: 0.6,
      ),
    ),
    content: DiaryCardContentStyle(
      coverFallback: DiaryCardCoverFallback.moodTile,
    ),
    meta: DiaryCardMetaStyle(indicatorStyle: DiaryCardIndicatorStyle.plain),
  );

  /// 备忘（IdeaMemo 风格）：文字先、封面在正文下面，像写备忘一样。
  /// 借鉴 ldlywt/IdeaMemo 的 NoteCard（GPL-3.0，与本项目同许可证；
  /// IdeaMemo 是 Kotlin/Compose，jotsy 是 Dart/Flutter，这里是按
  /// 它的版式与数值在 jotsy 卡片模型里重写，不是照抄代码）：
  /// 正文 16sp、行高 26sp（宽松），最多显示 8 行；图片在正文下面，
  /// 多图拼贴最多 3 张（等宽并排，点进预览看全部）；底栏是“几月几日
  /// 周X 几时几分”垫底，顶上不另排日期行；卡片间距收紧。
  static const _memo = DiaryCardStyle(
    surface: DiaryCardSurfaceStyle(
      cornerRadius: 16,
      shadow: DiaryCardShadowStyle.soft,
    ),
    typography: DiaryCardTypography(
      titleScale: 1.0,
      previewScale: 1.1,
      lineHeight: DiaryCardLineHeight.relaxed,
    ),
    content: DiaryCardContentStyle(collage: true),
    meta: DiaryCardMetaStyle(
      showDate: false,
      footerTime: DiaryCardFooterTime.dateTime,
    ),
    list: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.bottom,
      coverHeight: 160,
      coverDivider: false,
      coverGap: 12,
      paddingH: 16,
      paddingV: 12,
      cardGap: 8,
      elementGap: 8,
      previewMaxLines: 8,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
    waterfall: DiaryCardModeStyle(
      coverPosition: DiaryCardCoverPosition.top,
      coverHeight: 140,
      coverGap: 10,
      paddingH: 14,
      paddingV: 12,
      cardGap: 8,
      elementGap: 6,
      previewMaxLines: 4,
      metaPosition: DiaryCardMetaPosition.footer,
    ),
  );
}
