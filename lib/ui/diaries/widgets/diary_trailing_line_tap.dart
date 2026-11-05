import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/app_platform.dart';
import '../controllers/diary_embed_editing.dart';

/// 点按正文最后一块下方的空白处时补一行可写的段落（见
/// [appendDiaryTrailingLine]）。
///
/// 嵌入块没有文字位置，上游点到它下方时只把光标“盖”在它上面、不连接输入法；
/// 文末是这类块时就没有地方能放出插入点：键盘不出来，既删不掉它也接不着
/// 往下写。这里只给块下方的空白一个可写的去处；不点就不改正文。手机与桌面
/// 都生效。
///
/// 只观察指针（[Listener] 不参与手势竞技场，上游的点按、长按选字、拖动把手
/// 与外层滚动都不受影响）：一次点按（未越过触摸容差、未到长按时长、期间
/// 没有第二根手指）抬起后，等这一轮指针分发结束——上游在竞技场清场时才处理
/// 点按——再看落点。桌面右键是打开菜单，不是点按，直接跳过。
///
/// 键盘重开不在这里：那是上游另一份既有行为，本地没有。
class DiaryTrailingLineTap extends StatefulWidget {
  const DiaryTrailingLineTap({
    super.key,
    required this.editorState,
    required this.child,
  });

  final af.EditorState editorState;
  final Widget child;

  @override
  State<DiaryTrailingLineTap> createState() => _DiaryTrailingLineTapState();
}

class _DiaryTrailingLineTapState extends State<DiaryTrailingLineTap> {
  int? _pointer;
  Offset? _downPosition;
  Timer? _tapDeadline;

  bool get _isMobile => !kIsWeb && !AppPlatform.isDesktop;

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) {
      // 第二根手指按下：这一次不再是点按。
      _reset();
      return;
    }
    // 桌面右键是打开菜单，不是点按（触摸与手写笔按下时同为主键）。
    if (widget.editorState.isDisposed || event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _downPosition = event.position;
    // 按住超过长按时长不再是点按。
    _tapDeadline = Timer(kLongPressTimeout, _reset);
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final position = event.position;
    final downPosition = _downPosition;
    _reset();
    if (downPosition == null) return;
    // 拖出触摸容差的是滚动/拖动手势，不是点按。
    if ((position - downPosition).distance > kTouchSlop) return;
    scheduleMicrotask(() => _afterTap(position));
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _reset();
  }

  void _afterTap(Offset position) {
    if (!mounted) return;
    _appendLineBelow(position);
  }

  /// 点按落在最后一个顶层块下方、需要补行时补上并弹出键盘。
  bool _appendLineBelow(Offset position) {
    final state = widget.editorState;
    if (state.isDisposed) return false;
    final blocks = state.document.root.children;
    if (blocks.isEmpty) return false;
    // 最后一块没有排版（滚出了虚拟列表）时点不到它下方，也量不出位置。
    final box = blocks.last.renderBox;
    if (box == null || !box.attached || !box.hasSize) return false;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (position.dy <= bottom) return false;
    final keyboardShown = View.of(context).viewInsets.bottom > 0;
    final selection = appendDiaryTrailingLine(state);
    if (selection == null) return false;
    // 新空行的编辑值（空文字、偏移 0）可能与输入法上次拿到的相同，上游
    // 连接时会直接返回、不弹键盘：键盘收着时断开重连。
    if (_isMobile && !keyboardShown) {
      state.service.keyboardService
        ?..closeKeyboard()
        ..enableKeyBoard(selection);
    }
    return true;
  }

  void _reset() {
    _tapDeadline?.cancel();
    _tapDeadline = null;
    _pointer = null;
    _downPosition = null;
  }

  @override
  void dispose() {
    _tapDeadline?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}
