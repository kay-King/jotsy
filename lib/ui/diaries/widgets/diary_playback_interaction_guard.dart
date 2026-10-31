import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// 播放、拖动和弹窗期间临时释放编辑焦点，手势结束后恢复正文获取焦点的能力。
/// 不清空选区；恢复 canRequestFocus 不会主动把键盘重新拉起。
///
/// AppFlowy 迁移说明：原来找上层的 `QuillEditor` 拿 focusNode / controller / 选区，
/// 现在找 `AppFlowyEditor` 拿 [EditorState] 与 `focusNode`（后者可能为 null，
/// 此时只保护选区）。选区恢复直接赋值，不经过 uiEvent 的聚焦路径（与原来
/// `ignoreFocusOnTextChange` 的作用一致），不会把键盘重新拉起。只读正文里
/// 没有 `AppFlowyEditor` 祖先时退化为空操作。
class DiaryPlaybackInteractionGuard extends StatefulWidget {
  const DiaryPlaybackInteractionGuard({super.key, required this.child});
  final Widget child;

  @override
  State<DiaryPlaybackInteractionGuard> createState() =>
      _DiaryPlaybackInteractionGuardState();
}

class _DiaryPlaybackInteractionGuardState
    extends State<DiaryPlaybackInteractionGuard> {
  final _pointers = <int>{};
  FocusNode? _editorFocus;
  bool _couldRequestFocus = false;
  EditorState? _editorState;
  Selection? _selection;

  void _onDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_editorState != null) return;
    final editor = context.findAncestorWidgetOfExactType<AppFlowyEditor>();
    if (editor == null) return;
    _editorState = editor.editorState;
    _selection = editor.editorState.selection;
    final focusNode = editor.focusNode;
    if (focusNode != null) {
      _editorFocus = focusNode;
      _couldRequestFocus = focusNode.canRequestFocus;
      focusNode.canRequestFocus = false;
    }
  }

  void _onEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    // 选择服务在手势结束后更新选区，需等整帧完成再恢复。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pointers.isEmpty) _restore();
    });
  }

  void _restore({bool restoreSelection = true}) {
    final editorState = _editorState;
    _editorState = null;
    final selection = _selection;
    _selection = null;
    final focusNode = _editorFocus;
    _editorFocus = null;
    // 连续播放/暂停可能改变正文选区：恢复手势开始时的选区。直接赋值只重画
    // 光标，不走聚焦路径，不会把键盘重新拉起。
    if (restoreSelection &&
        editorState != null &&
        selection != null &&
        editorState.selection != selection) {
      editorState.selection = selection;
    }
    if (focusNode != null && (focusNode.context?.mounted ?? false)) {
      focusNode.canRequestFocus = _couldRequestFocus;
    }
  }

  @override
  void dispose() {
    _restore(restoreSelection: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _onDown,
    onPointerUp: _onEnd,
    onPointerCancel: _onEnd,
    child: widget.child,
  );
}
