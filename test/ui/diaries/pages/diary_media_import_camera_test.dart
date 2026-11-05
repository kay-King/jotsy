import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_appflowy.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_floating_toolbar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页里的拍照 / 录像：工具栏来源菜单打开后正文仍保持焦点、权限被拒时
/// 提示对应文案；`/` 菜单里的“拍照 / 录像”走同一条拍摄插入链路。
void main() {
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const camera = MethodChannel('com.jotsy.diary/camera_capture');
  late Directory root;
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    root = await Directory.systemTemp.createTemp('jotsy_camera_page_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => root.path);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(camera, null);
    debugDefaultTargetPlatformOverride = null;
    await database.close();
    await root.delete(recursive: true);
  });

  Future<void> pumpCreatePage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    // 悬浮工具栏只在软键盘弹起且正文有焦点时出现。
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EditDiaryPage(entryMode: EditDiaryEntryMode.create),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> focusEditor(WidgetTester tester) async {
    await tester.tap(find.byType(AppFlowyEditor));
    await tester.pumpAndSettle();
  }

  Future<void> openImageSourceMenu(WidgetTester tester) async {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    if (find.byTooltip('插入图片').evaluate().isEmpty) {
      await tester.tap(find.byTooltip(l10n.diaryToolbarMoreTools));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('插入图片'));
    await tester.pumpAndSettle();
    expect(find.text('拍照'), findsOneWidget);
  }

  EditorState editorStateOf(WidgetTester tester) =>
      tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

  bool hasMediaNode(WidgetTester tester, String type) {
    var found = false;
    void walk(Node node) {
      if (node.type == type) found = true;
      for (final child in node.children) {
        walk(child);
      }
    }

    for (final child in editorStateOf(tester).document.root.children) {
      walk(child);
    }
    return found;
  }

  /// 复制拍到的文件是真实文件 IO：在 testWidgets 里须经 runAsync 离开假
  /// 时钟推进，直到正文里出现媒体节点（与 edit_diary_day_photos_test 的
  /// waitForImages 同一做法）。
  Future<void> waitForMediaNode(
    WidgetTester tester,
    String type, {
    int count = 1,
  }) async {
    for (var i = 0; i < 60; i++) {
      var found = 0;
      void walk(Node node) {
        if (node.type == type) found++;
        for (final child in node.children) {
          walk(child);
        }
      }

      for (final child in editorStateOf(tester).document.root.children) {
        walk(child);
      }
      if (found >= count) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'the toolbar camera menu keeps the editor focused and reports a refused '
    'camera permission',
    (tester) async {
      try {
        final requests = <Object?>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(camera, (call) async {
              requests.add(call.arguments);
              throw PlatformException(code: 'camera_permission_denied');
            });
        await pumpCreatePage(tester);
        await focusEditor(tester);
        final editorState = editorStateOf(tester);
        final original = diaryDocumentToStoredJson(editorState.document);
        final focus = FocusManager.instance.primaryFocus;
        expect(focus, isNotNull);

        await openImageSourceMenu(tester);
        // 打开菜单不抢焦点：正文仍在编辑，工具栏（菜单的锚点）不会卸载。
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(find.byType(DiaryFloatingToolbar), findsOneWidget);

        await tester.tap(find.text('拍照'));
        await tester.pumpAndSettle();

        expect(requests, [
          {'kind': 'image'},
        ]);
        final l10n = lookupAppLocalizations(const Locale('zh'));
        expect(
          find.text(l10n.diaryMediaCameraPermissionDenied),
          findsOneWidget,
        );
        expect(diaryDocumentToStoredJson(editorState.document), original);
        final importer = tester
            .widget<DiaryFloatingToolbar>(find.byType(DiaryFloatingToolbar))
            .mediaImportController!;
        expect(importer.isBusy, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('the slash menu takes a photo through the same capture flow', (
    tester,
  ) async {
    try {
      final captured = File(
        p.join(root.path, 'diary_camera', 'batch', 'IMG_slash.jpg'),
      );
      await tester.runAsync(() async {
        await captured.create(recursive: true);
        await captured.writeAsBytes([7, 7, 7]);
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            camera,
            (_) async => [
              {'name': 'IMG_slash.jpg', 'path': captured.path, 'size': 3},
            ],
          );
      await pumpCreatePage(tester);
      await focusEditor(tester);
      final editorState = editorStateOf(tester);

      // 在行首敲 `/`：浮层弹出块菜单。
      final firstNode = editorState.document.root.children.first;
      final transaction = editorState.transaction;
      transaction.insertText(firstNode, 0, '/');
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: firstNode.path, offset: 1),
      );
      await tester.pumpAndSettle();

      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('录像'), findsOneWidget);

      await tester.tap(find.text('拍照'));
      await waitForMediaNode(tester, 'image');
      // 暂存清理在插入返回后的 finally 里：等导入控制器空闲（清理已做完）
      // 再断言，免得与清理竞态。
      final importer = tester
          .widget<DiaryFloatingToolbar>(find.byType(DiaryFloatingToolbar))
          .mediaImportController!;
      for (var i = 0; i < 100 && importer.isBusy; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(importer.isBusy, isFalse);

      // 斜杠已删掉（只看段落文字：图片节点的文件路径里本身就有 `/`，不能
      // 对整份 JSON 做 contains 判断），拍到的照片插进了正文，暂存已清理。
      expect(
        editorState.document.root.children.first.delta?.toPlainText().contains(
          '/',
        ),
        isFalse,
      );
      expect(hasMediaNode(tester, 'image'), isTrue);
      expect(await tester.runAsync(() => captured.exists()), isFalse);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the slash menu hides photo and video off Android', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await pumpCreatePage(tester);
      await focusEditor(tester);
      final editorState = editorStateOf(tester);

      final firstNode = editorState.document.root.children.first;
      final transaction = editorState.transaction;
      transaction.insertText(firstNode, 0, '/');
      await editorState.apply(transaction);
      editorState.selection = Selection.collapsed(
        Position(path: firstNode.path, offset: 1),
      );
      await tester.pumpAndSettle();

      // 桌面端 `/` 菜单本就不弹浮层（见 DiaryMentionPopup），拍照项无处可现。
      expect(find.text('拍照'), findsNothing);
      expect(find.text('录像'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
