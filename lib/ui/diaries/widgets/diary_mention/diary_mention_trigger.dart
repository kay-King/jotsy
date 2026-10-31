import 'package:appflowy_editor/appflowy_editor.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// @ 提及与 / 块菜单的触发器解析、href 编解码与选中后的写入。
///
/// 输入：光标所在文本节点的光标前文字；输出：触发器或 null。
/// 纯逻辑，不依赖 BuildContext，可直接单测。

/// 日记链接的 href scheme（写在行内 `href` 属性里）：
/// - `diary://<diaryId>`：链到一篇日记；
/// - `notebook://<notebookId>`：链到一本日记本。
const String kDiaryLinkSchemeDiary = 'diary';
const String kDiaryLinkSchemeNotebook = 'notebook';

/// 日记的 href：`diary://<diaryId>`。
String diaryLinkHrefForDiary(String diaryId) =>
    '$kDiaryLinkSchemeDiary://$diaryId';

/// 日记本的 href：`notebook://<notebookId>`。
String diaryLinkHrefForNotebook(String notebookId) =>
    '$kDiaryLinkSchemeNotebook://$notebookId';

/// 解析日记链接 href；不是日记链接时返回 null。
///
/// 返回的 record 里只有一个字段非空。
({String? diaryId, String? notebookId})? parseDiaryLinkHref(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme == kDiaryLinkSchemeDiary) {
    return (diaryId: uri.host, notebookId: null);
  }
  if (uri.scheme == kDiaryLinkSchemeNotebook) {
    return (diaryId: null, notebookId: uri.host);
  }
  return null;
}

/// 触发器种类。
enum MentionTriggerKind {
  /// `@`：提及日记或日记本，选中后插入行内链接。
  mention,

  /// `/`：块菜单（目前只有“日记卡片”一项）。
  slash,
}

/// 光标前解析出的触发器。
class MentionTrigger {
  const MentionTrigger({
    required this.kind,
    required this.query,
    required this.triggerOffset,
  });

  final MentionTriggerKind kind;

  /// `@` 或 `/` 之后、光标之前的文字（不过滤空格，由解析保证不含）。
  final String query;

  /// `@` 或 `/` 在节点文字中的偏移。
  final int triggerOffset;
}

/// 从光标前的节点文字解析触发器；没有触发器时返回 null。
///
/// 从光标往前扫到第一个 `@` 或 `/` 为止：
/// - `@`：前面是行首或空白才算触发（`a@` 这种不算，避免邮箱被劫持）；
/// - `/`：前面只能是行首或空白（`https://`、`a/b` 不算）；
/// - 触发器与光标之间不能有空白或换行。
MentionTrigger? parseMentionTrigger(String textBeforeCaret) {
  var triggerIndex = -1;
  var isSlash = false;
  for (var i = textBeforeCaret.length - 1; i >= 0; i--) {
    final char = textBeforeCaret[i];
    if (char == '@') {
      triggerIndex = i;
      break;
    }
    if (char == '/') {
      triggerIndex = i;
      isSlash = true;
      break;
    }
    // 空白、换行或标点分隔：触发器不可能跨过它。
    if (_isTriggerBoundary(char)) break;
  }
  if (triggerIndex < 0) return null;
  if (triggerIndex > 0 &&
      !_isTriggerBoundary(textBeforeCaret[triggerIndex - 1])) {
    return null;
  }
  return MentionTrigger(
    kind: isSlash ? MentionTriggerKind.slash : MentionTriggerKind.mention,
    query: textBeforeCaret.substring(triggerIndex + 1),
    triggerOffset: triggerIndex,
  );
}

bool _isTriggerBoundary(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '　';

/// 选中候选后：删掉 `@query`，在原位置插入带 href 的标题文字。
///
/// [displayText] 为候选的显示文字（日记标题或日记本名称），[href] 为
/// [diaryLinkHrefForDiary] / [diaryLinkHrefForNotebook] 生成的链接。
/// 插入后光标停在链接文字之后（`insertText` 已设置 afterSelection）。
Future<void> applyMentionPick({
  required EditorState editorState,
  required Node node,
  required MentionTrigger trigger,
  required String displayText,
  required String href,
}) async {
  final length = node.delta?.length ?? 0;
  final deleteLength = trigger.query.length + 1; // `@` 本身 + query
  if (trigger.triggerOffset < 0 ||
      trigger.triggerOffset + deleteLength > length) {
    return;
  }
  final transaction = editorState.transaction;
  transaction.deleteText(node, trigger.triggerOffset, deleteLength);
  transaction.insertText(
    node,
    trigger.triggerOffset,
    displayText,
    attributes: <String, dynamic>{kDiaryInlineHref: href},
  );
  await editorState.apply(transaction);
}
