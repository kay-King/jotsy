import 'package:appflowy_editor/appflowy_editor.dart';

import '../../../core/services/text_process_actions_service.dart';
import 'diary_editor_selection.dart';

/// 日记正文选区菜单里“其他应用的文字处理”（Android `ACTION_PROCESS_TEXT`：
/// 翻译、改写等）的执行与回写。
///
/// - 输入：正文 [EditorState]、动作 id，以及点按那一刻的选区 [selection] 与
///   它的纯文本 [text]（由菜单在收起前取下：收起菜单不改选区，但先取更稳妥）。
/// - 流程：把 [text] 交给对方应用（可编辑正文允许它回写，只读正文不允许）→
///   等对方返回 → 满足全部条件才以纯文本替换选区：返回非 null 且与原文不同、
///   正文可编辑、编辑器未销毁、选区仍等于点按时的选区且其中文字也没变（对方
///   应用开着期间用户可能回来改过正文，或自动保存 / 同步换了内容，这时写回会
///   覆盖到别处）。
/// - 输出：是否替换了选区。替换走 [insertDiaryEditorPlainText]（与粘贴原文
///   同一路径，不做 Markdown 转换），一步撤销。
/// - 失败：对方取消、没有回写或通道出错时 [TextProcessActionsService.process]
///   返回 null，正文不动。
Future<bool> runDiaryTextProcessAction(
  EditorState editorState, {
  required String actionId,
  required Selection selection,
  required String text,
  required bool readOnly,
  TextProcessActionsService? service,
}) async {
  final result = await (service ?? TextProcessActionsService.instance).process(
    actionId,
    text,
    readOnly: readOnly,
  );
  if (result == null || result == text || readOnly) return false;
  if (editorState.isDisposed) return false;
  if (editorState.selection?.normalized != selection.normalized ||
      diaryEditorSelectedPlainText(editorState) != text) {
    return false;
  }
  await insertDiaryEditorPlainText(editorState, result, editable: true);
  return true;
}
