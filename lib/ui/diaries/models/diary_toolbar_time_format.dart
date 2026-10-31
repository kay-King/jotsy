import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 将当前系统时间插入到编辑器当前选区。
///
/// 如果用户已选中文字，则替换选区；如果编辑器暂时没有有效选区，则插入到文档末尾。
/// 替换后光标停在插入文本之后（与原来一致）。
Future<void> insertDiaryToolbarCurrentTime(
  BuildContext context,
  EditorState editorState, {
  String? formatPattern,
}) async {
  final now = DateTime.now();
  final insertedText = formatDiaryToolbarCurrentTime(
    context.l10n,
    now,
    customPattern: formatPattern,
  );
  final transaction = editorState.transaction;
  final selection = editorState.selection;
  if (selection == null) {
    _insertAtDocumentEnd(transaction, editorState.document, insertedText);
  } else {
    final nodes = editorState.getNodesInSelection(selection);
    if (nodes.isEmpty) {
      _insertAtDocumentEnd(transaction, editorState.document, insertedText);
    } else {
      // 首个节点写入时间文本，其余节点清空选区内容：与原来整段替换选区的
      // 效果一致（原来是按文档偏移整段替换）。
      final texts = List<String>.filled(nodes.length, '');
      texts[0] = insertedText;
      transaction.replaceTexts(nodes, selection, texts);
      // 多节点时 replaceTexts 会把光标收到末节点行首；统一改到插入文本之后。
      final normalized = selection.normalized;
      transaction.afterSelection = Selection.collapsed(
        Position(
          path: normalized.start.path,
          offset: normalized.startIndex + insertedText.length,
        ),
      );
    }
  }
  await editorState.apply(transaction);
}

/// 没有有效选区时：把文本追加到最后一个文字块的末尾；文档里没有文字块时
/// （空文档）新起一个段落写入。
void _insertAtDocumentEnd(
  Transaction transaction,
  Document document,
  String text,
) {
  Node? lastText;
  void visit(Node node) {
    if (node.delta != null) lastText = node;
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(document.root);
  final target = lastText;
  if (target == null) {
    final children = document.root.children;
    final path = children.isEmpty ? [0] : children.last.path.next;
    transaction.insertNode(path, paragraphNode(text: text));
    transaction.afterSelection = Selection.collapsed(
      Position(path: path, offset: text.length),
    );
    return;
  }
  final length = target.delta!.length;
  transaction.insertText(target, length, text);
  transaction.afterSelection = Selection.collapsed(
    Position(path: target.path, offset: length + text.length),
  );
}

const String kDefaultDiaryToolbarCurrentTimeFormat = 'M月d日 HH:mm';

String formatDiaryToolbarCurrentTime(
  AppLocalizations l10n,
  DateTime value, {
  String? customPattern,
}) {
  final local = value.toLocal();
  final normalizedPattern = customPattern?.trim();
  if (normalizedPattern != null && normalizedPattern.isNotEmpty) {
    return DateFormat(normalizedPattern, l10n.localeName).format(local);
  }
  return DateFormat(kDefaultDiaryToolbarCurrentTimeFormat, 'zh').format(local);
}

bool isValidDiaryToolbarCurrentTimeFormat(
  AppLocalizations l10n,
  String formatPattern,
) {
  final normalized = formatPattern.trim();
  if (normalized.isEmpty) {
    return true;
  }
  try {
    formatDiaryToolbarCurrentTime(
      l10n,
      DateTime(2026, 3, 11, 21, 30),
      customPattern: normalized,
    );
    return true;
  } catch (_) {
    return false;
  }
}
