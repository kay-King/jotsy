import 'package:appflowy_editor/appflowy_editor.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_code_language_tracker.dart';
import '../../models/diary_code_block/diary_code_language.dart';

// 代码块标题栏的文案：显示的语言名与复制按钮的读屏标签。
//
// 输入：代码块节点、自动识别开关、语言识别状态与文案。
// 输出：标题栏的语言名与复制按钮的读屏标签。
// 副作用：会经 [DiaryCodeLanguageTracker.languageFor] 触发/读取识别（幂等，
// 有缓存）：标题栏与正文构建顺序不确定，首帧可能先于高亮，此时同步识别一次，
// 保证标题栏与高亮用的是同一份结果。
//
// AppFlowy 迁移说明：原来这里还从 Quill 的渲染树（RenderEditor）读出每个
// 代码块标题栏的位置；AppFlowy 时代标题栏是块组件里的 widget，不再需要
// 从渲染树收集几何，只剩文案逻辑。

/// 标题栏的语言名与复制按钮的读屏标签：
/// - 明确指定的语言：语言名（“C/C++”“Python”…）；
/// - 纯文本：“纯文本”；
/// - 未指定：开启自动识别且认出来了取识别结果的名称，否则“代码”。
({String label, String semanticsLabel}) describeDiaryCodeBlockHeader(
  Node block, {
  required bool autoDetect,
  required DiaryCodeLanguageTracker tracker,
  required AppLocalizations l10n,
}) {
  final choice = DiaryCodeLanguageChoice.fromAttributeValue(
    block.attributes[kDiaryBlockLanguageKey],
  );
  if (choice.isPlain) {
    final label = l10n.codeBlockLanguagePlain;
    return (label: label, semanticsLabel: l10n.codeBlockCopySemantics(label));
  }
  final text = block.delta?.toPlainText() ?? '';
  final id =
      choice.languageId ??
      (autoDetect ? tracker.languageFor(block, text) : null);
  final name = id == null ? null : diaryCodeLanguageById(id)?.name;
  if (name == null) {
    // 读屏不念“复制 代码 代码”，直接念按钮名。
    return (
      label: l10n.codeBlockLabelGeneric,
      semanticsLabel: l10n.codeBlockCopy,
    );
  }
  return (label: name, semanticsLabel: l10n.codeBlockCopySemantics(name));
}
