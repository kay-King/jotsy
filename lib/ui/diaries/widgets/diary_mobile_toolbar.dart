import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_callout_block/diary_callout_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_divider_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_image_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link_card/diary_link_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_link_card/diary_link_card_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_quote_bar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toggle_block/diary_toggle_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_builder.dart';
import 'package:node_diary/ui/widgets/image_viewer_hero.dart';

// 编辑页悬浮工具栏（常驻 + 「更多」面板）与正文渲染器的统一入口。
export '../models/diary_toolbar_layout.dart';
export '../models/diary_toolbar_preferences.dart';
export '../models/diary_toolbar_time_format.dart';
export 'diary_floating_toolbar.dart';
export 'diary_toolbar_panel_reserve.dart';

/// 编辑、发布预览和阅读页共用全部块组件（AppFlowy）；图片点按菜单见
/// `showDiaryImageOptions`。
/// [onImageOpen]：只读正文里点按图片时调用，第二个参数是从图片画面抓取的
/// 看图页飞入信息（减少动画或图片未解码时为 null）。
///
/// [foldLongImages]：正文长图折叠（默认）还是完整展开，只有预览页按阅读行为
/// 设置传入。
///
/// [onOpenDiary]：日记卡片块里点“打开日记”时调用（编辑页传入打开预览页的
/// 回调）；null 时菜单里点打开无反应。
Map<String, BlockComponentBuilder> buildDiaryBlockComponentBuilders({
  void Function(String imageSource, ImageViewerHero? hero)? onImageOpen,
  bool foldLongImages = true,
  void Function(String diaryId)? onOpenDiary,
}) {
  // 标准引用块的配置（占位文案与留白）：只换竖条，其他沿用。
  final quoteConfiguration =
      (standardBlockComponentBuilderMap[QuoteBlockKeys.type]
              as QuoteBlockComponentBuilder)
          .configuration;
  return <String, BlockComponentBuilder>{
    // 引用：竖条与相邻的引用相接时画进本块的上下留白（padding + margin），
    // 连续几行引用连成一条，见 DiaryQuoteBar（v0.11.0 #134）。
    QuoteBlockKeys.type: QuoteBlockComponentBuilder(
      configuration: quoteConfiguration,
      iconBuilder: (context, node) => DiaryQuoteBar(
        node: node,
        blockInsets:
            quoteConfiguration.padding(node) + quoteConfiguration.margin(node),
      ),
    ),
    // 菜单里删除图片只移出正文，不删文件：撤销或放弃修改后原日记还要用，
    // 文件由 DiaryMediaCleanupService 按引用回收。
    kDiaryBlockImage: DiaryImageEmbedBuilder(
      onImageOpen: onImageOpen,
      foldLongImages: foldLongImages,
    ),
    kDiaryBlockVideo: DiaryVideoEmbedBuilder(),
    kDiaryBlockAudio: DiaryAudioEmbedBuilder(),
    kDiaryBlockAttachment: DiaryAttachmentEmbedBuilder(),
    kDiaryBlockDivider: DiaryDividerEmbedBuilder(),
    // v0.10.0：折叠块与提示块（自定义块，AppFlowy 原生版本无）。
    kDiaryToggleBlockType: DiaryToggleBlockComponentBuilder(),
    kDiaryCalloutBlockType: DiaryCalloutBlockComponentBuilder(),
    // v0.10.0：日记卡片块（嵌入一篇日记的实时卡片）。
    kDiaryLinkCardBlockType: DiaryLinkCardBlockComponentBuilder(
      onOpenDiary: onOpenDiary,
    ),
  };
}
