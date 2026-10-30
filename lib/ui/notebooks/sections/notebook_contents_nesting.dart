import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../models/notebook_tree.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';

/// 日记本内容页的面包屑：顶级 > 父本 > 当前本。
///
/// 点祖先经 [onOpen] 跳到那本的内容页（由调用方处理路由）。当前本不高亮为可点。
class NotebookBreadcrumb extends ConsumerWidget {
  const NotebookBreadcrumb({
    super.key,
    required this.notebookId,
    required this.onOpen,
  });

  final String notebookId;
  final void Function(String ancestorId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(notebooksProvider).value;
    if (notebooks == null || notebooks.isEmpty) {
      return const SizedBox.shrink();
    }
    final tree = NotebookTree(<NotebookNode>[
      for (final n in notebooks) NotebookNode(n.id, n.row.parentId),
    ]);
    final ancestors = tree.ancestorsOf(notebookId).reversed.toList();
    if (ancestors.isEmpty) {
      return const SizedBox.shrink();
    }
    final byId = <String, NotebookView>{for (final n in notebooks) n.id: n};
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.l,
        end: AppSpacing.l,
        top: AppSpacing.s,
        bottom: AppSpacing.s,
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < ancestors.length; i++) ...<Widget>[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: FaIcon(FontAwesomeIcons.angleRight, size: 12),
              ),
            _BreadcrumbButton(
              label: byId[ancestors[i]]?.name ?? ancestors[i],
              onTap: () => onOpen(ancestors[i]),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: FaIcon(FontAwesomeIcons.angleRight, size: 12),
          ),
          Text(
            byId[notebookId]?.name ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreadcrumbButton extends StatelessWidget {
  const _BreadcrumbButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// 子日记本列表行：内容页顶部，列出直接子本，点进子本内容页。
class NotebookChildList extends ConsumerWidget {
  const NotebookChildList({
    super.key,
    required this.notebookId,
    required this.onOpen,
  });

  final String notebookId;
  final void Function(String childId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(notebooksProvider).value;
    if (notebooks == null) return const SizedBox.shrink();
    final tree = NotebookTree(<NotebookNode>[
      for (final n in notebooks) NotebookNode(n.id, n.row.parentId),
    ]);
    final childIds = tree.childrenOf(notebookId);
    if (childIds.isEmpty) return const SizedBox.shrink();
    final byId = <String, NotebookView>{for (final n in notebooks) n.id: n};
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.l,
            AppSpacing.xs,
          ),
          child: Text(
            l10n.notebookChildTitle,
            style: theme.textTheme.titleSmall,
          ),
        ),
        for (final childId in childIds)
          if (byId[childId] != null)
            ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: AppSpacing.l,
                end: AppSpacing.s,
              ),
              leading: FaIcon(byId[childId]!.icon.data, size: 20),
              title: Text(byId[childId]!.name),
              trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 16),
              onTap: () => onOpen(childId),
            ),
      ],
    );
  }
}
