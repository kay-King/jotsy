import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/text_process_actions_service.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import 'diary_editor_selection_menu_items.dart';

/// 日记正文（AppFlowy 编辑器）手机端的文字选区菜单浮层。
///
/// 背景：本项目用的 AppFlowy 版本里，包内自带的 `MobileFloatingToolbar` 从未
/// 被实例化（移动端长按选字后没有任何复制 / 粘贴菜单），也没有对外暴露的
/// 选区菜单钩子；桌面端则有 `AppFlowyEditor(contextMenuBuilder:)`（右键）。
/// 所以手机端由本浮层自己驱动，只用 `EditorState` 的公开 API：
/// `selectionNotifier`、`selectionRects()`、`selectionType`、
/// `selectionUpdateReason`、`selectionExtraInfo`。
///
/// 行为（对齐包内 `MobileFloatingToolbar` 的策略）：
/// - 有范围选区时显示玻璃胶囊 [AppTextSelectionToolbar]，锚点取选区首个矩形
///   的上沿中点与末个矩形的下沿中点（胶囊自己判断放上方还是下方）；
/// - 拖动选区把手期间隐藏，松手后重新显示；滚动时隐藏，滚动结束 50ms 后
///   重新显示；
/// - 点按光标处（选区不变的 uiEvent）时也显示（只有粘贴与全选）；
/// - 块选区（如选中图片块）时不显示；
/// - 点按菜单项后由菜单项自己收起（[diaryEditorSelectionMenuItems] 的
///   dismiss）；复制后选区收成光标（手机习惯）。
///
/// 桌面端不使用本浮层（右键菜单走 `contextMenuBuilder`），直接返回 child。
/// 选区菜单的“其他应用文字处理”在显示时后台刷新一次。
class DiarySelectionToolbarOverlay extends StatefulWidget {
  const DiarySelectionToolbarOverlay({
    super.key,
    required this.editorState,
    required this.editable,
    required this.child,
  });

  final EditorState editorState;
  final bool editable;
  final Widget child;

  @override
  State<DiarySelectionToolbarOverlay> createState() =>
      _DiarySelectionToolbarOverlayState();
}

class _DiarySelectionToolbarOverlayState
    extends State<DiarySelectionToolbarOverlay> {
  OverlayEntry? _entry;
  Selection? _prevSelection;
  bool _visible = false;
  Timer? _showTimer;
  VoidCallback? _onScrollEnd;

  EditorState get _editorState => widget.editorState;

  @override
  void initState() {
    super.initState();
    // 桌面端不使用本浮层（右键菜单走 AppFlowyEditor 的 contextMenuBuilder），
    // 这里就不监听选区：只在 build 里返回 child 是不够的，state 照样会弹菜单。
    if (!AppPlatform.isDesktop) {
      _editorState.selectionNotifier.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _editorState.selectionNotifier.removeListener(_onSelectionChanged);
    _removeEntry();
    super.dispose();
  }

  void _onSelectionChanged() {
    final selection = _editorState.selection;
    if (selection == null ||
        _editorState.selectionType == SelectionType.block) {
      _clear();
      return;
    }
    if (selection.isCollapsed) {
      if (_visible) {
        _clear();
      } else if (_prevSelection == selection &&
          _editorState.selectionUpdateReason == SelectionUpdateReason.uiEvent &&
          !_toolbarDisabled) {
        _showAfterDelay();
      }
      _prevSelection = selection;
      return;
    }
    _clear();
    // 拖动选区把手期间不显示，松手后选区再变时会重新显示。
    if (_draggingHandle) return;
    if (!_toolbarDisabled) _showAfterDelay();
    _prevSelection = selection;
  }

  /// 选区更新里要求不显示浮层工具栏（如长按拖动中途的更新）。
  bool get _toolbarDisabled =>
      _editorState.selectionExtraInfo?['disableFloatingToolbar'] == true;

  /// 是否正在拖动选区把手：包内 `MobileSelectionDragMode` 是未导出的内部
  /// 枚举，这里按它的 `toString()` 判断（值来自
  /// `mobile_selection_service.dart` 的 `selection_drag_mode`）。
  bool get _draggingHandle {
    final dragMode = _editorState.selectionExtraInfo?['selection_drag_mode'];
    final name = dragMode.toString();
    return name == 'MobileSelectionDragMode.leftSelectionHandle' ||
        name == 'MobileSelectionDragMode.rightSelectionHandle';
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification && _onScrollEnd != null) {
      final show = _onScrollEnd;
      _onScrollEnd = null;
      show?.call();
    } else if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      if (_visible && _onScrollEnd == null) {
        _removeEntry();
        _onScrollEnd = () => _showAfterDelay(const Duration(milliseconds: 50));
      } else if (_visible) {
        _removeEntry();
      }
    }
    return false;
  }

  void _clear() {
    _showTimer?.cancel();
    _showTimer = null;
    _removeEntry();
    _prevSelection = null;
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
    _visible = false;
  }

  void _showAfterDelay([Duration duration = Duration.zero]) {
    _showTimer?.cancel();
    _showTimer = Timer(duration, () {
      if (!mounted) return;
      _removeEntry();
      _showToolbar();
    });
  }

  void _showToolbar() {
    if (!mounted || _editorState.isDisposed) return;
    final selection = _editorState.selection;
    if (selection == null) return;
    final rects = _visibleRects();
    if (rects.isEmpty) return;
    // 只有一个选区且为空矩形时不显示（如不可见的选区）。
    if (rects.length <= 1 && rects.single.isEmpty) return;
    unawaited(TextProcessActionsService.instance.refresh());
    final anchors = TextSelectionToolbarAnchors(
      primaryAnchor: rects.first.topCenter,
      secondaryAnchor: rects.last.bottomCenter,
    );
    _entry = OverlayEntry(
      builder: (BuildContext context) => AppTextSelectionToolbar(
        anchors: anchors,
        actions: diaryEditorSelectionMenuItems(
          context,
          _editorState,
          editable: widget.editable,
          dismiss: _removeEntry,
          afterCopy: _collapseToCursor,
        ),
        collapseScope: selection,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _visible = true;
  }

  /// 只留编辑器可见区域内的选区矩形（滚出屏幕上方的部分不参与定位）。
  List<Rect> _visibleRects() {
    final rects = _editorState.selectionRects();
    if (rects.isEmpty) return rects;
    final editorTop =
        _editorState.renderBox?.localToGlobal(Offset.zero).dy ?? 0;
    final visible = rects.where((Rect rect) => rect.top >= editorTop).toList();
    return visible.isEmpty ? const <Rect>[] : visible;
  }

  /// 复制后把选区收成光标（手机习惯），同时收起菜单。
  void _collapseToCursor() {
    final selection = _editorState.selection;
    _removeEntry();
    if (selection == null || _editorState.isDisposed) return;
    unawaited(
      _editorState.updateSelectionWithReason(
        Selection.collapsed(selection.end),
        reason: SelectionUpdateReason.uiEvent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppPlatform.isDesktop) return widget.child;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: widget.child,
    );
  }
}
