import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';

/// 编辑页正文的光标跟随：打字、用键盘移动或扩展选区、软键盘弹起之后，把
/// 光标保持在底部浮层（悬浮工具栏、「更多」面板、元数据面板）上方。
///
/// 为什么不用编辑器自带的：编辑器自带的光标揭示只把光标滚到视口边缘，
/// 不知道底部被悬浮工具栏等浮层盖住了多少。这里取光标矩形并向下延长
/// [coveredHeight] 再揭示（[_revealCaretAbove]），视口只在光标确实被挡住
/// 时滚动，而且只滚到刚好露出为止。
///
/// - 触发：正文选区变化且正文有焦点；软键盘弹起（变高）的每一帧；调用方
///   手动调用 [revealCurrentCaret]（如「更多」面板展开这种不改变选区的场景）。
///   只改格式、勾选待办这类选区不动的变化不滚动，免得把用户正在看的位置
///   拽回光标处。
/// - 软键盘弹起时与 Flutter 自带输入框（EditableText.didChangeMetrics）一样，
///   每帧高度变大都立即（不带动画）揭示一次，光标随键盘一起被顶上去；不能只等
///   高度停稳再揭示：真机上键盘动画的节奏各不相同，点了底部的字、键盘弹起后
///   那一行仍会留在键盘下面。停稳后再补一次，校正最后一帧的布局。
/// - 揭示哪一端：折叠的光标揭示光标；选区只有一端在动（键盘“选择”模式、拖动
///   手柄）时揭示在动的那端；两端同时变（全选、双击选词）不滚动。
/// - 时机：同一帧内的多次变化合并为一次，放到帧末执行，此时新的一行已布局、
///   滚动范围已更新。
/// - 副作用：只滚动外层视口，不改选区与文档；正文失焦（录音面板、元数据面板
///   展开）或控制器已销毁时什么也不做。
///
/// AppFlowy 迁移说明：原来监听 `QuillController` 的通知并用
/// `RenderEditor.getLocalRectForCaret` 取光标矩形；现在监听
/// `EditorState.selectionNotifier`，光标矩形经块节点的 `Selectable`
/// 取（[SelectableMixin.getCursorRectInPosition]），揭示仍走
/// `RenderObject.showOnScreen` 把光标滚到遮挡物上方。
class DiaryCaretFollowController {
  DiaryCaretFollowController({
    required this.focusNode,
    required this.coveredHeight,
    required this.revealDuration,
  });

  final FocusNode focusNode;

  /// 视口底部当前被浮层盖住的高度，与正文滚动容器的底部占位同源。
  final double Function() coveredHeight;

  /// 打字、移动选区时揭示滚动的时长（经 ExpressiveMotion 解析，减少动画时
  /// 为 0）。软键盘弹起时的揭示不用它：每帧跟随键盘，再加动画只会落后一拍。
  final Duration Function() revealDuration;

  /// 软键盘高度逐帧变化、还可能回弹，停稳后再补一次揭示（与编辑器自身对键盘
  /// 高度的去抖一致）。这是去抖计时，不是动画时长。
  static const Duration _keyboardSettleDelay = Duration(milliseconds: 100);

  EditorState? _editorState;
  Selection? _lastSelection;
  Position? _pendingTarget;
  // 同一帧里只要有一次来自键盘弹起，这一帧的揭示就不带动画。
  bool _pendingImmediate = false;
  bool _revealScheduled = false;
  Timer? _keyboardSettleTimer;
  double? _lastKeyboardInset;
  bool _disposed = false;

  /// 绑定（或换绑）正文编辑器状态：编辑模式回填详情、新建模式恢复草稿时
  /// 页面会换一个新实例。旧实例此时可能已释放，移除监听是安全的。
  void attach(EditorState editorState) {
    if (identical(_editorState, editorState)) {
      return;
    }
    _editorState?.selectionNotifier.removeListener(_handleSelectionChanged);
    _editorState = editorState
      ..selectionNotifier.addListener(_handleSelectionChanged);
    _lastSelection = editorState.selection;
  }

  void _handleSelectionChanged() {
    final editorState = _editorState;
    if (editorState == null) {
      return;
    }
    final selection = editorState.selection;
    final previous = _lastSelection;
    _lastSelection = selection;
    if (selection == null || selection == previous || !focusNode.hasFocus) {
      return;
    }
    final target = _revealTarget(previous, selection);
    if (target != null) {
      _scheduleReveal(target);
    }
  }

  /// 选区在动的那一端：AppFlowy 的 Selection 已按文档顺序归一化
  /// （start 在前、end 在后），对应原来 TextSelection 的 base / extent。
  static Position? _revealTarget(
    Selection? previous,
    Selection selection,
  ) {
    if (selection.isCollapsed) {
      return selection.end;
    }
    final startMoved = previous?.start != selection.start;
    final endMoved = previous?.end != selection.end;
    if (endMoved && !startMoved) {
      return selection.end;
    }
    if (startMoved && !endMoved) {
      return selection.start;
    }
    return null;
  }

  /// 页面 didChangeMetrics 时传入当前软键盘高度（键盘动画期间逐帧调用）。
  /// 变高的每一帧立即揭示光标，停稳后再补一次；收起或变矮时不滚动。
  void handleKeyboardInset(double inset) {
    final previous = _lastKeyboardInset ?? 0;
    if (inset == _lastKeyboardInset) {
      return;
    }
    _lastKeyboardInset = inset;
    _keyboardSettleTimer?.cancel();
    if (inset <= previous) {
      return;
    }
    _revealCaretNow();
    _keyboardSettleTimer = Timer(_keyboardSettleDelay, _revealCaretNow);
  }

  void _revealCaretNow() {
    final editorState = _editorState;
    final selection = editorState?.selection;
    if (_disposed ||
        editorState == null ||
        selection == null ||
        !focusNode.hasFocus) {
      return;
    }
    _scheduleReveal(selection.end, immediate: true);
  }

  void _scheduleReveal(Position target, {bool immediate = false}) {
    _pendingTarget = target;
    _pendingImmediate = _pendingImmediate || immediate;
    if (_revealScheduled) {
      return;
    }
    _revealScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _revealPending())
      // 键盘停稳的计时器触发时可能没有待绘制的帧，主动排一帧让回调执行。
      ..ensureVisualUpdate();
  }

  void _revealPending() {
    _revealScheduled = false;
    final target = _pendingTarget;
    final immediate = _pendingImmediate;
    final editorState = _editorState;
    _pendingTarget = null;
    _pendingImmediate = false;
    if (_disposed || target == null || editorState == null) {
      return;
    }
    if (!focusNode.hasFocus) {
      return;
    }
    _revealCaretAbove(
      editorState,
      target,
      coveredHeight: coveredHeight(),
      duration: immediate ? Duration.zero : revealDuration(),
    );
  }

  /// 不改变选区的场景下手动揭示一次当前光标（如「更多」面板展开时）：
  /// 展开不改变选区，选区监听不会触发，调用方在留白生效的下一帧调这里。
  /// 编辑标题时光标不在正文里（[focusNode] 无焦点）时什么也不做。
  void revealCurrentCaret({required Duration duration}) {
    final editorState = _editorState;
    if (_disposed || editorState == null || !focusNode.hasFocus) {
      return;
    }
    final selection = editorState.selection;
    if (selection == null) {
      return;
    }
    _revealCaretAbove(
      editorState,
      selection.end,
      coveredHeight: coveredHeight(),
      duration: duration,
    );
  }

  /// 把 [target] 处的光标滚到底部遮挡物上方。
  ///
  /// 悬浮工具栏是叠在正文上的浮层，正文视口并不知道底部被遮住了多少：这里把
  /// 光标矩形向下延长 [coveredHeight] 再交给 showOnScreen，视口只在光标确实被
  /// 挡住时滚动，而且只滚到刚好露出为止。目标节点尚未布局时什么也不做。
  void _revealCaretAbove(
    EditorState editorState,
    Position target, {
    required double coveredHeight,
    required Duration duration,
  }) {
    final node = editorState.document.nodeAtPath(target.path);
    final selectable = node?.selectable;
    final renderBox = node?.renderBox;
    if (selectable == null ||
        renderBox == null ||
        !renderBox.attached ||
        !renderBox.hasSize) {
      return;
    }
    final localCaret = selectable.getCursorRectInPosition(
      target,
      shiftWithBaseOffset: true,
    );
    if (localCaret == null) {
      return;
    }
    final caretRect = selectable.transformRectToGlobal(
      localCaret,
      shiftWithBaseOffset: true,
    );
    final topLeft = renderBox.globalToLocal(caretRect.topLeft);
    final bottomRight = renderBox.globalToLocal(caretRect.bottomRight);
    renderBox.showOnScreen(
      rect: Rect.fromLTRB(
        topLeft.dx,
        topLeft.dy,
        bottomRight.dx,
        bottomRight.dy + coveredHeight,
      ),
      duration: duration,
      curve: ExpressiveMotion.effects,
    );
  }

  void dispose() {
    _disposed = true;
    _keyboardSettleTimer?.cancel();
    _editorState?.selectionNotifier.removeListener(_handleSelectionChanged);
    _editorState = null;
  }
}
