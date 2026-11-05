// fork 没有上游的 DiaryEditorController（编辑页直接持有 EditorState，
// 见 edit_diary_page.dart）：AI 写作 / 灵感只用它的很小一面，这里包一层
// EditorState，只提供那部分能力，不复制上游控制器的拖拽、折叠、链接等
// 逻辑。编辑页用 [DiaryEditorController.wrap] 跟随换 EditorState
// （replaceEditorState 后仍指向当前那份）；测试用 [fromContent] 自带一份
// EditorState。
//
// 另有两个上游同名顶层函数（diary_ai_editing.dart 与测试用）：
// [diaryEditorDocument] 与 [walkDiaryEditorNodes]，同样只做薄转发。

import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';

import '../../../core/database/content_codec.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';

export 'package:appflowy_editor/appflowy_editor.dart'
    show Document, Node, Selection, Position, Delta;

/// AI 功能用的编辑器会话：持有 AppFlowy 文档、选区与事务，不参与路由、
// 文件 IO 或写库。事务与选区通知合并到 Listenable，页面的自动保存链路
// 继续读同步快照。
class DiaryEditorController extends ChangeNotifier {
  DiaryEditorController({required af.EditorState state})
    : _stateOf = (() => state),
      _ownsState = false {
    _attach();
  }

  /// 跟随外部持有的 EditorState（编辑页换 EditorState 时仍指向当前那份）。
  /// 不拥有它：[dispose] 不释放 EditorState。
  DiaryEditorController.wrap(af.EditorState Function() stateOf)
    : _stateOf = stateOf,
      _ownsState = false {
    _attach();
  }

  factory DiaryEditorController.fromContent(
    String content, {
    bool readOnly = false,
  }) {
    final controller = DiaryEditorController(
      state: af.EditorState(document: diaryEditorDocument(content)),
    );
    controller._ownsState = true;
    controller.state.editable = !readOnly;
    return controller;
  }

  final af.EditorState Function() _stateOf;
  bool _ownsState;
  StreamSubscription<af.EditorTransactionValue>? _subscription;
  af.EditorState? _attachedState;
  af.Selection? _lastSelection;
  bool _disposeRequested = false;

  af.EditorState get state {
    final current = _stateOf();
    // 跟随外部 EditorState：编辑页换了 EditorState 时把订阅迁过去。
    if (!identical(_attachedState, current)) _attach(current);
    return current;
  }

  af.Document get document => state.document;

  af.Selection? get selection {
    final current = state.selection ?? _lastSelection;
    return current != null && document.nodeAtPath(current.end.path) != null
        ? current
        : null;
  }

  bool get readOnly => !state.editable;

  String get plainText => diaryBlocksPlainText(document.toJson());

  bool get hasContent => diaryBlocksHaveVisibleContent(document.toJson());

  void _attach([af.EditorState? next]) {
    final current = next ?? _stateOf();
    if (identical(_attachedState, current)) return;
    final old = _attachedState;
    if (old != null) {
      old.selectionNotifier.removeListener(_onSelection);
      unawaited(_subscription?.cancel());
      _subscription = null;
    }
    _attachedState = current;
    _subscription = current.transactionStream.listen((event) {
      if (event.$1 == af.TransactionTime.after &&
          event.$2.operations.isNotEmpty) {
        notifyListeners();
      }
    });
    current.selectionNotifier.addListener(_onSelection);
    _lastSelection = current.selection;
  }

  void _onSelection() {
    if (state.selection != null) _lastSelection = state.selection;
    notifyListeners();
  }

  void select(af.Selection? selection) {
    unawaited(state.updateSelectionWithReason(selection));
  }

  void apply(
    af.Transaction transaction, {
    bool allowReadOnly = false,
    bool recordUndo = true,
    bool updateSelection = true,
  }) {
    unawaited(
      state.apply(
        transaction,
        skipEditableCheck: allowReadOnly,
        options: af.ApplyOptions(
          source: recordUndo
              ? af.TransactionSource.userEdit
              : af.TransactionSource.none,
        ),
        skipHistoryDebounce: true,
        withUpdateSelection: updateSelection,
      ),
    );
  }

  void undo() => state.undoManager.undo();
  void redo() => state.undoManager.redo();
  // FixedSizeStack 只有 isEmpty，没有 isNotEmpty。
  bool get hasUndo => !state.undoManager.undoStack.isEmpty;
  bool get hasRedo => !state.undoManager.redoStack.isEmpty;

  @override
  void dispose() {
    if (_disposeRequested) return;
    _disposeRequested = true;
    final attached = _attachedState;
    attached?.selectionNotifier.removeListener(_onSelection);
    unawaited(_subscription?.cancel());
    _subscription = null;
    // 跟随外部 EditorState 时不释放它（归属在编辑页）；自带的才释放。
    if (_ownsState && attached != null && !attached.isDisposed) {
      attached.dispose();
    }
    super.dispose();
  }
}

/// 输入为任一代存储内容。通过 JSON 做隔离，编辑会话不能改动模板或缓存快照。
af.Document diaryEditorDocument(String content) {
  return decodeDiaryContentToAppFlowyDocument(content);
}

Iterable<af.Node> walkDiaryEditorNodes(af.Document document) sync* {
  Iterable<af.Node> visit(Iterable<af.Node> nodes) sync* {
    for (final node in nodes) {
      yield node;
      yield* visit(node.children);
    }
  }

  yield* visit(document.root.children);
}
