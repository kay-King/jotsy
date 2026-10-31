import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';

import 'diary_blocks_codec.dart';
import 'diary_blocks_schema.dart';

/// AppFlowy Document 与块文档存储格式的互转。
///
/// 块文档格式与 AppFlowy `Document.toJson()` 同构（见 diary_blocks_schema.dart），
/// 因此新保存的内容可直接用 `Document.toJson()`；读取时兼容旧格式
/// （Delta List、Legacy Quill Document Map），经 `decodeStoredDiaryBlocks`
/// 归一化后再转成 AppFlowy Document。

/// 从存储的 JSON 字符串解析出 AppFlowy Document。
///
/// 兼容三种格式：
/// 1. 块文档格式 `{"document": {...}}`（新格式，与 AppFlowy 同构）
/// 2. Delta List（简洁编辑器旧格式）
/// 3. Legacy Quill Document Map
/// 解析失败时返回空文档。
Document diaryDocumentFromStoredJson(String raw) {
  try {
    final normalized = decodeStoredDiaryBlocks(raw);
    return Document.fromJson(normalized);
  } catch (_) {
    return Document.blank();
  }
}

/// 把 AppFlowy Document 序列化为存储用的 JSON 字符串。
///
/// 输出即块文档格式（与 `Document.toJson()` 同构），可直接存入
/// `contentDocJson` 字段。
String diaryDocumentToStoredJson(Document document) {
  return jsonEncode(document.toJson());
}

/// 从 EditorState 导出存储用的 JSON 字符串。
String diaryEditorStateToStoredJson(EditorState editorState) {
  return diaryDocumentToStoredJson(editorState.document);
}

/// 用存储的 JSON 创建 EditorState（编辑器打开日记时用）。
EditorState diaryEditorStateFromStoredJson(String raw) {
  final document = diaryDocumentFromStoredJson(raw);
  return EditorState(document: document);
}

/// 空文档的存储 JSON（新建日记时用）。
String diaryBlankDocumentJson() {
  return jsonEncode(Document.blank().toJson());
}

/// 从 AppFlowy Document 提取纯文本（用于 contentText 镜像、搜索等）。
///
/// 每个块一行，媒体与分隔线占一个空行；与 `diaryBlocksToPlainText` 口径一致。
String diaryDocumentToPlainText(Document document) {
  final buffer = StringBuffer();
  for (final node in document.root.children) {
    _writeNodePlainText(node, buffer);
  }
  var text = buffer.toString();
  while (text.endsWith('\n')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

void _writeNodePlainText(Node node, StringBuffer buffer) {
  final type = node.type;
  if (kDiaryTextBlockTypes.contains(type)) {
    final delta = node.delta;
    if (delta != null) {
      buffer.write(delta.toPlainText());
    }
    // 代码块的 delta 可能不以换行结尾，统一加换行分隔。
    if (!buffer.toString().endsWith('\n')) {
      buffer.write('\n');
    }
  } else if (type == kDiaryBlockDivider) {
    buffer.write('\n');
  } else {
    // 图片、视频、音频、附件等媒体块：占一个空行。
    buffer.write('\n');
  }
  for (final child in node.children) {
    _writeNodePlainText(child, buffer);
  }
}

/// 判断 Document 是否为空（无内容）。
bool diaryDocumentIsEmpty(Document document) {
  if (document.root.children.isEmpty) return true;
  if (document.root.children.length == 1) {
    final node = document.root.children.first;
    if (node.type == kDiaryBlockParagraph) {
      final delta = node.delta;
      if (delta == null || delta.isEmpty) {
        return node.children.isEmpty;
      }
      final text = delta.toPlainText().trim();
      return text.isEmpty && node.children.isEmpty;
    }
  }
  return false;
}
