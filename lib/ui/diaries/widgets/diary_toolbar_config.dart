import 'dart:async' show unawaited;
import 'dart:ui' show lerpDouble;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_paragraph_indent_editing.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_newline.dart';
import 'package:node_diary/ui/diaries/models/diary_divider_block.dart';
import 'package:node_diary/ui/diaries/models/diary_table_block.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_layout.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_time_format.dart';
import 'package:node_diary/ui/diaries/widgets/diary_callout_block/diary_callout_block.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toggle_block/diary_toggle_block.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

/// 工具按钮的可见尺寸；触控区经 padded tapTargetSize 扩到
/// [kDiaryToolbarButtonExtent]。「更多」按钮复用同一尺寸。
const BoxConstraints kDiaryToolbarButtonConstraints = BoxConstraints(
  minWidth: 32,
  minHeight: 32,
  maxWidth: 32,
  maxHeight: 32,
);

/// 选区是否触及代码块（折叠选区看光标所在块）。工具栏据此决定点按代码块
/// 工具是“转为代码块”还是打开代码块面板，面板开着时据此判断是否该收起。
bool diarySelectionInCodeBlock(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) return false;
  return diaryCodeBlocksInRange(editorState.document, selection).isNotEmpty;
}

/// 工具在当前选区上是否“正在生效”（加粗、引用、列表等），供「更多」按钮在
/// 面板收起时提示：收进面板的工具虽然看不见，选中态不能跟着丢。
/// 撤销、插入类等没有选中态的工具恒为 false。
bool isDiaryToolbarItemActive(DiaryToolbarItem item, EditorState editorState) {
  String? blockType() {
    final selection = editorState.selection;
    if (selection == null) return null;
    return editorState.getNodeAtPath(selection.start.path)?.type;
  }

  return switch (item) {
    DiaryToolbarItem.bold => _isDiaryInlineActive(
      editorState,
      kDiaryInlineBold,
    ),
    DiaryToolbarItem.italic => _isDiaryInlineActive(
      editorState,
      kDiaryInlineItalic,
    ),
    DiaryToolbarItem.underline => _isDiaryInlineActive(
      editorState,
      kDiaryInlineUnderline,
    ),
    DiaryToolbarItem.strikeThrough => _isDiaryInlineActive(
      editorState,
      kDiaryInlineStrikethrough,
    ),
    DiaryToolbarItem.inlineCode => _isDiaryInlineActive(
      editorState,
      kDiaryInlineCode,
    ),
    DiaryToolbarItem.textColor => _isDiaryInlineActive(
      editorState,
      kDiaryInlineTextColor,
    ),
    DiaryToolbarItem.backgroundColor => _isDiaryInlineActive(
      editorState,
      kDiaryInlineBackgroundColor,
    ),
    DiaryToolbarItem.headerStyle => blockType() == kDiaryBlockHeading,
    DiaryToolbarItem.orderedList => blockType() == kDiaryBlockNumberedList,
    DiaryToolbarItem.bulletList => blockType() == kDiaryBlockBulletedList,
    DiaryToolbarItem.checkList => blockType() == kDiaryBlockTodoList,
    DiaryToolbarItem.codeBlock => diarySelectionInCodeBlock(editorState),
    DiaryToolbarItem.quote => blockType() == kDiaryBlockQuote,
    DiaryToolbarItem.indent => _isDiarySelectionIndented(editorState),
    DiaryToolbarItem.link => _isDiaryInlineActive(
      editorState,
      kDiaryInlineHref,
    ),
    DiaryToolbarItem.undo ||
    DiaryToolbarItem.redo ||
    DiaryToolbarItem.clearFormat ||
    DiaryToolbarItem.image ||
    DiaryToolbarItem.video ||
    DiaryToolbarItem.attachment ||
    DiaryToolbarItem.currentTime ||
    DiaryToolbarItem.recording ||
    DiaryToolbarItem.ai ||
    DiaryToolbarItem.table ||
    DiaryToolbarItem.divider ||
    DiaryToolbarItem.toggleList ||
    DiaryToolbarItem.callout => false,
  };
}

/// 选区在行内属性 [key] 上是否生效：折叠选区看待输入样式与光标前一个字符，
/// 与 [EditorState.toggleAttribute] 的判定口径一致。
bool _isDiaryInlineActive(EditorState editorState, String key) {
  final selection = editorState.selection;
  if (selection == null) return false;
  final toggled = editorState.toggledStyle[key];
  if (toggled != null) return toggled == true;
  var range = selection.normalized;
  if (range.isCollapsed) {
    if (range.start.offset == 0) return false;
    range = range.copyWith(
      start: range.start.copyWith(offset: range.start.offset - 1),
    );
  }
  final nodes = editorState.getNodesInSelection(range);
  if (nodes.isEmpty) return false;
  return nodes.allSatisfyInSelection(
    range,
    (delta) => delta.everyAttributes((attributes) => attributes[key] == true),
  );
}

/// 选区起始块是否缩进：带首行缩进标记，或嵌在别的块下（块文档里缩进即嵌套）。
bool _isDiarySelectionIndented(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) return false;
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node != null && diaryParagraphHasFirstLineIndent(node)) return true;
  final parent = node?.parent;
  return parent != null && parent != editorState.document.root;
}

/// 悬浮工具栏的单个工具按钮：外观与文字颜色 / 更多 / 代码块按钮一致（32dp
/// 可见、40dp 触控区、14dp 图标），选中态经 [ExpressiveStateBlend] 过渡到
/// primaryContainer 小圆角方形。
///
/// - [editorState] 与 [isActive] 要么都给（开关按钮：随选区与待输入样式局部
///   重建），要么都不给（普通动作按钮）；
/// - [icon] 按选中过渡系数着色：[foreground] 为当前前景色。
class _DiaryToolbarButton extends StatelessWidget {
  const _DiaryToolbarButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.editorState,
    this.isActive,
  });

  final String tooltip;
  final Widget Function(BuildContext context, Color foreground) icon;
  final VoidCallback? onPressed;
  final EditorState? editorState;
  final bool Function()? isActive;

  @override
  Widget build(BuildContext context) {
    final editorState = this.editorState;
    final isActive = this.isActive;
    // 开关按钮：选区变化（每次 transaction 落定都会通知）与待输入样式变化时
    // 重算选中态。普通动作按钮直接画。
    if (editorState == null || isActive == null) {
      return _buildButton(context, false);
    }
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        editorState.selectionNotifier,
        editorState.toggledStyleNotifier,
      ]),
      builder: (BuildContext context, Widget? child) =>
          _buildButton(context, isActive()),
    );
  }

  Widget _buildButton(BuildContext context, bool active) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: isActive == null ? null : active,
      child: ExpressiveStateBlend(
        active: active,
        builder: (BuildContext context, double t, Widget? child) {
          final foreground = Color.lerp(
            colors.onSurface,
            colors.onPrimaryContainer,
            t,
          )!;
          return IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: kDiaryToolbarButtonConstraints,
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
                final pressed = states.contains(WidgetState.pressed);
                return RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    pressed ? lerpDouble(12, 8, t)! : lerpDouble(16, 12, t)!,
                  ),
                );
              }),
              backgroundColor: WidgetStatePropertyAll<Color>(
                colors.primaryContainer.withValues(alpha: t),
              ),
              foregroundColor: WidgetStatePropertyAll<Color>(foreground),
              iconColor: WidgetStatePropertyAll<Color>(foreground),
            ),
            icon: SizedBox.square(
              dimension: 32,
              child: Center(child: icon(context, foreground)),
            ),
          );
        },
      ),
    );
  }
}

/// 单个工具项的按钮（AppFlowy 版）：调用方按 [diaryToolbarItemSlots] 预留宽度。
/// 文字颜色与背景颜色不经这里（见 `DiaryToolbarColorButton`），代码块也不经
/// 这里（见 `DiaryToolbarCodeBlockButton`）；文件选择与复制由媒体导入控制器
/// 处理。
Widget buildDiaryToolbarItemButton(
  BuildContext context,
  DiaryToolbarItem item,
  EditorState editorState, {
  String? currentTimeFormatPattern,
  VoidCallback? onRecordingPressed,
  bool recordingOpen = false,
  // AI 写作面板：给出时工具栏出现 AI 按钮（见 DiaryToolbarItem.ai）。
  VoidCallback? onAiPressed,
  bool aiOpen = false,
  void Function(DiaryMediaKind)? onMediaPressed,
  DiaryMediaKind? activeMediaKind,
  bool mediaImportBusy = false,
  // 能拍摄的平台上图片 / 视频按钮先弹来源菜单（见 DiaryToolbarMediaSourceButton）：
  // 给出时点按改为开合菜单，不再直接打开选择器；[mediaMenuOpen] 为菜单正
  // 开着，按钮与面板开着时一样显示选中态。
  VoidCallback? onMediaButtonPressed,
  bool mediaMenuOpen = false,
}) {
  final l10n = context.l10n;

  /// 行内开关（加粗、斜体等）：选中态随选区，开按切换。
  Widget inlineToggle(String key) => _DiaryToolbarButton(
    editorState: editorState,
    tooltip: item.label(l10n),
    icon: (context, foreground) =>
        FaIcon(item.iconData, size: 14, color: foreground),
    isActive: () => _isDiaryInlineActive(editorState, key),
    onPressed: () => unawaited(editorState.toggleAttribute(key)),
  );

  /// 块开关（列表、引用、标题）：在块类型与普通段落之间切换。
  Widget blockToggle(String blockType, Future<void> Function() onPressed) =>
      _DiaryToolbarButton(
        editorState: editorState,
        tooltip: item.label(l10n),
        icon: (context, foreground) =>
            FaIcon(item.iconData, size: 14, color: foreground),
        isActive: () => editorState.selection == null
            ? false
            : editorState
                      .getNodeAtPath(editorState.selection!.start.path)
                      ?.type ==
                  blockType,
        onPressed: () => unawaited(onPressed()),
      );

  final mediaKind = switch (item) {
    DiaryToolbarItem.image => DiaryMediaKind.image,
    DiaryToolbarItem.video => DiaryMediaKind.video,
    DiaryToolbarItem.attachment => DiaryMediaKind.attachment,
    _ => null,
  };
  if (mediaKind != null) {
    final menuButton = onMediaButtonPressed != null;
    return _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) {
        if (activeMediaKind == mediaKind) {
          return ExpressiveLoadingIndicator(
            size: 16,
            semanticLabel: l10n.diaryMediaImporting,
          );
        }
        final colors = Theme.of(context).colorScheme;
        return FaIcon(
          item.iconData,
          size: 14,
          color: mediaImportBusy || recordingOpen
              ? colors.onSurfaceVariant
              : colors.onSurface,
        );
      },
      editorState: menuButton ? editorState : null,
      isActive: menuButton ? () => mediaMenuOpen : null,
      onPressed: mediaImportBusy || recordingOpen
          ? null
          : menuButton
          ? onMediaButtonPressed
          : (onMediaPressed == null ? null : () => onMediaPressed(mediaKind)),
    );
  }

  return switch (item) {
    DiaryToolbarItem.undo => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => editorState.undoManager.undo(),
    ),
    DiaryToolbarItem.redo => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => editorState.undoManager.redo(),
    ),
    DiaryToolbarItem.bold => inlineToggle(kDiaryInlineBold),
    DiaryToolbarItem.italic => inlineToggle(kDiaryInlineItalic),
    DiaryToolbarItem.underline => inlineToggle(kDiaryInlineUnderline),
    DiaryToolbarItem.strikeThrough => inlineToggle(kDiaryInlineStrikethrough),
    DiaryToolbarItem.inlineCode => inlineToggle(kDiaryInlineCode),
    DiaryToolbarItem.clearFormat => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => unawaited(_clearDiaryInlineFormat(editorState)),
    ),
    DiaryToolbarItem.headerStyle => blockToggle(
      kDiaryBlockHeading,
      () => _cycleDiaryHeaderStyle(editorState),
    ),
    DiaryToolbarItem.orderedList => blockToggle(
      kDiaryBlockNumberedList,
      () => _toggleDiaryBlockType(editorState, kDiaryBlockNumberedList),
    ),
    DiaryToolbarItem.bulletList => blockToggle(
      kDiaryBlockBulletedList,
      () => _toggleDiaryBlockType(editorState, kDiaryBlockBulletedList),
    ),
    DiaryToolbarItem.checkList => blockToggle(
      kDiaryBlockTodoList,
      () => _toggleDiaryBlockType(editorState, kDiaryBlockTodoList),
    ),
    DiaryToolbarItem.quote => blockToggle(
      kDiaryBlockQuote,
      () => _toggleDiaryBlockType(editorState, kDiaryBlockQuote),
    ),
    // 「缩进」占两格：增 / 减两个按钮，中间隔 kDiaryToolbarIndentGap（排布
    // 按 diaryToolbarItemExtent 计算，与原来一致）。
    DiaryToolbarItem.indent => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _DiaryToolbarButton(
          tooltip: item.label(l10n),
          icon: (context, foreground) =>
              FaIcon(FontAwesomeIcons.indent, size: 14, color: foreground),
          onPressed: () =>
              unawaited(_shiftDiaryBlockIndent(editorState, increase: true)),
        ),
        const SizedBox(width: kDiaryToolbarIndentGap),
        _DiaryToolbarButton(
          tooltip: item.label(l10n),
          icon: (context, foreground) =>
              FaIcon(FontAwesomeIcons.outdent, size: 14, color: foreground),
          onPressed: () =>
              unawaited(_shiftDiaryBlockIndent(editorState, increase: false)),
        ),
      ],
    ),
    DiaryToolbarItem.link => _DiaryToolbarButton(
      editorState: editorState,
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      isActive: () => _isDiaryInlineActive(editorState, kDiaryInlineHref),
      onPressed: () => unawaited(_editDiaryLink(context, editorState)),
    ),
    DiaryToolbarItem.currentTime => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => unawaited(
        insertDiaryToolbarCurrentTime(
          context,
          editorState,
          formatPattern: currentTimeFormatPattern,
        ),
      ),
    ),
    DiaryToolbarItem.recording => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) => FaIcon(
        item.iconData,
        size: 14,
        color: recordingOpen
            ? Theme.of(context).colorScheme.primary
            : foreground,
      ),
      onPressed: mediaImportBusy ? null : onRecordingPressed,
    ),
    // v0.11.0 新增：AI 写作（形态仿录音；面板开着时图标取主色）。
    DiaryToolbarItem.ai => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) => FaIcon(
        item.iconData,
        size: 14,
        color: aiOpen ? Theme.of(context).colorScheme.primary : foreground,
      ),
      onPressed: mediaImportBusy ? null : onAiPressed,
    ),
    // v0.10.0 新增：表格 / 折叠块 / 提示块（实现见各模块的 helper）。
    DiaryToolbarItem.table => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => unawaited(insertDiaryTableBlock(editorState)),
    ),
    // v0.11.0 新增：分隔线（实现见 diary_divider_block.dart）。
    DiaryToolbarItem.divider => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => unawaited(insertDiaryDividerBlock(editorState)),
    ),
    DiaryToolbarItem.toggleList => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => unawaited(insertDiaryToggleBlock(editorState)),
    ),
    DiaryToolbarItem.callout => _DiaryToolbarButton(
      tooltip: item.label(l10n),
      icon: (context, foreground) =>
          FaIcon(item.iconData, size: 14, color: foreground),
      onPressed: () => unawaited(insertDiaryCalloutBlock(editorState)),
    ),
    // 文字颜色 / 背景颜色走 DiaryToolbarColorButton，代码块走
    // DiaryToolbarCodeBlockButton，不会进到这里。
    DiaryToolbarItem.textColor ||
    DiaryToolbarItem.backgroundColor ||
    DiaryToolbarItem.codeBlock ||
    DiaryToolbarItem.image ||
    DiaryToolbarItem.video ||
    DiaryToolbarItem.attachment => const SizedBox.shrink(),
  };
}

/// 在 [blockType] 与普通段落之间切换选区触及的文字块（列表、引用、待办）。
///
/// 只改类型与必要的块属性（标题的 `level`、待办的 `checked`），其余属性
/// （如对齐）原样保留；delta 原样保留。
Future<void> _toggleDiaryBlockType(
  EditorState editorState,
  String blockType,
) async {
  final selection = editorState.selection?.normalized;
  if (selection == null) return;
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.delta == null) return;
  final isActive = node.type == blockType;
  await editorState.formatNode(selection, (n) {
    final attributes = Map<String, dynamic>.from(n.attributes);
    attributes[kDiaryBlockDeltaKey] = (n.delta ?? Delta()).toJson();
    if (isActive) {
      attributes.remove(kDiaryBlockLevelKey);
      attributes.remove(kDiaryBlockCheckedKey);
    } else if (blockType == kDiaryBlockTodoList) {
      attributes[kDiaryBlockCheckedKey] = false;
    }
    return n.copyWith(
      type: isActive ? kDiaryBlockParagraph : blockType,
      attributes: attributes,
    );
  });
}

/// 标题级别循环：正文 → 一级 → 二级 → 三级 → 正文（与原来一致）。
Future<void> _cycleDiaryHeaderStyle(EditorState editorState) async {
  final selection = editorState.selection?.normalized;
  if (selection == null) return;
  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.delta == null) return;
  final nextLevel = switch ((
    node.type == kDiaryBlockHeading,
    node.attributes[kDiaryBlockLevelKey],
  )) {
    (true, 1) => 2,
    (true, 2) => 3,
    (true, _) => 0,
    (false, _) => 1,
  };
  await editorState.formatNode(selection, (n) {
    final attributes = Map<String, dynamic>.from(n.attributes);
    attributes[kDiaryBlockDeltaKey] = (n.delta ?? Delta()).toJson();
    if (nextLevel == 0) {
      attributes.remove(kDiaryBlockLevelKey);
      return n.copyWith(type: kDiaryBlockParagraph, attributes: attributes);
    }
    attributes[kDiaryBlockLevelKey] = nextLevel;
    return n.copyWith(type: kDiaryBlockHeading, attributes: attributes);
  });
}

/// 缩进：块文档里缩进即嵌套（见 diary_blocks_from_delta）。
///
/// - 增加：把选区触及的顶层块逐个挂到各自前一个兄弟块的末尾；前一个块不能
///   收子块、或是第一个块时跳过；
/// - 减少：把嵌套块提为其父块的后一个兄弟（顶层块不动）。
/// 操作暂存在同一个 transaction 里、文档不动，循环内读到的路径始终有效；
/// 同一目标下接连移动时用已暂存的数量错开目标路径。
Future<void> _shiftDiaryBlockIndent(
  EditorState editorState, {
  required bool increase,
}) async {
  // 正文段落：只缩进首行，多行段落折行后的各行仍顶格（v0.11.0 #122，见
  // diary_paragraph_indent_editing.dart）；列表、待办、折叠块等仍是真实的
  // 嵌套层级。格子里只能放段落，不缩进（缩进即成为上一段的子块）。
  final paragraphs = diaryFirstLineIndentTargets(editorState);
  if (paragraphs != null) {
    if (increase) {
      await indentDiaryFirstLine(editorState, paragraphs);
    } else {
      await outdentDiaryFirstLine(editorState, paragraphs);
    }
    return;
  }
  final selection = editorState.selection?.normalized;
  if (selection == null) return;
  final document = editorState.document;
  final nodes = editorState.getNodesInSelection(selection);
  if (nodes.isEmpty) return;
  final transaction = editorState.transaction;
  final movedCounts = <String, int>{};
  var changed = false;

  Path shiftedTarget(Path base, String key) {
    final extra = movedCounts[key] ?? 0;
    movedCounts[key] = extra + 1;
    var target = base;
    for (var i = 0; i < extra; i++) {
      target = target.next;
    }
    return target;
  }

  // 减少缩进按文档顺序（提上去的块保持原有先后），增加缩进倒序（先动的块
  // 不影响后动块的前一个兄弟判断——路径都取自未改动的文档，顺序只影响
  // 同一父块下多个块的目标错开）。
  final ordered = increase ? nodes.reversed.toList() : nodes;
  for (final node in ordered) {
    final parent = node.parent;
    if (parent == null) continue;
    if (increase) {
      if (parent != document.root) continue;
      final path = node.path;
      if (path.last == 0) continue;
      final previous = document.nodeAtPath(path.previous);
      if (previous == null ||
          !kDiaryContainerBlockTypes.contains(previous.type)) {
        continue;
      }
      final key = previous.path.join('/');
      final extra = movedCounts[key] ?? 0;
      movedCounts[key] = extra + 1;
      transaction.moveNode(
        Path.from([...previous.path, previous.children.length + extra]),
        node,
      );
      changed = true;
    } else {
      if (parent == document.root) continue;
      final target = shiftedTarget(parent.path.next, parent.path.join('/'));
      transaction.moveNode(target, node);
      changed = true;
    }
  }
  if (changed) {
    transaction.afterSelection = transaction.beforeSelection;
    await editorState.apply(transaction);
  }
}

/// 清除选区的全部行内格式（加粗、斜体、颜色、链接、字号等）。
Future<void> _clearDiaryInlineFormat(EditorState editorState) async {
  final selection = editorState.selection?.normalized;
  if (selection == null || selection.isCollapsed) return;
  await editorState.formatDelta(selection, <String, dynamic>{
    kDiaryInlineBold: null,
    kDiaryInlineItalic: null,
    kDiaryInlineUnderline: null,
    kDiaryInlineStrikethrough: null,
    kDiaryInlineCode: null,
    kDiaryInlineHref: null,
    kDiaryInlineTextColor: null,
    kDiaryInlineBackgroundColor: null,
    kDiaryInlineSize: null,
  });
}

/// 链接按钮：选区已有链接时清除；选中了文字且没有链接时弹输入框写入 `href`。
///
/// 对话框关闭后按关闭前的选区写入（对话框会抢走焦点，选区可能已变）。
Future<void> _editDiaryLink(
  BuildContext context,
  EditorState editorState,
) async {
  final selection = editorState.selection?.normalized;
  if (selection == null) return;
  if (_isDiaryInlineActive(editorState, kDiaryInlineHref)) {
    if (!selection.isCollapsed) {
      await editorState.formatDelta(selection, <String, dynamic>{
        kDiaryInlineHref: null,
      });
    }
    return;
  }
  if (selection.isCollapsed) return;
  final l10n = context.l10n;
  final controller = TextEditingController(
    text:
        editorState.getDeltaAttributeValueInSelection<String>(
          kDiaryInlineHref,
          selection,
        ) ??
        '',
  );
  final url = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(l10n.autoT0024),
      content: TextField(
        contextMenuBuilder: appTextContextMenuBuilder,
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'https://'),
        onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  );
  controller.dispose();
  if (url == null || url.isEmpty) return;
  final target = editorState.selection?.normalized ?? selection;
  if (target.isCollapsed) return;
  await editorState.formatDelta(target, <String, dynamic>{
    kDiaryInlineHref: url,
  });
}
