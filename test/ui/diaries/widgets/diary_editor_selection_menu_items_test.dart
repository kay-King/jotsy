import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/text_process_actions_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor_selection_menu_items.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../support/expressive_test_theme.dart';

/// 日记正文选区菜单的菜单项组装：主行、分享与文字处理。

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

class _FakeProcessTextService implements ProcessTextService {
  @override
  Future<List<ProcessTextAction>> queryTextActions() async =>
      const <ProcessTextAction>[ProcessTextAction('translate', 'Google 翻译')];

  @override
  Future<String?> processTextAction(
    String id,
    String text,
    bool readOnly,
  ) async => null;
}

Future<List<String>> _labels(
  WidgetTester tester,
  af.EditorState state, {
  required bool editable,
}) async {
  var labels = const <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          labels = diaryEditorSelectionMenuItems(
            context,
            state,
            editable: editable,
            dismiss: () {},
            afterCopy: () {},
          ).map((AppTextMenuAction action) => action.label).toList();
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return labels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TextProcessActionsService.debugOverride(null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows cut, copy, paste, select all and share for a range', (
    tester,
  ) async {
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    state.selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 0),
      end: af.Position(path: <int>[0], offset: 5),
    );
    final labels = await _labels(tester, state, editable: true);
    expect(labels, <String>['剪切', '复制', '粘贴', '全选', '分享']);
  });

  testWidgets('read-only keeps copy, select all and share', (tester) async {
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    state.selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 0),
      end: af.Position(path: <int>[0], offset: 5),
    );
    final labels = await _labels(tester, state, editable: false);
    expect(labels, <String>['复制', '全选', '分享']);
  });

  testWidgets('collapsed selection shows only paste and select all', (
    tester,
  ) async {
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    state.selection = af.Selection.collapsed(
      af.Position(path: <int>[0], offset: 3),
    );
    final labels = await _labels(tester, state, editable: true);
    expect(labels, <String>['粘贴', '全选']);
  });

  testWidgets('process text actions appear after a refresh', (tester) async {
    final service = TextProcessActionsService(
      service: _FakeProcessTextService(),
    );
    TextProcessActionsService.debugOverride(service);
    await service.refresh();
    final state = _document(<Map<String, Object?>>[_p('hello world')]);
    state.selection = af.Selection(
      start: af.Position(path: <int>[0], offset: 0),
      end: af.Position(path: <int>[0], offset: 5),
    );
    final labels = await _labels(tester, state, editable: true);
    expect(labels, <String>['剪切', '复制', '粘贴', '全选', '分享', 'Google 翻译']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
