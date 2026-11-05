import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar.dart';

import '../../../support/expressive_test_theme.dart';

/// 工具栏图片 / 视频按钮在能拍摄的平台上先弹来源菜单（从相册选择 / 拍照、
/// 录像），附件仍直接打开选择器；不能拍摄的平台保持原样。
void main() {
  Future<void> pumpToolbar(
    WidgetTester tester, {
    required EditorState editorState,
    List<DiaryToolbarItem> order = kDefaultDiaryToolbarOrder,
    void Function(DiaryMediaKind)? onMediaPressed,
    void Function(DiaryMediaKind)? onCameraPressed,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: DiaryFloatingToolbar(
              editorState: editorState,
              order: order,
              onMediaPressed: onMediaPressed,
              onCameraPressed: onCameraPressed,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  EditorState editorState() => EditorState(document: Document.blank());

  const order = <DiaryToolbarItem>[
    DiaryToolbarItem.undo,
    DiaryToolbarItem.image,
    DiaryToolbarItem.video,
    DiaryToolbarItem.attachment,
  ];

  group('camera capture source menu', () {
    testWidgets('image and video ask for the source before opening anything', (
      tester,
    ) async {
      final picked = <DiaryMediaKind>[];
      final captured = <DiaryMediaKind>[];
      await pumpToolbar(
        tester,
        editorState: editorState(),
        order: order,
        onMediaPressed: picked.add,
        onCameraPressed: captured.add,
      );

      await tester.tap(find.byTooltip('插入图片'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      expect(find.text('从相册选择'), findsOneWidget);
      expect(find.text('录像'), findsNothing);
      // 菜单落在工具栏上方（工具栏贴底，下方是键盘）。
      expect(
        tester.getBottomLeft(find.text('拍照')).dy,
        lessThan(tester.getTopLeft(find.byTooltip('插入图片')).dy),
      );
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();
      expect(captured, [DiaryMediaKind.image]);
      expect(find.text('拍照'), findsNothing);

      await tester.tap(find.byTooltip('插入视频'));
      await tester.pumpAndSettle();
      expect(find.text('拍照'), findsNothing);
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      expect(picked, [DiaryMediaKind.video]);
      expect(find.text('录像'), findsNothing);

      await tester.tap(find.byTooltip('插入视频'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('录像'));
      await tester.pumpAndSettle();
      expect(captured, [DiaryMediaKind.image, DiaryMediaKind.video]);

      // 附件不能拍摄，仍直接打开选择器。
      await tester.tap(find.byTooltip('插入附件'));
      await tester.pumpAndSettle();
      expect(picked, [DiaryMediaKind.video, DiaryMediaKind.attachment]);
      expect(find.text('从相册选择'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the source menu also opens from inside More', (tester) async {
      final captured = <DiaryMediaKind>[];
      final l10n = lookupAppLocalizations(const Locale('zh'));
      await pumpToolbar(
        tester,
        editorState: editorState(),
        onMediaPressed: (_) {},
        onCameraPressed: captured.add,
      );
      await tester.tap(find.byTooltip(l10n.diaryToolbarMoreTools));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('插入图片'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();
      expect(captured, [DiaryMediaKind.image]);
      // 选完来源，「更多」面板原样开着。
      expect(find.byTooltip(l10n.diaryToolbarHideMoreTools), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without camera capture the tools open the picker at once', (
      tester,
    ) async {
      final picked = <DiaryMediaKind>[];
      await pumpToolbar(
        tester,
        editorState: editorState(),
        order: order,
        onMediaPressed: picked.add,
      );
      await tester.tap(find.byTooltip('插入图片'));
      await tester.tap(find.byTooltip('插入视频'));
      await tester.pumpAndSettle();
      expect(picked, [DiaryMediaKind.image, DiaryMediaKind.video]);
      expect(find.text('从相册选择'), findsNothing);
    });
  });
}
