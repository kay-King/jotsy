import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/diary_blocks/diary_blocks_appflowy.dart';
import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../diary_link_card/diary_link_card.dart';
import '../diary_mention/diary_mention_trigger.dart';

/// 反向链接：“提到这篇的日记”。
///
/// 查询逻辑：扫描全部可见日记的正文块（经 [diaryDocumentFromStoredJson]
/// 解析），找出带 `href == 'diary://<当前id>'` 行内链接的，或放了
/// [diaryId] 相同的日记卡片块的。只在预览页打开时计算一次，结果由
/// [diaryBacklinksProvider]（autoDispose）缓存，关闭页面即释放。

/// 一条反向链接。
class DiaryBacklinkEntry {
  const DiaryBacklinkEntry({
    required this.diaryId,
    required this.title,
    required this.createdAt,
  });

  final String diaryId;
  final String title;
  final DateTime createdAt;
}

/// 纯函数：从日记行里找出提到 [diaryId] 的日记（不含自己）。
///
/// “提到”指正文里有 `diary://<diaryId>` 的行内链接，或有指向它的日记
/// 卡片块。单篇解析失败时跳过该篇，不影响其他。
List<DiaryBacklinkEntry> findDiaryBacklinks(
  List<Diary> diaries,
  String diaryId,
) {
  final entries = <DiaryBacklinkEntry>[];
  for (final diary in diaries) {
    if (diary.diaryId == diaryId) continue;
    if (!_mentionsDiary(diary.content, diaryId)) continue;
    entries.add(
      DiaryBacklinkEntry(
        diaryId: diary.diaryId,
        title: diary.title,
        createdAt: diary.createdAt,
      ),
    );
  }
  return entries;
}

bool _mentionsDiary(String rawContent, String diaryId) {
  try {
    final document = diaryDocumentFromStoredJson(rawContent);
    return document.root.children.any(
      (node) => _nodeMentionsDiary(node, diaryId),
    );
  } catch (_) {
    // 坏块文档不挡住整批扫描。
    return false;
  }
}

bool _nodeMentionsDiary(Node node, String diaryId) {
  // 日记卡片块：指向这篇即算提到。
  if (diaryLinkCardDiaryId(node) == diaryId) return true;
  final delta = node.delta;
  if (delta != null) {
    for (final op in delta) {
      if (op is! TextInsert) continue;
      final href = op.attributes?[kDiaryInlineHref];
      if (href is String && parseDiaryLinkHref(href)?.diaryId == diaryId) {
        return true;
      }
    }
  }
  return node.children.any((child) => _nodeMentionsDiary(child, diaryId));
}

/// 反向链接查询：预览页打开时扫一次全库并缓存。
final diaryBacklinksProvider = FutureProvider.autoDispose
    .family<List<DiaryBacklinkEntry>, String>((Ref ref, String diaryId) async {
      final db = ref.watch(appDatabaseProvider);
      // 私密日记已被 getActiveDiariesPage 的统一谓词排除，不会泄漏。
      final diaries = <Diary>[];
      var offset = 0;
      while (true) {
        final page = await db.getActiveDiariesPage(limit: 200, offset: offset);
        diaries.addAll(page);
        if (page.length < 200) break;
        offset += page.length;
      }
      return findDiaryBacklinks(diaries, diaryId);
    });

/// 预览页正文末尾的“提到这篇的日记”区块；没有反向链接时不占位。
class DiaryBacklinksSection extends ConsumerWidget {
  const DiaryBacklinksSection({
    super.key,
    required this.diaryId,
    this.onOpenDiary,
  });

  final String diaryId;
  final ValueChanged<String>? onOpenDiary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backlinksAsync = ref.watch(diaryBacklinksProvider(diaryId));
    final entries = backlinksAsync.value;
    if (entries == null || entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            FaIcon(
              FontAwesomeIcons.link,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.backlinksTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          _BacklinkRow(
            entry: entry,
            onTap: onOpenDiary == null
                ? null
                : () => onOpenDiary!(entry.diaryId),
          ),
      ],
    );
  }
}

class _BacklinkRow extends StatelessWidget {
  const _BacklinkRow({required this.entry, this.onTap});

  final DiaryBacklinkEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = entry.title.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: <Widget>[
            FaIcon(FontAwesomeIcons.book, size: 15, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title.isEmpty ? context.l10n.autoT0033 : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    context.l10n.formatFullDate(entry.createdAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FaIcon(
              FontAwesomeIcons.angleRight,
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
