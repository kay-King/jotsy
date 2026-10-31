import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页正文与手机键盘的配合：在底部打字时新内容跟着上升、离工具栏留出
/// 空隙；点了屏幕下部的字再弹起键盘，那一行随键盘一起被顶上去；只改格式
/// 不拽动视口。
///
/// 注意：软键盘“选择”模式的扩选（[SoftKeyboardSelectionKeys]）原来走
/// Flutter 的 ExtendSelection Intent、由 QuillRawEditor 的 Action 执行；
/// AppFlowy 不注册这类 Action，其自带的 shift+方向键命令又依赖
/// `HardwareKeyboard.isShiftPressed`（虚拟键盘的 shift 到不了那里，
/// flutter/flutter#185849），这条链路需另行适配，本文件暂不覆盖。
void main() {
  late AppDatabase database;
  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
  });
  tearDown(() => database.close());

  Future<void> pumpCreatePage(
    WidgetTester tester, {
    double keyboardHeight = 300,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  EditorState bodyEditorState(WidgetTester tester) => tester
      .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
      .editorState;

  ScrollPosition bodyScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(AppFlowyEditor),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            )
            .first,
      )
      .position;

  double caretBottom(WidgetTester tester) {
    final editorState = bodyEditorState(tester);
    final selection = editorState.selection!;
    final node = editorState.document.nodeAtPath(selection.end.path)!;
    final selectable = node.selectable!;
    final localCaret = selectable.getCursorRectInPosition(
      selection.end,
      shiftWithBaseOffset: true,
    )!;
    final globalCaret = selectable.transformRectToGlobal(
      localCaret,
      shiftWithBaseOffset: true,
    );
    return globalCaret.bottom;
  }

  double toolbarTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(DiaryFloatingToolbar)).dy;

  // 与编辑页的光标空隙一致：光标不贴着工具栏。
  const caretClearance = 40.0;

  /// 正文写满 [lines] 行，光标停在末尾。
  Future<void> fillBody(WidgetTester tester, {int lines = 40}) async {
    final editorState = bodyEditorState(tester);
    final text = List<String>.generate(
      lines,
      (index) => 'line $index',
    ).join('\n');
    final node = editorState.document.root.children.first;
    final transaction = editorState.transaction;
    transaction.replaceText(node, 0, node.delta!.length, text);
    await editorState.apply(transaction);
    final endNode = editorState.document.root.children.first;
    // 注意：updateSelectionWithReason 默认参数下 completer 永不完成（上游
    // bug），测试里直接走同步的 selection setter，同样触发 selectionNotifier。
    editorState.selection = Selection.collapsed(
      Position(path: endNode.path, offset: endNode.delta!.length),
    );
    await tester.pumpAndSettle();
  }

  /// 在光标处插入文字并把光标移到插入末尾（走编辑器事务；输入法链路在
  /// AppFlowy 内是私有的，这里验证的是插入后光标跟随把新行顶到工具栏上方
  /// 的行为，与真机打字走同一条选区变化 → 揭示链路）。
  Future<void> typeAtCaret(WidgetTester tester, String text) async {
    final editorState = bodyEditorState(tester);
    final selection = editorState.selection!;
    final node = editorState.document.nodeAtPath(selection.end.path)!;
    final transaction = editorState.transaction;
    transaction.insertText(node, selection.end.offset, text);
    await editorState.apply(transaction);
    editorState.selection = Selection.collapsed(
      Position(
        path: node.path,
        offset: selection.end.offset + text.length,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('typing at the bottom keeps new lines above the toolbar', (
    tester,
  ) async {
    await pumpCreatePage(tester);
    await fillBody(tester);
    final position = bodyScroll(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final offsetBefore = position.pixels;

    for (var index = 0; index < 5; index += 1) {
      await typeAtCaret(tester, '\nnew line $index');
      expect(
        toolbarTop(tester) - caretBottom(tester),
        greaterThanOrEqualTo(caretClearance),
      );
    }
    expect(position.pixels, greaterThan(offsetBefore));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('tapped bottom text rides up with the rising keyboard', (
    tester,
  ) async {
    await pumpCreatePage(tester, keyboardHeight: 0);
    await fillBody(tester);
    final position = bodyScroll(tester);
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pumpAndSettle();

    // 键盘未弹起时点屏幕下部的一行：弹起后这一块会被键盘盖住。
    await tester.tapAt(const Offset(40, 700));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(caretBottom(tester), greaterThan(900 - 300));

    // 键盘逐帧升高：每一帧光标都在键盘上方，而不是等停稳后才跳上来。
    for (var step = 1; step <= 10; step += 1) {
      final inset = 30.0 * step;
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      expect(caretBottom(tester), lessThanOrEqualTo(900 - inset));
    }
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(
      toolbarTop(tester) - caretBottom(tester),
      greaterThanOrEqualTo(caretClearance),
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('formatting scrolls the selection into view', (tester) async {
    await pumpCreatePage(tester);
    await fillBody(tester);
    final position = bodyScroll(tester);
    position.jumpTo(0);
    await tester.pumpAndSettle();

    // 格式化视口外的选区：AppFlowy 的滚动服务在选区通知后自动把选区滚回
    // 可见（框架行为，与 Quill 时代“只改格式不拽动视口”不同；工具栏的
    // 加粗走 toggleAttribute，同样经这条链路）。
    final editorState = bodyEditorState(tester);
    final node = editorState.document.root.children.first;
    final transaction = editorState.transaction;
    transaction.formatText(node, 0, 4, const <String, dynamic>{'bold': true});
    transaction.afterSelection = transaction.beforeSelection;
    await editorState.apply(transaction);
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
