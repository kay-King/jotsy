import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';

part 'diary_toggle_block_editor.dart';
part 'diary_toggle_block_preview.dart';

// v0.10.0 折叠块（toggle list）：标题行 + 可收起的子内容。
//
// 当前 appflowy_editor 版本（01eccc6）没有原生 toggle block，这里自定义实现。
// 块类型：`diaryToggleBlock`，属性：`collapsed` (bool)。
//
// 输入：块上下文的节点——标题文字记在 `data.delta`，收起状态记在
// `data.collapsed`，子内容记在节点的 children 里。
// 输出：编辑器里渲染“箭头 + 可编辑标题行”，点箭头经事务翻转 `collapsed`；
// 预览页里只读渲染，点箭头只改本地展开状态。
// 副作用：插入与箭头点按各占一步可撤销事务；收起时 children 保留在文档里，
// 只是不进渲染树。
//
// AppFlowy 迁移说明：标题文字走 AppFlowyRichText——基础样式取编辑器级的
// textStyleConfiguration（日记正文排版：字体/字号/行距/颜色），日记行内
// 属性（文字色/背景色/字号档位/链接）由编辑器级的 textSpanDecorator 叠加，
// 这里不另写样式。子块渲染复用编辑器自带的 NestedListWidget +
// renderer.buildList，与待办列表的嵌套一致。
//
// 文件拆分：编辑器组件见 diary_toggle_block_editor.dart，只读预览见
// diary_toggle_block_preview.dart；公共 API 都从本文件导出。

/// 块类型标识。
const String kDiaryToggleBlockType = 'diaryToggleBlock';

/// 是否收起的属性 key。
const String kDiaryToggleCollapsedKey = 'collapsed';

/// 在光标处插入折叠块。
///
/// 标题行为空（光标落在标题开头，用户直接打字写标题）；子内容用户后续经
/// 缩进加入。无选区时插到文档末尾（与表格插入同口径）。
Future<void> insertDiaryToggleBlock(EditorState editorState) async {
  final node = Node(
    type: kDiaryToggleBlockType,
    attributes: <String, dynamic>{
      kDiaryToggleCollapsedKey: false,
      // 本版本 Node 没有 delta 构造参数，delta 记在 attributes['delta']；
      // validate 要求 delta 非空，空标题也要占一个空 delta。
      blockComponentDelta: (Delta()..insert('')).toJson(),
    },
    children: <Node>[],
  );
  final transaction = editorState.transaction;
  final selection = editorState.selection?.normalized;
  final Path insertPath;
  if (selection == null) {
    insertPath = [editorState.document.root.children.length];
  } else {
    final anchor = editorState.getNodeAtPath(selection.end.path);
    insertPath = anchor == null
        ? [editorState.document.root.children.length]
        : anchor.path.next;
  }
  transaction
    ..insertNode(insertPath, node)
    ..afterSelection = Selection.collapsed(Position(path: insertPath));
  await editorState.apply(transaction);
}
