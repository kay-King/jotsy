import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_features.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';
import 'package:node_diary/ui/settings/pages/app_features_page.dart';
import 'package:node_diary/ui/settings/widgets/settings_option_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:node_diary/core/services/settings_service.dart';

import '../../support/diary_drafts_harness.dart';
import '../../support/expressive_test_theme.dart';
import '../notebooks/notebook_test_support.dart';
import 'package:node_diary/ui/widgets/salt_switch.dart';

/// 功能管理页：每个开关立即写入设置；纪念日在日历下方、随日历显隐；关闭日记本时若有
/// 隐藏 / 上锁的本子先确认。
void main() {
  Finder switchTile(String title) =>
      find.widgetWithText(SettingsSwitchTile, title);

  SaltSwitch tile(WidgetTester tester, String title) =>
      tester.widget<SaltSwitch>(
        find.descendant(
          of: switchTile(title),
          matching: find.byType(SaltSwitch),
        ),
      );

  AppFeatures stored(DiaryDraftsHarness h) =>
      AppFeatures.decode(h.settings.appFeaturesRaw);

  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.ensureVisible(switchTile(title));
    await tester.tap(switchTile(title));
    await tester.pumpAndSettle();
  }

  testWidgets('each switch writes its feature immediately', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;

    await toggle(tester, l10n.navDesktop);
    expect(stored(h).desktop, isFalse);
    await toggle(tester, l10n.navDesktop);
    expect(stored(h), AppFeatures.defaults);
    expect(h.settings.appFeaturesRaw, isNull);

    await toggle(tester, l10n.settingsFeaturesAnniversaries);
    expect(stored(h).anniversaries, isFalse);
    await toggle(tester, l10n.settingsFeaturesTemplates);
    expect(stored(h).templates, isFalse);
    await toggle(tester, l10n.settingsFeaturesTimeCapsules);
    expect(stored(h).timeCapsules, isFalse);
    await toggle(tester, l10n.settingsFeaturesSwipeArchive);
    expect(stored(h).swipeArchive, isFalse);
    await toggle(tester, l10n.notebookTitle);
    await h.settle();
    expect(stored(h).notebooks, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tile(tester, l10n.notebookTitle).value, isFalse);

    // 打开日记本从不询问。
    await toggle(tester, l10n.notebookTitle);
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored(h).notebooks, isTrue);
    await h.unmount();
  });

  testWidgets('anniversaries sit right below the desktop toggle and write '
      'their own value', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;

    // 「页面」组顺序：桌面、纪念日；「功能」组在其后。
    final desktopY = tester.getTopLeft(switchTile(l10n.navDesktop)).dy;
    final anniversaryY = tester
        .getTopLeft(switchTile(l10n.settingsFeaturesAnniversaries))
        .dy;
    final notebooksY = tester.getTopLeft(switchTile(l10n.notebookTitle)).dy;
    expect(desktopY, lessThan(anniversaryY));
    expect(anniversaryY, lessThan(notebooksY));

    // 与桌面平齐（用户 2026-10-24：从属缩进在卡里读起来像没对齐）。
    final desktopTitleX = tester.getTopLeft(find.text(l10n.navDesktop)).dx;
    final anniversaryTitleX = tester
        .getTopLeft(find.text(l10n.settingsFeaturesAnniversaries))
        .dx;
    expect(anniversaryTitleX, desktopTitleX);

    final anniversaries = tile(tester, l10n.settingsFeaturesAnniversaries);
    expect(anniversaries.value, isTrue);
    expect(anniversaries.onChanged, isNotNull);
    expect(find.text(l10n.settingsFeaturesAnniversariesSubtitle), findsOne);

    await toggle(tester, l10n.settingsFeaturesAnniversaries);
    expect(stored(h).anniversaries, isFalse);
    await h.unmount();
  });

  testWidgets('turning notebooks off with a private notebook asks first', (
    tester,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.notebook('日常');
    await h.notebook('秘密', visibility: NotebookVisibility.locked);
    await h.notebook('收起', visibility: NotebookVisibility.hidden);
    await h.pump(const AppFeaturesPage());
    final l10n = h.l10n;

    await toggle(tester, l10n.notebookTitle);
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsFeaturesNotebooksOffTitle), findsOne);
    expect(find.text(l10n.settingsFeaturesNotebooksOffMessage(2)), findsOne);

    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored(h).notebooks, isTrue);
    expect(tile(tester, l10n.notebookTitle).value, isTrue);

    await toggle(tester, l10n.notebookTitle);
    await h.settle();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsFeaturesNotebooksOffConfirm));
    await tester.pumpAndSettle();
    await h.settle();
    expect(stored(h).notebooks, isFalse);
    expect(tile(tester, l10n.notebookTitle).value, isFalse);
    await h.unmount();
  });

  testWidgets('only normal notebooks turn off without asking', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.notebook('日常');
    await h.pump(const AppFeaturesPage());

    await toggle(tester, h.l10n.notebookTitle);
    await h.settle();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(stored(h).notebooks, isFalse);
    await h.unmount();
  });

  for (final locale in const <Locale>[Locale('zh'), Locale('en')]) {
    testWidgets('renders without overflow at 320dp in ${locale.languageCode}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await SettingsService.create();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWith((ref) async => settings),
            notebooksProvider.overrideWith(
              (ref) => Stream.value(const <NotebookView>[]),
            ),
          ],
          child: MaterialApp(
            theme: expressiveTestTheme(Brightness.light),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppFeaturesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 功能管理里 6 个开关（桌面/日记本/纪念日/模板/时间胶囊/侧滑归档；
      // 探索与日历已并进首页，不再有开关）。
      expect(find.byType(SettingsSwitchTile), findsNWidgets(6));
    });
  }

  testWidgets('desktop has no swipe-to-archive switch', (tester) async {
    final h = await DiaryDraftsHarness.create(tester);
    await h.pump(const AppFeaturesPage());

    expect(switchTile(h.l10n.settingsFeaturesTimeCapsules), findsOneWidget);
    expect(switchTile(h.l10n.settingsFeaturesSwipeArchive), findsNothing);
    await h.unmount();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
