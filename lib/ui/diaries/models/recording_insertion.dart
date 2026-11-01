import 'dart:convert' show jsonDecode;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';

/// Inserts an audio block at the captured body selection without deleting
/// selected prose.
///
/// AppFlowy 迁移说明：录音是独立块节点（[kDiaryBlockAudio]），插入即独占一行；
/// 块后自动跟一个可编辑的空段落（原来是手动补的换行），光标落在行首。
/// `skipRequestKeyboard` 是 QuillController 的专有行为，这里不需要。
Future<void> insertDiaryRecording({
  required EditorState editorState,
  required Selection selection,
  required DiaryAudioAttachment recording,
}) async {
  final transaction = editorState.transaction;
  final normalized = selection.normalized;
  final anchor = editorState.getNodeAtPath(normalized.end.path);
  final insertPath = anchor == null
      ? [editorState.document.root.children.length]
      : anchor.path.next;
  transaction.insertNode(
    insertPath,
    Node(type: kDiaryBlockAudio, attributes: _audioAttributes(recording)),
  );
  final paragraphPath = insertPath.next;
  transaction.insertNode(paragraphPath, paragraphNode());
  transaction.afterSelection = Selection.collapsed(
    Position(path: paragraphPath, offset: 0),
  );
  await editorState.apply(transaction);
}

/// 录音块的 data：与块文档 schema 一致，直接用 [DiaryAudioAttachment] 的字段
/// （path / durationMs / name / waveform），而不是 Quill 时代的 JSON 字符串。
Attributes _audioAttributes(DiaryAudioAttachment recording) {
  final decoded = jsonDecode(recording.encode());
  return Map<String, dynamic>.from(decoded as Map);
}
