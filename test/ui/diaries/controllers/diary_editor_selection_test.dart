import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_selection.dart';

/// 编辑器选区菜单的剪贴板操作（直接对 EditorState）。
///
/// 剪贴板经 `SystemChannels.platform` 模拟：`setData` 记下文字，`getData`
/// 返回记下的文字。

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

  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            final text = clipboardText;
            return text == null ? null : <String, Object?>{'text': text};
          }
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('diaryEditorSelectedPlainText', () {
    test('returns null without a ranged selection', () {
      final state = _document(<Map<String, Object?>>[_p('hello')]);
      expect(diaryEditorSelectedPlainText(state), isNull);
      state.selection = af.Selection.collapsed(
        af.Position(path: <int>[0], offset: 2),
      );
      expect(diaryEditorSelectedPlainText(state), isNull);
    });

    test('returns the selected text of one paragraph', () {
      final state = _document(<Map<String, Object?>>[_p('hello world')]);
      state.selection = af.Selection(
        start: af.Position(path: <int>[0], offset: 6),
        end: af.Position(path: <int>[0], offset: 11),
      );
      expect(diaryEditorSelectedPlainText(state), 'world');
    });

    test('joins several paragraphs with newlines', () {
      final state = _document(<Map<String, Object?>>[
        _p('first'),
        _p('second'),
      ]);
      state.selection = af.Selection(
        start: af.Position(path: <int>[0], offset: 0),
        end: af.Position(path: <int>[1], offset: 6),
      );
      expect(diaryEditorSelectedPlainText(state), 'first\nsecond');
    });
  });

  group('copy and cut', () {
    test('copy writes the selected plain text to the clipboard', () async {
      final state = _document(<Map<String, Object?>>[_p('hello world')]);
      state.selection = af.Selection(
        start: af.Position(path: <int>[0], offset: 0),
        end: af.Position(path: <int>[0], offset: 5),
      );
      await copyDiaryEditorSelection(state);
      expect(clipboardText, 'hello');
      expect(_textOf(state), 'hello world');
    });

    test('cut copies then deletes the selection', () async {
      final state = _document(<Map<String, Object?>>[_p('hello world')]);
      state.selection = af.Selection(
        start: af.Position(path: <int>[0], offset: 0),
        end: af.Position(path: <int>[0], offset: 5),
      );
      await cutDiaryEditorSelection(state, editable: true);
      expect(clipboardText, 'hello');
      expect(_textOf(state), ' world');
    });

    test('cut does nothing when read-only', () async {
      final state = _document(<Map<String, Object?>>[_p('hello world')]);
      state.selection = af.Selection(
        start: af.Position(path: <int>[0], offset: 0),
        end: af.Position(path: <int>[0], offset: 5),
      );
      await cutDiaryEditorSelection(state, editable: false);
      expect(clipboardText, isNull);
      expect(_textOf(state), 'hello world');
    });
  });

  group('paste and replace', () {
    test('paste inserts clipboard lines as paragraphs', () async {
      final state = _document(<Map<String, Object?>>[_p('')]);
      state.selection = af.Selection.collapsed(
        af.Position(path: <int>[0], offset: 0),
      );
      clipboardText = 'one\ntwo';
      await pasteDiaryEditorPlainText(state, editable: true);
      expect(_textOf(state), 'one\ntwo');
    });

    test('paste replaces the selection', () async {
      final state = _document(<Map<String, Object?>>[_p('hello world')]);
      state.selection = af.Selection(
        start: af.Position(path: <int>[0], offset: 6),
        end: af.Position(path: <int>[0], offset: 11),
      );
      clipboardText = 'there';
      await pasteDiaryEditorPlainText(state, editable: true);
      expect(_textOf(state), 'hello there');
    });

    test(
      'paste does nothing when read-only or the clipboard is empty',
      () async {
        final state = _document(<Map<String, Object?>>[_p('keep')]);
        state.selection = af.Selection.collapsed(
          af.Position(path: <int>[0], offset: 0),
        );
        await pasteDiaryEditorPlainText(state, editable: true);
        expect(_textOf(state), 'keep');
        clipboardText = 'nope';
        await pasteDiaryEditorPlainText(state, editable: false);
        expect(_textOf(state), 'keep');
      },
    );

    test(
      'insertDiaryEditorPlainText replaces the selection line by line',
      () async {
        final state = _document(<Map<String, Object?>>[_p('aaa bbb')]);
        state.selection = af.Selection(
          start: af.Position(path: <int>[0], offset: 4),
          end: af.Position(path: <int>[0], offset: 7),
        );
        await insertDiaryEditorPlainText(state, 'x\ny', editable: true);
        expect(_textOf(state), 'aaa x\ny');
      },
    );
  });

  group('selectAllDiaryEditor', () {
    test('selects the whole document', () {
      final state = _document(<Map<String, Object?>>[
        _p('first'),
        _p('second'),
      ]);
      state.selection = af.Selection.collapsed(
        af.Position(path: <int>[0], offset: 0),
      );
      selectAllDiaryEditor(state);
      expect(diaryEditorSelectedPlainText(state), 'first\nsecond');
    });
  });
}
