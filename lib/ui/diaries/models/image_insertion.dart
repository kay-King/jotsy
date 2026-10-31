import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';

/// Inserts one or more image blocks into the diary document at the current selection.
///
/// Ensures each image occupies its own block line, separates multiple images
/// with clean newlines, and positions the cursor on a new line after insertion.
/// A non-collapsed selection is deleted first, matching the previous behavior.
///
/// AppFlowy 迁移说明：图片是独立块节点（[kDiaryBlockImage]），天然独占一行，
/// 不需要原来那样手动插换行分隔、也不需要 `skipRequestKeyboard`（那是
/// QuillController 的专有行为）。
Future<void> insertDiaryImages({
  required EditorState editorState,
  required List<String> imagePaths,
  Selection? selection,
}) async {
  final validPaths = imagePaths
      .where((path) => path.trim().isNotEmpty)
      .toList();
  if (validPaths.isEmpty) return;

  final transaction = editorState.transaction;
  final normalized = (selection ?? editorState.selection)?.normalized;

  // 插入锚点：选区末端所在节点之后；没有选区时文档末尾。
  final Path insertPath;
  if (normalized == null) {
    final children = editorState.document.root.children;
    insertPath = children.isEmpty ? [0] : children.last.path.next;
  } else {
    if (!normalized.isCollapsed) {
      // 原来是 replaceText(start, len, '') 删掉选区内容。
      final nodes = editorState.getNodesInSelection(normalized);
      if (nodes.isNotEmpty) {
        transaction.replaceTexts(
          nodes,
          normalized,
          List<String>.filled(nodes.length, ''),
        );
      }
    }
    final anchor = editorState.getNodeAtPath(normalized.end.path);
    insertPath =
        anchor == null
            ? [editorState.document.root.children.length]
            : anchor.path.next;
  }

  var path = insertPath;
  for (final imagePath in validPaths) {
    transaction.insertNode(
      path,
      Node(
        type: kDiaryBlockImage,
        attributes: <String, dynamic>{kDiaryBlockUrlKey: imagePath},
      ),
    );
    path = path.next;
  }

  // 光标落在图片后的新空行。
  transaction.insertNode(path, paragraphNode());
  transaction.afterSelection = Selection.collapsed(
    Position(path: path, offset: 0),
  );
  await editorState.apply(transaction);
}
