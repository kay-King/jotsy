import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../providers/diary_detail_provider.dart';
import 'diary_link_card.dart';
import 'diary_link_card_view.dart';

/// 预览页的日记卡片只读渲染：与编辑器内同一套外观，点按直接打开那篇日记。
class DiaryLinkCardPreview extends ConsumerWidget {
  const DiaryLinkCardPreview({
    super.key,
    required this.node,
    required this.onOpenDiary,
  });

  final Node node;

  /// 点按卡片打开被链日记；null 时卡片不可点按。
  final ValueChanged<String>? onOpenDiary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaryId = diaryLinkCardDiaryId(node);
    if (diaryId == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final detailAsync = ref.watch(diaryDetailProvider(diaryId));
    if (detailAsync.isLoading) {
      return const SizedBox(height: 76);
    }
    final diary = detailAsync.value?.diary;
    final title = diary?.title.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DiaryLinkCardView(
        title: diary == null
            ? null
            : (title == null || title.isEmpty ? l10n.autoT0033 : title),
        dateLabel: diary == null
            ? null
            : l10n.formatFullDate(diary.createdAt.toLocal()),
        summary: diary?.contentText,
        coverPath: diary?.cover,
        missingLabel: l10n.linkCardMissing,
        onTap: diary == null || onOpenDiary == null
            ? null
            : () => onOpenDiary!(diaryId),
      ),
    );
  }
}
