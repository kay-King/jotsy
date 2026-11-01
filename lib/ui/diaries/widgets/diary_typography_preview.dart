import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../l10n/app_localizations.dart';
import 'diary_preview/diary_appflowy_preview.dart';
import '../viewmodels/diary_text_appearance.dart';

/// 正文排版预览卡：示例标题 + 几段示例正文，按传入外观渲染。
///
/// 正文用 [DiaryAppFlowyPreview] 只读渲染（与日记预览页同一套逐块渲染）：
/// 字体、字号、行距、字间距、段间距、首行缩进在这里看到的就是日记里的效果。
/// 示例文本随界面语言切换时重建文档。预览不可交互：不允许选择文字，
/// 也不抢滚动手势。
class DiaryTypographyPreview extends StatelessWidget {
  const DiaryTypographyPreview({
    super.key,
    required this.appearance,
    this.maxHeight = double.infinity,
  });

  final DiaryTextAppearance appearance;

  /// 卡片高度上限：超出时卡片外框保持完整圆角，示例文字在卡内滚动。
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ExpressiveSurfaces.cardColor(colorScheme),
        borderRadius: BorderRadius.circular(20),
        border: Border.fromBorderSide(
          ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.diaryTypographySampleTitle,
              style: appearance.titleStyle(
                theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            DiaryAppFlowyPreview(
              document: _sampleDocument(context.l10n.diaryTypographySampleBody),
              appearance: appearance,
              textSelection: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// 示例正文拼成块文档：每行一个段落块。
Document _sampleDocument(String sample) {
  return Document(
    root: Node(
      type: kDiaryBlockPage,
      children: <Node>[
        for (final line in sample.split('\n')) paragraphNode(text: line),
      ],
    ),
  );
}
