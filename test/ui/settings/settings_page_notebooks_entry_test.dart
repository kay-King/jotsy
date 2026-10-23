import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/notebooks/pages/notebooks_page.dart';
import 'package:node_diary/ui/settings/pages/app_features_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

import '../../support/diary_drafts_harness.dart';

/// 设置首页的“日记本”入口：紧跟“标签管理”，点按进入日记本管理页；日记本
/// 功能关闭时隐藏。“功能管理”入口紧跟“编辑器设置”。
void main() {
  testWidgets('settings home links to the notebooks page', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();

    final entry = find.text('日记本');
    expect(entry, findsOneWidget);
    expect(find.text('整理、排序、合并你的日记本'), findsOneWidget);
    expect(find.byIcon(Icons.book_outlined), findsOneWidget);
    // 位置在“标签管理”之后。
    expect(
      tester.getTopLeft(entry).dy,
      greaterThan(
        tester.getTopLeft(find.text(h.l10n.settingsTagManagement)).dy,
      ),
    );

    await tester.tap(entry);
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.byType(NotebooksPage), findsOneWidget);
    await h.unmount();
  });

  testWidgets('notebooks entry is hidden when notebooks are turned off', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.settings.setAppFeaturesRaw('{"notebooks":false}');
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('整理、排序、合并你的日记本'), findsNothing);
    expect(find.byIcon(Icons.book_outlined), findsNothing);
    // 分组卡结构下入口是卡内平铺的行：隐藏日记本后，标签管理与数据与
    // 隐私直接相邻，行距与第一组里相邻两行（外观与语言→编辑器设置）
    // 一致，不留双倍间隔。
    double pitch(String first, String second) =>
        tester.getTopLeft(find.text(second)).dy -
        tester.getTopLeft(find.text(first)).dy;
    expect(
      pitch(h.l10n.settingsTagManagement, h.l10n.settingsDataPrivacy),
      // 容差 2px：两组标题文字的取整可差 1px；要防的是隐藏后留下
      // 双倍行距（约 +70px），2px 容差足以判别。
      closeTo(
        pitch(h.l10n.settingsAppearanceLanguage, h.l10n.settingsEditorTitle),
        2.0,
      ),
    );
    await h.unmount();
  });

  testWidgets('features entry follows the editor entry and opens its page', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const Scaffold(body: SettingsPage()));
    await tester.pumpAndSettle();

    final entry = find.text(h.l10n.settingsFeaturesTitle);
    expect(entry, findsOneWidget);
    expect(find.text(h.l10n.settingsFeaturesSubtitle), findsOneWidget);
    expect(find.byIcon(Icons.toggle_on_outlined), findsOneWidget);
    final entryTop = tester.getTopLeft(entry).dy;
    expect(
      entryTop,
      greaterThan(tester.getTopLeft(find.text(h.l10n.settingsEditorTitle)).dy),
    );
    expect(
      entryTop,
      lessThan(tester.getTopLeft(find.text(h.l10n.settingsTagManagement)).dy),
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(AppFeaturesPage), findsOneWidget);
    await h.unmount();
  });
}
