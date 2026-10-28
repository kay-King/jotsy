import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../pages/edit_diary_page.dart';
import '../pages/simple_composer_page.dart';
import 'simple_composer_controller.dart';

/// 打开一篇日记的编辑器后返回的结果。
enum DiaryEditEntryOutcome {
  /// 编辑器里保存了改动（简洁模式保存，或标准编辑器返回但没删）。
  saved,

  /// 在编辑器里删除了这篇日记。
  deleted,

  /// 没打开编辑器（选择框点了取消），或简洁模式没保存就退出了。
  cancelled,
}

/// 打开一篇日记的编辑器。
///
/// 简洁模式写过且内容还是纯文本时，先给简洁 / 完整选择；其余（标准模式
/// 写的，或标准模式改过后带了格式、超长、超图）直进标准编辑器。`detail`
/// 为空时（详情还没查回来）直接走标准编辑器。
///
/// 这是预览页与时间线页“...”菜单共用的流程：选择框、简洁编辑器、标准
/// 编辑器的打开方式与返回值口径都在这里，调用方只按返回值决定之后的事——
/// 时间线是流式查询，改动自动刷新，忽略返回值即可；预览页按返回值刷新
/// 详情，或按已删除退出。
Future<DiaryEditEntryOutcome> openDiaryEditorForDetail(
  BuildContext context, {
  required String diaryId,
  DiaryWithTags? detail,
}) async {
  final simpleContent =
      detail != null &&
          SimpleComposerController.isSimpleComposerEntry(detail.diary.metadata)
      ? SimpleComposerController.tryExtractSimpleContent(detail.diary.content)
      : null;
  if (simpleContent != null && detail != null) {
    final choice = await _showEditChoice(context);
    if (!context.mounted || choice == null) {
      return DiaryEditEntryOutcome.cancelled;
    }
    if (choice == _EditChoice.simple) {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => SimpleComposerPage(
            editDiaryId: detail.diary.diaryId,
            editTagIds: detail.tags.map((tag) => tag.id).toList(),
            initialText: simpleContent.text,
            initialImages: simpleContent.images,
          ),
        ),
      );
      if (!context.mounted) {
        return DiaryEditEntryOutcome.cancelled;
      }
      return saved == true
          ? DiaryEditEntryOutcome.saved
          : DiaryEditEntryOutcome.cancelled;
    }
    // 选了完整编辑，往下走标准编辑器。
  }
  // 编辑页里删除日记后以 true 返回。经发布页保存时编辑页以日记 id
  // （String）结束，所以结果类型放宽为 Object?。
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (BuildContext context) {
        return EditDiaryPage(
          diaryId: diaryId,
          entryMode: EditDiaryEntryMode.edit,
        );
      },
    ),
  );
  if (!context.mounted) {
    return DiaryEditEntryOutcome.cancelled;
  }
  return result == true
      ? DiaryEditEntryOutcome.deleted
      : DiaryEditEntryOutcome.saved;
}

/// 重新编辑时的选择框（只在简洁模式写过的那篇上出现）：简洁 / 完整。
/// 点外面或返回即取消（null），不打开编辑器。
Future<_EditChoice?> _showEditChoice(BuildContext context) {
  final l10n = context.l10n;
  final colorScheme = Theme.of(context).colorScheme;
  Widget option({
    required _EditChoice value,
    required String title,
    required String desc,
  }) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  return showDialog<_EditChoice>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.simpleComposerEditChoiceTitle),
      children: <Widget>[
        option(
          value: _EditChoice.simple,
          title: l10n.simpleComposerEditChoiceSimple,
          desc: l10n.simpleComposerEditChoiceSimpleDesc,
        ),
        option(
          value: _EditChoice.full,
          title: l10n.simpleComposerEditChoiceFull,
          desc: l10n.simpleComposerEditChoiceFullDesc,
        ),
      ],
    ),
  );
}

enum _EditChoice { simple, full }
