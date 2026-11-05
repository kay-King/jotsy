import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/text_process_actions_service.dart';
import 'package:node_diary/ui/diaries/controllers/diary_text_process_flow.dart';

/// 其他应用的文字处理回写：对方返回文字后，按点按时的选区核对无误才替换。

class _FakeProcessTextService implements ProcessTextService {
  String? result;
  bool fail = false;

  @override
  Future<List<ProcessTextAction>> queryTextActions() async =>
      const <ProcessTextAction>[];

  @override
  Future<String?> processTextAction(
    String id,
    String text,
    bool readOnly,
  ) async {
    if (fail) throw PlatformException(code: 'boom');
    return result;
  }
}

Map<String, Object?> _p(String text) => {
  'type': 'paragraph',
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
  },
};

af.EditorState _document(List<Map<String, Object?>> blocks) {
  final state = af.EditorState(
    document: af.Document.fromJson({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(state.dispose);
  return state;
}

String _textOf(af.EditorState state) => state.document.root.children
    .map((af.Node node) => node.delta?.toPlainText() ?? '')
    .join('\n');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('replaces the selection with the processed text', () async {
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    final selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 6),
      end: af.Position(path: <int>[0], offset: 11),
    );
    state.selection = selection;
    final service = TextProcessActionsService(
      service: _FakeProcessTextService()..result = 'WORLD',
    );
    final replaced = await runDiaryTextProcessAction(
      state,
      actionId: 'upper',
      selection: selection,
      text: 'world',
      readOnly: false,
      service: service,
    );
    expect(replaced, isTrue);
    expect(_textOf(state), 'hello WORLD');
  });

  test('does nothing when the other app cancels or fails', () async {
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    final selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 6),
      end: af.Position(path: <int>[0], offset: 11),
    );
    state.selection = selection;
    final cancelled = TextProcessActionsService(
      service: _FakeProcessTextService()..result = null,
    );
    expect(
      await runDiaryTextProcessAction(
        state,
        actionId: 'x',
        selection: selection,
        text: 'world',
        readOnly: false,
        service: cancelled,
      ),
      isFalse,
    );
    final failed = TextProcessActionsService(
      service: _FakeProcessTextService()..fail = true,
    );
    expect(
      await runDiaryTextProcessAction(
        state,
        actionId: 'x',
        selection: selection,
        text: 'world',
        readOnly: false,
        service: failed,
      ),
      isFalse,
    );
    expect(_textOf(state), 'hello world');
  });

  test('does nothing when the result equals the source or read-only', () async {
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    final selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 6),
      end: af.Position(path: <int>[0], offset: 11),
    );
    state.selection = selection;
    final same = TextProcessActionsService(
      service: _FakeProcessTextService()..result = 'world',
    );
    expect(
      await runDiaryTextProcessAction(
        state,
        actionId: 'x',
        selection: selection,
        text: 'world',
        readOnly: false,
        service: same,
      ),
      isFalse,
    );
    final changed = TextProcessActionsService(
      service: _FakeProcessTextService()..result = 'WORLD',
    );
    expect(
      await runDiaryTextProcessAction(
        state,
        actionId: 'x',
        selection: selection,
        text: 'world',
        readOnly: true,
        service: changed,
      ),
      isFalse,
    );
    expect(_textOf(state), 'hello world');
  });

  test('does nothing when the selection moved meanwhile', () async {
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    final selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 6),
      end: af.Position(path: <int>[0], offset: 11),
    );
    state.selection = selection;
    final service = TextProcessActionsService(
      service: _FakeProcessTextService()..result = 'WORLD',
    );
    // 对方应用开着期间用户把选区移走了：不回写。
    state.selection = af.Selection.collapsed(
      af.Position(path: <int>[0], offset: 0),
    );
    expect(
      await runDiaryTextProcessAction(
        state,
        actionId: 'x',
        selection: selection,
        text: 'world',
        readOnly: false,
        service: service,
      ),
      isFalse,
    );
    expect(_textOf(state), 'hello world');
  });
}
