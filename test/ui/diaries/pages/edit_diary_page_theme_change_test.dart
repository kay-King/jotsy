import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/expressive_test_theme.dart';

/// 编辑页换主题（应用切换明暗）时正文颜色的回归测试。
///
/// 本地编辑页的正文样式直接读 `Theme.of(context).textTheme.bodyMedium`，
/// 且编辑器缓存的输入含 `Theme.of(context)`，主题变化时应重建——理论上
/// 没有上游 #130 那个“编辑器把样式连同 EditorStyle 存进 EditorState、只
/// 在换编辑器 widget 时更新”的 bug。这里用测试实证：亮暗切换后正文
/// RichText 的颜色必须跟到新主题，且光标与撤销记录不受影响。

void main() {
  late AppDatabase database;
  late SettingsService settings;
  late String diaryId;
  bool viewConfigured = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = await SettingsService.create();
    viewConfigured = false;
    diaryId = await database.createDiary(
      title: 'Rebuild probe',
      contentDocJson: '[{"insert":"正文 body text\\n"}]',
      contentText: '正文 body text',
      metadataJson: '{}',
    );
  });
  tearDown(() => database.close());

  // 同一棵树反复 pump（只换主题）：页面 State 与 EditorState 原样保留，
  // 测的才是“开着的编辑页换主题”，不是重新打开。view 属性只在第一次装配时
  // 设：每次重设都会发一次 didChangeMetrics，上游桌面选区服务收到后经
  // 100ms 防抖按它自己记的选区重刷一次，会把下面直接设的选区盖掉。
  Future<void> pumpEditPage(
    WidgetTester tester, {
    required Brightness brightness,
    Duration duration = ExpressiveMotion.fast,
    bool settle = true,
  }) async {
    if (!viewConfigured) {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      viewConfigured = true;
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          settingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: MaterialApp(
          themeAnimationDuration: duration,
          theme: expressiveTestTheme(brightness),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EditDiaryPage(diaryId: diaryId),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  EditorState bodyEditorState(WidgetTester tester) =>
      tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState;

  /// 正文里包含 [text] 的那一行实际绘制的文字颜色（读画出来的 RichText，
  /// 编辑器缓存了过期的 EditorStyle 时也能发现）。
  Color renderedColor(WidgetTester tester, String text) {
    final line = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(AppFlowyEditor),
            matching: find.byType(RichText),
          ),
        )
        .firstWhere((rich) => rich.text.toPlainText().contains(text));
    Color? color;
    line.text.visitChildren((span) {
      if (span is TextSpan && (span.text?.contains(text) ?? false)) {
        color = span.style?.color;
        return false;
      }
      return true;
    });
    return color ?? line.text.style!.color!;
  }

  Color bodyColor(Brightness brightness) =>
      expressiveTestTheme(brightness).textTheme.bodyMedium!.color!;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  // 应用切换明暗时 MaterialApp 按 themeAnimationDuration 补间主题（减少动画时
  // 为 0，直接换）。两种时长下打开着的编辑器都必须停在新主题的正文色上。
  for (final (label, duration) in <(String, Duration)>[
    ('with the theme animation', ExpressiveMotion.fast),
    ('when motion is reduced', Duration.zero),
  ]) {
    testWidgets('an open editor repaints its text in the new theme $label', (
      tester,
    ) async {
      await pumpEditPage(tester, brightness: Brightness.light);
      expect(renderedColor(tester, '正文'), bodyColor(Brightness.light));

      await pumpEditPage(
        tester,
        brightness: Brightness.dark,
        duration: duration,
      );
      expect(renderedColor(tester, '正文'), bodyColor(Brightness.dark));
      expect(renderedColor(tester, 'body text'), bodyColor(Brightness.dark));

      await pumpEditPage(
        tester,
        brightness: Brightness.light,
        duration: duration,
      );
      expect(renderedColor(tester, '正文'), bodyColor(Brightness.light));
      await unmount(tester);
      expect(tester.takeException(), isNull);
    });
  }

  // 换主题时编辑器按新输入重建（同一份 EditorState）：光标、输入法连接与
  // 撤销记录都必须原样保留，换完接着打字仍落在光标处，撤销照常。
  testWidgets('switching the theme keeps the caret, input and undo history', (
    tester,
  ) async {
    await pumpEditPage(tester, brightness: Brightness.light);
    final state = bodyEditorState(tester);

    // 经键盘服务聚焦（不点按正文：点按会让桌面选区服务记下点按位置的选区，
    // 而下面直接设的选区不同步它，之后任何一次 didChangeMetrics 都会把
    // 选区刷回点按位置）。
    state.service.keyboardService?.enable();
    final caret = Selection.collapsed(Position(path: [0], offset: 3));
    state.selection = caret;
    await tester.pumpAndSettle();
    expect(state.selection, caret);
    expect(tester.testTextInput.hasAnyClients, isTrue);

    // 经输入法打字。编辑值由输入法自己记着（上游打完字不回写，测试的
    // editingState 只反映框架发出的值），这里像真的键盘一样自己累积。
    var attached = tester.testTextInput.editingState!;
    var ime = TextEditingValue(
      text: attached['text'] as String,
      selection: TextSelection.collapsed(
        offset: attached['selectionBase'] as int,
      ),
    );
    void type(String text) {
      final at = ime.selection.baseOffset;
      ime = TextEditingValue(
        text: ime.text.replaceRange(at, at, text),
        selection: TextSelection.collapsed(offset: at + text.length),
      );
      tester.testTextInput.updateEditingValue(ime);
    }

    // 先打一个字：有了撤销记录，光标停在它后面。
    type('A');
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      extractPlainTextFromAppFlowyDocument(state.document),
      contains('正文 Abody text'),
    );
    final typed = Selection.collapsed(Position(path: [0], offset: 4));
    expect(state.selection, typed);
    final undoDepth = state.undoManager.undoStack.length;
    expect(undoDepth, greaterThan(0));

    await pumpEditPage(tester, brightness: Brightness.dark, settle: false);
    // 逐帧走完主题补间（光标闪烁让 pumpAndSettle 停不下来），并确认补间
    // 期间确实换过多次编辑器 widget（否则本用例没测到什么）。
    final editors = Set<Widget>.identity();
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      editors.add(tester.widget(find.byType(AppFlowyEditor)));
      expect(bodyEditorState(tester).selection, typed);
    }
    expect(editors.length, greaterThan(2));
    expect(renderedColor(tester, '正文'), bodyColor(Brightness.dark));
    expect(tester.testTextInput.hasAnyClients, isTrue);

    // 同一份 EditorState：光标与撤销记录原样。
    expect(identical(bodyEditorState(tester), state), isTrue);
    expect(state.undoManager.undoStack.length, undoDepth);

    // 换完主题接着打字仍落在光标处，撤销照常。输入法连接没有断开重连：
    // 测试绑定里存的编辑值还是打字前的（编辑器不回显输入法发起的改动），
    // 这里继续用上面自己累积的值（与编辑器内部的当前值一致），不再从
    // 绑定重读。
    type('B');
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      extractPlainTextFromAppFlowyDocument(state.document),
      contains('正文 ABbody text'),
    );
    expect(
      state.selection,
      Selection.collapsed(Position(path: [0], offset: 5)),
    );
    state.undoManager.undo();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      extractPlainTextFromAppFlowyDocument(state.document),
      isNot(contains('B')),
    );

    await unmount(tester);
    expect(tester.takeException(), isNull);
  });
}
