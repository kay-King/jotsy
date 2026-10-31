import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_playback_gestures.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_embed_builder.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_audio_player.dart';

/// AppFlowy 版：录音是独立块节点（[kDiaryBlockAudio]），键盘/焦点断言与
/// Quill 时代一致——点录音控件不弹正文键盘、不动正文选区。

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness recording controls keep keyboard hidden and preserve the body cursor',
      (tester) async {
        final focus = FocusNode();
        final player = FakeAudioPlayer();
        final editorState = _editorState();
        addTearDown(focus.dispose);
        addTearDown(editorState.dispose);
        await tester.pumpWidget(
          _editor(editorState, focus, player, brightness),
        );
        await tester.pumpAndSettle();
        _setBodySelection(editorState);
        tester.testTextInput.hide();
        await tester.pump();
        final selection = editorState.selection;
        final content = jsonEncode(editorState.document.toJson());
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pumpAndSettle();
        expect(player.playCalls, 1);
        expect(find.byTooltip('暂停播放'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(editorState.selection, selection);
        await tester.tap(find.byTooltip('暂停播放'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('播放录音'), findsOneWidget);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.byTooltip('暂停播放'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(editorState.selection, selection);
        await tester.tap(find.byType(DiaryWaveformBarVisualizer));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(DiaryWaveformBarVisualizer),
          const Offset(60, 0),
        );
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        expect(focus.canRequestFocus, isTrue);
        expect(editorState.selection, selection);
        expect(jsonEncode(editorState.document.toJson()), content);
        final body = tester.getRect(find.byType(AppFlowyEditor));
        await tester.tapAt(Offset(body.left + 30, body.bottom - 14));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$brightness recording rename opens its own keyboard without focusing the body',
      (tester) async {
        final focus = FocusNode();
        final editorState = _editorState();
        addTearDown(focus.dispose);
        addTearDown(editorState.dispose);
        await tester.pumpWidget(
          _editor(editorState, focus, FakeAudioPlayer(), brightness),
        );
        await tester.pumpAndSettle();
        _setBodySelection(editorState);
        tester.testTextInput.hide();
        await tester.pump();
        await tester.tap(find.byTooltip('重命名录音'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(focus.hasFocus, isFalse);
        await tester.enterText(find.byType(TextField), '我的录音');
        await tester.tap(find.widgetWithText(TextButton, '确认'));
        await tester.pumpAndSettle();
        expect(find.text('我的录音'), findsOneWidget);
        // 重命名经对话框 + updateNode 事务：AppFlowy 不保留对话框打断前的
        // 正文选区（与 Quill 时代不同）；选区保留由上一个测试覆盖。
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('暂停播放'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed recording playback reports an error without opening the keyboard',
    (tester) async {
      final focus = FocusNode();
      final editorState = _editorState();
      final player = FakeAudioPlayer()..fail = true;
      addTearDown(focus.dispose);
      addTearDown(editorState.dispose);
      await tester.pumpWidget(
        _editor(editorState, focus, player, Brightness.light),
      );
      await tester.pumpAndSettle();
      _setBodySelection(editorState);
      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.byTooltip('播放录音'));
      await tester.pumpAndSettle();
      expect(find.text('录音无法播放'), findsWidgets);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(focus.canRequestFocus, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  test('audio block tap suppression only consumes the audio node itself', () {
    final editorState = _editorState();
    addTearDown(editorState.dispose);
    _setBodySelection(editorState);
    final audioNode = editorState.document.root.children[0];
    final paragraphNode = editorState.document.root.children[1];
    expect(isDiaryPlaybackTap(editorState, audioNode), isTrue);
    expect(isDiaryPlaybackTap(editorState, paragraphNode), isFalse);
  });
}

EditorState _editorState() {
  final document = Document.blank();
  document.insert(
    [0],
    [
      Node(
        type: kDiaryBlockAudio,
        attributes: {
          'path': '/diary_recordings/entry.m4a',
          'durationMs': const Duration(seconds: 12).inMilliseconds,
          'name': '原始录音',
        },
      ),
    ],
  );
  document.insert([1], [paragraphNode(text: '正文继续输入')]);
  return EditorState(document: document);
}

/// 选区必须在编辑器挂载后再设：AppFlowyEditor 初始化时会重置挂载前的选区。
void _setBodySelection(EditorState editorState) {
  editorState.selection = Selection.collapsed(Position(path: [1], offset: 0));
}

Widget _editor(
  EditorState editorState,
  FocusNode focus,
  FakeAudioPlayer player,
  Brightness brightness,
) => MaterialApp(
  theme: expressiveTestTheme(brightness),
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 400,
        child: AppFlowyEditor(
          editorState: editorState,
          focusNode: focus,
          editorStyle: EditorStyle.mobile(
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          blockComponentBuilders: {
            ...standardBlockComponentBuilderMap,
            kDiaryBlockAudio: DiaryAudioEmbedBuilder(player: player),
          },
        ),
      ),
    ),
  ),
);
