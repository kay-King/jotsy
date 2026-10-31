import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/precise_time_formatter.dart';
import '../../../../utils/relative_time_formatter.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../models/time_capsule.dart';
import '../../viewmodels/diary_text_appearance.dart';
import 'diary_appflowy_preview.dart';

/// 预览页正文：只读的 AppFlowy 块渲染，没有可见内容时显示空正文提示
///（可关）。
///
/// 首行缩进只在渲染层垫出来（[diaryFirstLineIndentWidth]）：段落首个文字
/// span 前插定宽占位，原文 Delta 不动，待办勾选经 EditorState 事务写回。
///
/// 是否有正文不能只看 contentText（纯文本镜像），否则“仅图片正文”会被误判
/// 为空：统一按文档是否存在可见内容判断（见
/// [diaryAppFlowyDocumentHasVisibleContent]），图片、视频与其他嵌入都算
/// 正文。正文样式必须在正文位置生成（[DiaryAppFlowyPreview]），这里在
/// Scaffold 之下，取得到主题的正文样式；自定义正文颜色经 [DefaultTextStyle]
/// 传给渲染层（段落、标题都从它取色），字号与行距仍只来自正文排版设置。
class DiaryPreviewBody extends StatelessWidget {
  const DiaryPreviewBody({
    super.key,
    required this.document,
    required this.appearance,
    required this.onOpenImage,
    this.onToggleTodo,
    this.showEmptyHint = true,
    this.textSelection = true,
    this.longImageMode = DiaryPreviewLongImageMode.fold,
    this.textColor,
    this.onOpenDiary,
  });

  final Document document;
  final DiaryTextAppearance appearance;

  /// 点按正文图片：来源与点按处抓取的共享元素。
  final void Function(String source, ImageViewerHero? hero) onOpenImage;

  /// 待办勾选变化：调用方把 `checked` 写回 EditorState；null 时复选框只读
  ///（对应旧版 `todoToggle` 为 false）。
  final void Function(Node node, bool checked)? onToggleTodo;

  final bool showEmptyHint;

  /// 允许长按选择文字。
  final bool textSelection;

  /// 正文长图折叠还是完整显示。
  final DiaryPreviewLongImageMode longImageMode;

  /// 通过对比度检查的自定义正文颜色；null 用主题正文色。
  final Color? textColor;

  /// 点按日记链接（`diary://` 行内链接 / 日记卡片 / 反向链接）：按业务 id
  /// 打开那篇日记；null 时不可点按。
  final ValueChanged<String>? onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final hasVisibleContent = diaryAppFlowyDocumentHasVisibleContent(document);
    Widget body;
    if (hasVisibleContent) {
      body = DiaryAppFlowyPreview(
        document: document,
        appearance: appearance,
        onOpenImage: onOpenImage,
        onToggleTodo: onToggleTodo,
        textSelection: textSelection,
        longImageMode: longImageMode,
        onOpenDiary: onOpenDiary,
      );
    } else if (showEmptyHint) {
      body = Text(
        context.l10n.autoT0119,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: textColor),
      );
    } else {
      return const SizedBox.shrink();
    }
    final color = textColor;
    if (color == null) {
      return body;
    }
    return DefaultTextStyle.merge(
      style: TextStyle(color: color),
      child: body,
    );
  }
}

/// “最后编辑于 …”（没编辑过的日记返回 null，不占位）。
String? diaryPreviewEditedLabel(
  AppLocalizations l10n,
  Diary diary,
  DiaryPreviewEditedFormat format,
) {
  if (diary.updatedAt.isAtSameMomentAs(diary.createdAt)) {
    return null;
  }
  final now = DateTime.now();
  final updated = diary.updatedAt;
  final time = switch (format) {
    DiaryPreviewEditedFormat.precise => PreciseTimeFormatter.format(
      target: updated,
      now: now,
      l10n: l10n,
    ),
    DiaryPreviewEditedFormat.relative => RelativeTimeFormatter.formatUpdatedAt(
      updatedAt: updated,
      now: now,
      l10n: l10n,
    ),
    DiaryPreviewEditedFormat.full => l10n.diaryCardDateWithTime(
      l10n.formatFullDate(updated.toLocal()),
      DateFormat.Hm(l10n.localeName).format(updated.toLocal()),
    ),
  };
  return '${l10n.autoT0118} $time';
}

/// 页尾的“最后编辑于”一行。
class DiaryPreviewEditedLine extends StatelessWidget {
  const DiaryPreviewEditedLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 已解封时间胶囊顶部的提示卡（未解封或不是胶囊时不占位）。
class DiaryPreviewCapsuleInsight extends StatelessWidget {
  const DiaryPreviewCapsuleInsight({
    super.key,
    required this.capsuleState,
    required this.moodEmoji,
  });

  final TimeCapsuleState capsuleState;
  final String? moodEmoji;

  @override
  Widget build(BuildContext context) {
    if (!capsuleState.isCapsule || capsuleState.isLocked) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final mood = moodEmoji;
    final message = mood != null
        ? l10n.timeCapsuleUnlockedInsight(mood)
        : l10n.timeCapsuleUnlockedInsightNoMood;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FaIcon(
            FontAwesomeIcons.unlockKeyhole,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
