import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../widgets/expressive_menu/expressive_menu_anchor.dart';
import '../../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../providers/diary_comment_providers.dart';

/// 预览页正文下方的留言区（#95 本地改造版核心）。
///
/// 白卡 + 平铺行，走 Salt 风，不引入新控件风。能写留言、能看留言列表
/// （按时间升序）、自己的留言可删除（本应用是单人日记，全部留言都是自己
/// 的；编辑留后做）。只读写 [DiaryComments] 表，不碰日记表；导出、搜索、
/// 备份均不带留言。
///
/// 输入：日记业务 id；输出：留言卡片。设置页的样式预览不传真实日记，由
/// 调用方（[DiaryPreviewContent]）决定是否挂载本组件。
class DiaryPreviewCommentsSection extends ConsumerStatefulWidget {
  const DiaryPreviewCommentsSection({super.key, required this.diaryId});

  final String diaryId;

  @override
  ConsumerState<DiaryPreviewCommentsSection> createState() =>
      _DiaryPreviewCommentsSectionState();
}

class _DiaryPreviewCommentsSectionState
    extends ConsumerState<DiaryPreviewCommentsSection> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(appDatabaseProvider)
          .addDiaryComment(diaryId: widget.diaryId, content: content);
      _controller.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (error) {
      if (mounted) {
        await HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(
            content: Text(error.toString()),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _edit(DiaryCommentRow comment) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _EditCommentDialog(initialContent: comment.content),
    );
    if (saved == null || !mounted) {
      return;
    }
    final content = saved.trim();
    if (content.isEmpty || content == comment.content) {
      return;
    }
    await ref
        .read(appDatabaseProvider)
        .updateDiaryComment(
          diaryId: widget.diaryId,
          commentId: comment.commentId,
          content: content,
        );
  }

  Future<void> _delete(DiaryCommentRow comment) async {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.diaryCommentsDelete),
          content: Text(l10n.diaryCommentsDeleteConfirm),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref
        .read(appDatabaseProvider)
        .deleteDiaryComment(
          diaryId: widget.diaryId,
          commentId: comment.commentId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final commentsAsync = ref.watch(diaryCommentsProvider(widget.diaryId));
    final comments = commentsAsync.value ?? const <DiaryCommentRow>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FaIcon(
                FontAwesomeIcons.comment,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.diaryCommentsTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (comments.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${comments.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (commentsAsync.hasError)
            Text(
              commentsAsync.error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            )
          else if (comments.isEmpty)
            Text(
              l10n.diaryCommentsEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < comments.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 24,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              _commentRow(context, comments[i]),
            ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('diary-comment-input'),
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.diaryCommentsHint,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey<String>('diary-comment-send'),
                tooltip: l10n.diaryCommentsSend,
                onPressed: _controller.text.trim().isEmpty || _sending
                    ? null
                    : _send,
                icon: FaIcon(
                  FontAwesomeIcons.paperPlane,
                  size: 18,
                  color: _controller.text.trim().isEmpty || _sending
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commentRow(BuildContext context, DiaryCommentRow comment) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final created = comment.createdAt.toLocal();
    final time =
        '${l10n.formatFullDate(created)} '
        '${DateFormat.Hm(l10n.localeName).format(created)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(comment.content, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                time,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ExpressiveMenuAnchor(
          menuChildren: <Widget>[
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.pen),
              onPressed: () => _edit(comment),
              child: Text(l10n.diaryCommentsEdit),
            ),
            ExpressiveMenuItem(
              leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
              destructive: true,
              onPressed: () => _delete(comment),
              child: Text(l10n.diaryCommentsDelete),
            ),
          ],
          builder: (BuildContext context, ExpressiveMenuAnchorState menu, _) =>
              IconButton(
                tooltip: l10n.diaryCommentsEdit,
                visualDensity: VisualDensity.compact,
                onPressed: menu.open,
                icon: FaIcon(
                  FontAwesomeIcons.ellipsis,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
        ),
      ],
    );
  }
}

/// 编辑留言的对话框：自带 TextEditingController，关闭时自行 dispose，
/// 避免外部提前 dispose 导致动画期间报错。
class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initialContent});

  final String initialContent;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialContent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.diaryCommentsEdit),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
