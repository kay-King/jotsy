import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';

/// 日记筛选 BottomSheet：日记本切换 + 标签多选 + 清除筛选。
///
/// Salt 风：白卡底、分组标题、行平铺。筛选逻辑（filterState、scope）一点不动，
/// 只是把原来顶栏 DiaryTagFilterBar 的入口搬到这里。
class DiaryFilterSheet extends ConsumerWidget {
  const DiaryFilterSheet({
    super.key,
    required this.currentNotebookName,
    required this.isAllScope,
    required this.onOpenNotebookShelf,
    required this.onToggleTag,
    required this.onClearFilters,
  });

  /// 当前日记本名称；全部日记时为 null。
  final String? currentNotebookName;

  /// 是否为“全部日记”范围。
  final bool isAllScope;

  /// 打开日记本选择（书架）。
  final VoidCallback onOpenNotebookShelf;

  /// 切换标签选中：(tagId, 是否选中)。
  final void Function(int tagId, bool selected) onToggleTag;

  /// 清除所有筛选（标签 + 范围回到全部）。
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final tagsAsync = ref.watch(tagListProvider);
    final filterState = ref.watch(diaryFilterProvider);
    final selectedIds = filterState.selectedTagIds;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.diaryFilterSheetTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    onClearFilters();
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.diaryFilterClear),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 日记本分组
            _SectionTitle(title: l10n.diaryFilterNotebook),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.book_outlined,
                size: 20,
                color: colorScheme.onSurface,
              ),
              title: Text(
                isAllScope
                    ? l10n.notebookAllDiaries
                    : (currentNotebookName ?? l10n.notebookAllDiaries),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                Navigator.of(context).pop();
                onOpenNotebookShelf();
              },
            ),
            const Divider(height: 1),
            // 标签分组
            _SectionTitle(title: l10n.diaryFilterTags),
            tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.diaryFilterNoTags,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final selected = selectedIds.contains(tag.id);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(tag.name),
                        value: selected,
                        activeColor: colorScheme.primary,
                        onChanged: (value) {
                          if (value != null) {
                            onToggleTag(tag.id, value);
                          }
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分组标题：小字、次要颜色，跟设置页组标题风格一致。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
