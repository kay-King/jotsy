import 'package:appflowy_editor/appflowy_editor.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';

/// v0.10.0 日记卡片块：在正文里嵌入一篇日记的实时卡片（标题、日期、摘要、
/// 封面图），点按打开那篇日记。
///
/// 块类型：`diaryLinkCard`，属性：`diaryId`（String，被链日记的业务 id）。
/// 渲染只读被链日记的实时数据（标题改了卡片跟着变）；被链日记被删除时
/// 卡片显示“不存在”占位，不丢块。

/// 块类型标识。
const String kDiaryLinkCardBlockType = 'diaryLinkCard';

/// 被链日记的业务 id 属性 key。
const String kDiaryLinkCardDiaryIdKey = 'diaryId';

/// 被链日记的业务 id；类型不对或属性缺失时返回 null。
String? diaryLinkCardDiaryId(Node node) {
  if (node.type != kDiaryLinkCardBlockType) return null;
  final id = node.attributes[kDiaryLinkCardDiaryIdKey];
  return id is String && id.isNotEmpty ? id : null;
}

/// 构造日记卡片节点。
Node diaryLinkCardNode(String diaryId) => Node(
  type: kDiaryLinkCardBlockType,
  attributes: <String, dynamic>{kDiaryLinkCardDiaryIdKey: diaryId},
);

/// 在光标处插入日记卡片。
///
/// 光标在空段落上时直接用卡片替换这个空段落（`/` 菜单删掉 `/` 后正是
/// 这种情况），否则插在光标所在块之后；插入后光标停在卡片之后。
Future<void> insertDiaryLinkCardBlock(
  EditorState editorState, {
  required String diaryId,
}) async {
  final card = diaryLinkCardNode(diaryId);
  final selection = editorState.selection;
  if (selection == null) {
    final transaction = editorState.transaction;
    transaction.insertNode([editorState.document.root.children.length], card);
    await editorState.apply(transaction);
    return;
  }
  final node = editorState.getNodeAtPath(selection.start.path);
  final transaction = editorState.transaction;
  if (node != null &&
      node.type == kDiaryBlockParagraph &&
      (node.delta?.toPlainText().trim().isEmpty ?? true)) {
    // 空段落：卡片占它的位置（事务内后加的操作会自动相对前面的插入做
    // 路径变换，见 Transaction.add），原段落删掉，不留空行；光标停在
    // 卡片上（与官方 insertNodeAfterSelection 一致）。
    transaction
      ..insertNode(node.path, card)
      ..deleteNode(node)
      ..afterSelection = Selection.collapsed(Position(path: node.path));
    await editorState.apply(transaction);
    return;
  }
  final next = selection.start.path.next;
  transaction
    ..insertNode(next, card)
    ..afterSelection = Selection.collapsed(Position(path: next));
  await editorState.apply(transaction);
}
