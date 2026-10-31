import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_playback_gestures.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_builder.dart';

import '../../../support/expressive_test_theme.dart';
import '../../../support/fake_video_player.dart';

/// AppFlowy 版：视频是独立块节点（[kDiaryBlockVideo]），键盘/焦点断言与
/// Quill 时代一致——点视频控件不弹正文键盘、不动正文选区。

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness video buttons and seeking keep keyboard hidden while body remains editable',
      (tester) async {
        final focus = FocusNode();
        final player = FakeVideoPlayer();
        final editorState = _editorState();
        addTearDown(editorState.dispose);
        addTearDown(focus.dispose);
        final service = _KeyboardCheckExportService();
        await tester.pumpWidget(
          MaterialApp(
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
                      kDiaryBlockVideo: DiaryVideoEmbedBuilder(
                        playerFactory: (_) => player,
                        exportService: service,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // 选区在挂载后设置（挂载前设置会被编辑器初始化重置），键盘保持收起。
        editorState.selection = Selection.collapsed(
          Position(path: [1], offset: 0),
        );
        tester.testTextInput.hide();
        await tester.pump();
        final selection = editorState.selection;
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('播放视频').last);
        await tester.pumpAndSettle();
        expect(player.value.isPlaying, isTrue);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        expect(editorState.selection, selection);
        await tester.tap(find.byTooltip('暂停视频'));
        await tester.pumpAndSettle();
        expect(player.value.isPlaying, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('播放视频').last);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.byTooltip('暂停视频'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        final slider = find.byType(Slider);
        await tester.drag(slider, const Offset(60, 0));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.canRequestFocus, isTrue);
        await tester.tap(find.byTooltip('导出视频'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.widgetWithText(TextButton, '取消'));
        await tester.pumpAndSettle();
        expect(service.exportCount, 0);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('全屏播放'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byTooltip('退出全屏'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(focus.hasFocus, isFalse);
        final editorRect = tester.getRect(find.byType(AppFlowyEditor));
        await tester.tapAt(
          Offset(editorRect.left + 30, editorRect.bottom - 14),
        );
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('video tap guard only consumes the video node itself', () {
    final editorState = _editorState();
    addTearDown(editorState.dispose);
    final videoNode = editorState.document.root.children[0];
    final paragraphNode = editorState.document.root.children[1];
    expect(isDiaryPlaybackTap(editorState, videoNode), isTrue);
    expect(isDiaryPlaybackTap(editorState, paragraphNode), isFalse);
  });
}

EditorState _editorState() {
  final document = Document.blank();
  document.insert(
    [0],
    [
      Node(
        type: kDiaryBlockVideo,
        attributes: {kDiaryBlockUrlKey: '/video.mp4'},
      ),
    ],
  );
  document.insert([1], [paragraphNode(text: '正文继续输入')]);
  return EditorState(document: document);
}

class _KeyboardCheckExportService extends VideoExportService {
  int exportCount = 0;
  @override
  Future<void> saveToGallery(String source) async {
    exportCount++;
  }
}
