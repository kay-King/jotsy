import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../providers/diary_detail_provider.dart';
import 'diary_link_card.dart';
import 'diary_link_card_view.dart';

/// 编辑器内的日记卡片块组件：实时读被链日记的标题 / 日期 / 摘要 / 封面。
///
/// 点按卡片弹出菜单：打开日记、删除卡片（菜单项 ≤4 个单行文字，用
/// [ExpressiveMenuAnchor]，见 AGENTS.md）。
class DiaryLinkCardBlockComponentBuilder extends BlockComponentBuilder {
  DiaryLinkCardBlockComponentBuilder({super.configuration, this.onOpenDiary});

  /// 点按“打开日记”：调用方按业务 id 打开预览页。
  final ValueChanged<String>? onOpenDiary;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryLinkCardBlockWidget(
      key: node.key,
      node: node,
      onOpenDiary: onOpenDiary,
    );
  }
}

class _DiaryLinkCardBlockWidget extends BlockComponentStatelessWidget {
  const _DiaryLinkCardBlockWidget({
    super.key,
    required super.node,
    required this.onOpenDiary,
    super.configuration = const BlockComponentConfiguration(),
  });

  final ValueChanged<String>? onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final diaryId = diaryLinkCardDiaryId(node);
    if (diaryId == null) return const SizedBox.shrink();
    // 删除卡片需要 editorState：与图片块一致，经 AppFlowyEditor 祖先取。
    final editorState = context
        .findAncestorWidgetOfExactType<AppFlowyEditor>()
        ?.editorState;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final l10n = context.l10n;
          final detailAsync = ref.watch(diaryDetailProvider(diaryId));
          if (detailAsync.isLoading) {
            // 本地库一帧即回，不转菊花，留占位避免布局跳动。
            return const SizedBox(height: 76);
          }
          final diary = detailAsync.value?.diary;
          return ExpressiveMenuAnchor(
            menuChildren: <Widget>[
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.bookOpen),
                onPressed: () => onOpenDiary?.call(diaryId),
                child: Text(l10n.linkCardOpen),
              ),
              ExpressiveMenuItem(
                leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                destructive: true,
                onPressed: () => unawaited(_deleteCard(editorState)),
                child: Text(l10n.linkCardDelete),
              ),
            ],
            builder:
                (
                  BuildContext context,
                  ExpressiveMenuAnchorState menu,
                  Widget? _,
                ) => DiaryLinkCardView(
                  title: _title(l10n, diary?.title),
                  dateLabel: diary == null
                      ? null
                      : l10n.formatFullDate(diary.createdAt.toLocal()),
                  summary: diary?.contentText,
                  coverPath: diary?.cover,
                  missingLabel: l10n.linkCardMissing,
                  // 点卡片只弹菜单（打开 / 删除），不直接跳转，避免误触。
                  onTap: menu.toggle,
                ),
          );
        },
      ),
    );
  }

  static String? _title(AppLocalizations l10n, String? title) {
    if (title == null) return null;
    return title.trim().isEmpty ? l10n.autoT0033 : title;
  }

  Future<void> _deleteCard(EditorState? editorState) async {
    if (editorState == null) return;
    final transaction = editorState.transaction;
    transaction.deleteNode(node);
    await editorState.apply(transaction);
  }
}
