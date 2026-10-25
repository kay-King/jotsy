import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_create_entry_flow.dart';
import 'package:node_diary/ui/diaries/pages/diary_preview_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_card/diary_card_cover.dart';
import 'package:node_diary/utils/relative_time_formatter.dart';

import '../../../core/database/app_database.dart';
import '../widgets/desktop_card.dart';

/// 最近记录：一张白卡，标题行 + 查看全部；正文是最新一篇的摘要一行，左侧
/// 有封面时放一张小图；点整张卡进预览页。没有日记时给一句空态 + 写一篇。
class DesktopLatest extends ConsumerWidget {
  const DesktopLatest({
    super.key,
    required this.latest,
    required this.imageCount,
    required this.now,
  });

  final ExploreDiaryOverview? latest;
  final int imageCount;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final diary = latest;
    return DesktopCard(
      onTap: diary == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DiaryPreviewPage(diaryId: diary.diaryId),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.desktopLatestTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (diary != null)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiaryPreviewPage(diaryId: diary.diaryId),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.desktopViewAll,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (diary == null)
            _DesktopLatestEmpty(
              onWrite: () async {
                await runDiaryCreateEntryFlow(context, ref);
              },
            )
          else
            _DesktopLatestBody(diary: diary, imageCount: imageCount, now: now),
        ],
      ),
    );
  }
}

/// 最近记录空态：没有日记时的一句提示 + 写一篇按钮。
class _DesktopLatestEmpty extends StatelessWidget {
  const _DesktopLatestEmpty({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.desktopStatsLineEmpty,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onWrite, child: Text(l10n.navDiaries)),
      ],
    );
  }
}

/// 最近记录正文：左侧封面小图（有封面时）+ 摘要一行 + 时间与图片数。
class _DesktopLatestBody extends StatelessWidget {
  const _DesktopLatestBody({
    required this.diary,
    required this.imageCount,
    required this.now,
  });

  final ExploreDiaryOverview diary;
  final int imageCount;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final cover = diary.cover?.trim();
    final excerpt = _excerpt(diary);
    final meta = StringBuffer(
      RelativeTimeFormatter.formatUpdatedAt(
        updatedAt: diary.updatedAt,
        now: now,
        l10n: l10n,
      ),
    );
    if (imageCount > 0) {
      meta.write(' · ${l10n.desktopImagesCount(imageCount)}');
    }
    meta.write(' · ${l10n.desktopOnlyMe}');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (cover != null && cover.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DiaryCardCoverImage(
              source: cover,
              width: 64,
              height: 64,
              radius: 8,
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (excerpt.isNotEmpty)
                Text(
                  excerpt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurface,
                  ),
                ),
              if (excerpt.isNotEmpty) const SizedBox(height: 6),
              Text(
                meta.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 摘要：正文纯文本压成一行；没有正文时用标题；只有图片时为空。
  String _excerpt(ExploreDiaryOverview diary) {
    final text = diary.contentText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isNotEmpty) {
      return text;
    }
    return diary.title.trim();
  }
}
