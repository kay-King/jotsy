import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_appflowy.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_appflowy_preview.dart';

/// 发布页的标题与正文预览（只读），与编辑页、预览页同一套正文排版，所见即
/// 发布后的样子。
///
/// 正文在发布页不会变：文档解析与“有无可见内容”的判断都只在创建时算一次；
/// 只有正文排版设置变化（监听 diaryTextAppearanceProvider）才重建。待办
/// 复选框只读（与之前只读 Quill 的 `checkBoxReadOnly` 默认跟随 readOnly
/// 一致），图片点按不接菜单（旧的图片选项菜单依赖 Quill，随编辑器 UI
/// 迁移再接入）。
class PublishDiaryPreview extends ConsumerStatefulWidget {
  const PublishDiaryPreview({super.key, required this.draft});

  final NewDiaryDraft draft;

  @override
  ConsumerState<PublishDiaryPreview> createState() =>
      _PublishDiaryPreviewState();
}

class _PublishDiaryPreviewState extends ConsumerState<PublishDiaryPreview> {
  late final Document _document;
  late final bool _hasVisibleContent;

  @override
  void initState() {
    super.initState();
    // 正文不是合法格式时解码器自己降级为空文档，页面总能打开。
    _document = diaryDocumentFromStoredJson(widget.draft.contentDocJson);
    // 不能只看纯文本镜像（contentText），纯图片正文在镜像里会为空。统一按
    // 文档可见内容判断，图片/嵌入也算正文内容。
    _hasVisibleContent = diaryAppFlowyDocumentHasVisibleContent(_document);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final theme = Theme.of(context);
    final title = widget.draft.title.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.isEmpty ? context.l10n.autoT0095 : title,
            style: appearance.titleStyle(
              theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_hasVisibleContent)
            Text(context.l10n.autoT0139, style: theme.textTheme.bodyMedium)
          else
            DiaryAppFlowyPreview(document: _document, appearance: appearance),
        ],
      ),
    );
  }
}
