import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../notebooks/controllers/notebook_lock_flow.dart';
import '../../notebooks/providers/home_notebook_scope_provider.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../notebooks/sections/notebook_shelf_sheet.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../settings/pages/settings_page.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 日记页左侧边栏：日记本列表（照 moodiary CategoryDrawer 模式改造）。
///
/// Salt 风：白底、行平铺、选中行浅蓝底。
///
/// - 顶部 Header：应用名 + 日记总数；
/// - “日记本”标题行 + 数量；
/// - 列表：全部日记（带总数）→ 手动日记本（名字 + 篇数含子本 + 颜色点）
///   → 未收录（有未收录日记时才显示，带篇数）；
/// - 底部：管理日记本按钮（开书架）+ 设置图标。
///
/// 点一项就切换范围并自动关掉抽屉；上锁日记本先走验证。
class DiaryNotebookDrawer extends ConsumerWidget {
  const DiaryNotebookDrawer({super.key});

  Future<void> _enterNotebook(
    BuildContext context,
    WidgetRef ref,
    NotebookView notebook,
  ) async {
    final allowed = await authorizeNotebookEntry(context, ref, notebook);
    if (!allowed || !context.mounted) {
      return;
    }
    ref.read(homeNotebookScopeProvider.notifier).enter(notebook.id);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showAll(BuildContext context, WidgetRef ref) {
    ref.read(homeNotebookScopeProvider.notifier).showAll();
    Navigator.of(context).pop();
  }

  void _enterUnfiled(BuildContext context, WidgetRef ref) {
    ref.read(homeNotebookScopeProvider.notifier).enterUnfiled();
    Navigator.of(context).pop();
  }

  Future<void> _openShelf(BuildContext context, WidgetRef ref) async {
    final currentId = ref.read(homeNotebookScopeProvider).notebookId;
    // 先关抽屉，再开书架，避免两层叠加。
    Navigator.of(context).pop();
    final result = await showNotebookShelfSheet(
      context,
      currentNotebookId: currentId,
    );
    if (!context.mounted || result == null) {
      return;
    }
    switch (result) {
      case NotebookShelfSelectAll():
        ref.read(homeNotebookScopeProvider.notifier).showAll();
      case NotebookShelfSelectNotebook(:final notebookId):
        final notebooks =
            ref.read(notebooksProvider).value ?? const <NotebookView>[];
        NotebookView? notebook;
        for (final candidate in notebooks) {
          if (candidate.id == notebookId) {
            notebook = candidate;
            break;
          }
        }
        if (notebook != null && context.mounted) {
          await _enterNotebook(context, ref, notebook);
        }
      case NotebookShelfSelectUnfiled():
        ref.read(homeNotebookScopeProvider.notifier).enterUnfiled();
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final scope = ref.watch(homeNotebookScopeProvider);
    final notebooksAsync = ref.watch(notebooksProvider);
    final countsAsync = ref.watch(notebookEntryCountsProvider);
    final unfiledCountAsync = ref.watch(unfiledDiaryCountProvider);
    final totalCountAsync = ref.watch(
      StreamProvider<int>(
        (ref) => ref
            .watch(appDatabaseProvider)
            .watchScopedDiaryCount(DiaryListScope.all),
      ),
    );

    final notebooks = notebooksAsync.value ?? const <NotebookView>[];
    final manualNotebooks = <NotebookView>[
      for (final n in notebooks)
        if (n.isManual) n,
    ];
    final counts = countsAsync.value ?? const <String, int>{};
    final unfiledCount = unfiledCountAsync.value ?? 0;
    final totalCount = totalCountAsync.value;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部 Header：应用名 + 日记总数。
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jotsy',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (totalCount != null)
                    Text(
                      l10n.diaryDrawerTotalCount(totalCount),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // “日记本”标题行 + 数量。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  Text(
                    l10n.diaryDrawerNotebooks,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.diaryDrawerNotebookCount(manualNotebooks.length),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _DrawerTile(
                    label: l10n.notebookAllDiaries,
                    count: totalCount,
                    selected: scope.isAll,
                    leading: _ColorDot.all(colorScheme: colorScheme),
                    onTap: () => _showAll(context, ref),
                  ),
                  for (final notebook in manualNotebooks)
                    _DrawerTile(
                      label: notebook.name,
                      count: counts[notebook.id] ?? 0,
                      selected: scope.notebookId == notebook.id,
                      leading: _ColorDot(
                        color: notebook.color == null
                            ? null
                            : Color(notebook.color!),
                        colorScheme: colorScheme,
                      ),
                      onTap: () => _enterNotebook(context, ref, notebook),
                    ),
                  if (unfiledCount > 0) ...[
                    const Divider(height: 1),
                    _DrawerTile(
                      label: l10n.notebookUnfiled,
                      count: unfiledCount,
                      selected: scope.isUnfiled,
                      leading: _ColorDot.none(colorScheme: colorScheme),
                      onTap: () => _enterUnfiled(context, ref),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                4,
                12,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openShelf(context, ref),
                      icon: const Icon(Icons.tune_outlined, size: 18),
                      label: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.diaryDrawerManageNotebooks),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: l10n.settingsTitle,
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 44),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉行：颜色点 + 名字 + 篇数，选中时浅蓝底。
class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 颜色圆点：全部日记用渐变/特殊样式，有颜色用颜色，无颜色用灰色描边。
class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.colorScheme})
    : _variant = _DotVariant.color;

  const _ColorDot.all({required this.colorScheme})
    : color = null,
      _variant = _DotVariant.all;

  const _ColorDot.none({required this.colorScheme})
    : color = null,
      _variant = _DotVariant.none;

  final Color? color;
  final ColorScheme colorScheme;
  final _DotVariant _variant;

  @override
  Widget build(BuildContext context) {
    switch (_variant) {
      case _DotVariant.all:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
        );
      case _DotVariant.none:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colorScheme.outline, width: 1.5),
          ),
        );
      case _DotVariant.color:
        final c = color;
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c ?? colorScheme.surfaceContainerHighest,
          ),
        );
    }
  }
}

enum _DotVariant { all, none, color }
