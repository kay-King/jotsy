import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../controllers/notebook_editor_controller.dart';
import '../models/notebook_tree.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';

/// 父日记本（只在手动本编辑页出现）：把这本挂到另一本手动本下面做子本。
///
/// 点行弹出底部面板选父本（含“顶级日记本”移到顶级）。候选只列手动本，
/// 排除自己与自己的后代（防环）；面板里子本缩进显示层级。
class NotebookEditorParentSection extends ConsumerWidget {
  const NotebookEditorParentSection({super.key, required this.controller});

  final NotebookEditorController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notebooks = ref.watch(notebooksProvider).value;
    final parentId = controller.parentId;
    String parentName = l10n.notebookParentTopLevel;
    if (parentId != null && notebooks != null) {
      for (final n in notebooks) {
        if (n.id == parentId) {
          parentName = n.name;
          break;
        }
      }
    }
    return SettingsCardGroup(
      title: l10n.notebookParentLabel,
      children: <Widget>[
        ListTile(
          leading: const FaIcon(FontAwesomeIcons.sitemap, size: 20),
          title: Text(parentName),
          subtitle: Text(l10n.notebookParentHint),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 16),
          onTap: notebooks == null
              ? null
              : () => _pick(context, ref, notebooks),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<NotebookView> notebooks,
  ) async {
    final l10n = context.l10n;
    // 候选：手动本，排除自己与后代（防环）。新建时 id 为 null，不过滤自己。
    final selfId = controller.notebookId;
    final tree = NotebookTree(<NotebookNode>[
      for (final n in notebooks)
        if (n.isManual) NotebookNode(n.id, n.row.parentId),
    ]);
    final excluded = <String>{
      if (selfId != null) ...<String>{selfId, ...tree.descendantsOf(selfId)},
    };
    final candidates = <NotebookView>[
      for (final n in notebooks)
        if (n.isManual && !excluded.contains(n.id)) n,
    ];
    final result = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Text(
                  l10n.notebookParentPick,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.house, size: 20),
                title: Text(l10n.notebookParentTopLevel),
                selected: controller.parentId == null,
                // 空字符串表示“顶级”：pop(null) 是点遮罩/返回取消，须区分。
                onTap: () => Navigator.of(context).pop(''),
              ),
              const Divider(height: 1),
              for (final candidate in candidates)
                _ParentRow(
                  notebook: candidate,
                  depth: tree.ancestorsOf(candidate.id).length,
                  selected: controller.parentId == candidate.id,
                  onTap: () => Navigator.of(context).pop<String>(candidate.id),
                ),
              SizedBox(
                height: AppSpacing.l + MediaQuery.paddingOf(context).bottom,
              ),
            ],
          ),
        );
      },
    );
    // pop('') 为选顶级，pop(id) 为选父本，pop(null)（点遮罩/返回）为取消。
    if (result == null) return;
    controller.parentId = result.isEmpty ? null : result;
  }
}

/// 候选行：按层级缩进，显示名称。
class _ParentRow extends StatelessWidget {
  const _ParentRow({
    required this.notebook,
    required this.depth,
    required this.selected,
    required this.onTap,
  });

  final NotebookView notebook;
  final int depth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: AppSpacing.l + depth * 24.0,
        end: AppSpacing.l,
      ),
      leading: FaIcon(notebook.icon.data, size: 20),
      title: Text(notebook.name),
      selected: selected,
      onTap: onTap,
    );
  }
}
