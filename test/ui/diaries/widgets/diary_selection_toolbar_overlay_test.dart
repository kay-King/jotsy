import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_toolbar_overlay.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../support/expressive_test_theme.dart';

/// 手机端正文选区浮层：有范围选区时出现玻璃胶囊，点复制后收成光标。
///
/// 桌面端不使用本浮层（右键菜单走 `AppFlowyEditor(contextMenuBuilder:)`），
/// 这里只测手机分支。

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

Future<af.EditorState> _pump(
  WidgetTester tester,
  List<Map<String, Object?>> blocks,
) async {
  final state = _document(blocks);
  final focus = FocusNode();
  addTearDown(focus.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        af.AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DiarySelectionToolbarOverlay(
          editorState: state,
          editable: true,
          child: af.AppFlowyEditor(
            editorState: state,
            focusNode: focus,
            editorStyle: af.EditorStyle.mobile(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  focus.requestFocus();
  await tester.pump();
  return state;
}

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

  testWidgets('shows the glass capsule for a ranged selection', (tester) async {
    final state = await _pump(tester, <Map<String, Object?>>[
      _p('hello world'),
    ]);
    state.selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 0),
      end: af.Position(path: <int>[0], offset: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('剪切'), findsOneWidget);
    expect(find.text('粘贴'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
  });

  testWidgets('copy collapses the selection to a cursor', (tester) async {
    final state = await _pump(tester, <Map<String, Object?>>[
      _p('hello world'),
    ]);
    state.selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 0),
      end: af.Position(path: <int>[0], offset: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
    await tester.tap(find.text('复制'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(clipboardText, 'hello');
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
    expect(state.selection?.isCollapsed, isTrue);
  });

  testWidgets('hides when the selection collapses', (tester) async {
    final state = await _pump(tester, <Map<String, Object?>>[
      _p('hello world'),
    ]);
    state.selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 0),
      end: af.Position(path: <int>[0], offset: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppTextSelectionToolbar), findsOneWidget);
    state.selection = af.Selection.collapsed(
      af.Position(path: <int>[0], offset: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
  });

  testWidgets('does nothing on desktop', (tester) async {
    final state = await _pump(tester, <Map<String, Object?>>[
      _p('hello world'),
    ]);
    state.selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 0),
      end: af.Position(path: <int>[0], offset: 5),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppTextSelectionToolbar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
