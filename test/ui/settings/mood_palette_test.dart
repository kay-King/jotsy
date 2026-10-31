import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/backup_settings.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/models/mood_palette.dart';
import 'package:node_diary/ui/settings/pages/mood_options_page.dart';
import 'package:node_diary/ui/widgets/color_swatch_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoodPalette codec', () {
    test('decodes to defaults on null, empty or corrupt input', () {
      expect(MoodPalette.decode(null), MoodPalette.defaults);
      expect(MoodPalette.decode(''), MoodPalette.defaults);
      expect(MoodPalette.decode('not json'), MoodPalette.defaults);
      expect(MoodPalette.decode('[]'), MoodPalette.defaults);
      expect(MoodPalette.decode('{"v":1}'), MoodPalette.defaults);
    });

    test('tolerates bad fields one by one', () {
      final decoded = MoodPalette.decode(
        '{"v":1,'
        '"symbols":["😡","","😶"],'
        '"colors":["#FF0000","bad",null,123456789012345,-1,"#GGGGGG",4278190335,"#12345",4294967296]}',
      );
      // 符号：坏位逐个回退默认，缺位按默认补齐。
      expect(decoded.symbols[0], '😡');
      expect(decoded.symbols[1], MoodPalette.defaultSymbols[1]);
      expect(decoded.symbols[2], '😶');
      expect(decoded.symbols[9], MoodPalette.defaultSymbols[9]);
      // 颜色：坏值逐个回退默认（4278190335 = 0xFF0000FF 合法）。
      expect(decoded.colors[0], 0xFFFF0000);
      expect(decoded.colors[1], MoodPalette.defaultColors[1]);
      expect(decoded.colors[2], MoodPalette.defaultColors[2]);
      expect(decoded.colors[3], MoodPalette.defaultColors[3]);
      expect(decoded.colors[4], MoodPalette.defaultColors[4]);
      expect(decoded.colors[5], MoodPalette.defaultColors[5]);
      expect(decoded.colors[6], 0xFF0000FF);
      expect(decoded.colors[7], MoodPalette.defaultColors[7]);
      expect(decoded.colors[8], MoodPalette.defaultColors[8]);
      expect(decoded.colors[9], MoodPalette.defaultColors[9]);
    });

    test('encodes null when default and round-trips custom values', () {
      expect(MoodPalette.defaults.encode(), isNull);

      final custom = MoodPalette.defaults
          .withColor(0, const Color(0xFFFF0000))
          .withSymbol(9, '🥳');
      final decoded = MoodPalette.decode(custom.encode());
      expect(decoded, custom);
      expect(decoded.colors[0], 0xFFFF0000);
      expect(decoded.symbols[9], '🥳');
    });

    test('withSymbol falls back to the default symbol on empty input', () {
      final updated = MoodPalette.defaults.withSymbol(0, '   ');
      expect(updated.symbols[0], MoodPalette.defaultSymbols[0]);
    });

    test('colorForSymbol finds slot colors and misses unknown symbols', () {
      const palette = MoodPalette.defaults;
      expect(palette.colorForSymbol('😭'), const Color(0xFF5C6BC0));
      expect(palette.colorForSymbol('🤩'), const Color(0xFFEC407A));
      expect(palette.colorForSymbol(' 😭 '), const Color(0xFF5C6BC0));
      expect(palette.colorForSymbol('unknown'), isNull);
      expect(palette.colorForSymbol(''), isNull);
      expect(palette.colorForSymbol(null), isNull);
    });

    test('colorForWeight clamps to the ten slots', () {
      expect(
        MoodPalette.defaults.colorForWeight(1),
        const Color(0xFF5C6BC0),
      );
      expect(
        MoodPalette.defaults.colorForWeight(10),
        const Color(0xFFEC407A),
      );
      expect(
        MoodPalette.defaults.colorForWeight(0),
        const Color(0xFF5C6BC0),
      );
      expect(
        MoodPalette.defaults.colorForWeight(99),
        const Color(0xFFEC407A),
      );
    });
  });

  group('SettingsService mood palette', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists the palette and clears the key when default', () async {
      final settings = await SettingsService.create();
      expect(settings.moodPalette, MoodPalette.defaults);
      expect(settings.moodPaletteRaw, isNull);

      final custom = MoodPalette.defaults.withColor(
        0,
        const Color(0xFFFF0000),
      );
      await settings.setMoodPalette(custom);
      expect(settings.moodPalette, custom);
      expect(settings.moodPaletteRaw, isNotNull);
      // 符号读取与色板保持一致。
      expect(settings.moodOptions, custom.symbols);

      await settings.resetMoodPalette();
      expect(settings.moodPalette, MoodPalette.defaults);
      expect(settings.moodPaletteRaw, isNull);
    });

    test('migrates symbols from the legacy key once', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.settings.mood_options':
            '["😡","😣","🙁","😕","😐","🙂","😌","😁","🥳","✨"]',
      });
      final settings = await SettingsService.create();
      expect(settings.moodPalette.symbols.first, '😡');
      expect(settings.moodPalette.symbols.last, '✨');
      expect(settings.moodPalette.colors, MoodPalette.defaultColors);
      expect(settings.moodOptions.first, '😡');

      await settings.setMoodPalette(
        settings.moodPalette.withColor(0, const Color(0xFF00FF00)),
      );
      final fresh = await SettingsService.create();
      expect(fresh.moodPalette.symbols.first, '😡');
      expect(fresh.moodPalette.colors.first, 0xFF00FF00);
    });

    test('backups carry the palette and restore applies it', () async {
      final settings = await SettingsService.create();
      final custom = MoodPalette.defaults
          .withColor(0, const Color(0xFFFF0000))
          .withSymbol(9, '🥳');
      await settings.setMoodPalette(custom);

      final captured = BackupSettings.capture(settings);
      expect(captured['moodPaletteRaw'], isNotNull);

      await settings.resetMoodPalette();
      await BackupSettings.restore(settings, <String, dynamic>{
        'moodPaletteRaw': captured['moodPaletteRaw'],
      });
      expect(settings.moodPalette, custom);

      // 没有该键的旧备份不碰本机色板。
      await BackupSettings.restore(settings, <String, dynamic>{
        'themeMode': 'dark',
      });
      expect(settings.moodPalette, custom);

      // 显式 null 恢复默认。
      await BackupSettings.restore(settings, <String, dynamic>{
        'moodPaletteRaw': null,
      });
      expect(settings.moodPalette, MoodPalette.defaults);
    });
  });

  group('MoodOptionsPage', () {
    Future<({AppLocalizations l10n})> pumpPage(
      WidgetTester tester,
      SettingsService settings,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MoodOptionsPage(settingsService: settings),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MoodOptionsPage)),
      );
      return (l10n: l10n,);
    }

    testWidgets('picks a color from the sheet and saves it', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await SettingsService.create();
      final (:l10n) = await pumpPage(tester, settings);

      // 10 行，每行一个颜色块。
      expect(find.byType(ColorSwatchButton), findsNWidgets(10));

      // 点开第 2 个心情的颜色块，选推荐色里的第一个（靛紫）。
      await tester.tap(find.byType(ColorSwatchButton).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('#5C6BC0'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.commonSave));
      await tester.pumpAndSettle();

      expect(settings.moodPalette.colors[1], 0xFF5C6BC0);
    });

    testWidgets('reset restores both symbols and colors', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = await SettingsService.create();
      await settings.setMoodPalette(
        MoodPalette.defaults
            .withColor(0, const Color(0xFFFF0000))
            .withSymbol(0, '😡'),
      );
      final (:l10n) = await pumpPage(tester, settings);

      expect(find.text('😡'), findsOneWidget);

      await tester.tap(find.text(l10n.commonReset));
      await tester.pump();
      await tester.tap(find.text(l10n.commonSave));
      await tester.pumpAndSettle();

      expect(settings.moodPalette, MoodPalette.defaults);
    });
  });
}
