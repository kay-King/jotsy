import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/models/changelog_entries.dart';
import 'package:node_diary/ui/settings/pages/changelog_page.dart';

void main() {
  group('changelog entries', () {
    test('are ordered newest to oldest with complete bilingual content', () {
      final versions = changelogEntries.map((entry) => entry.version).toList();
      expect(versions, <String>['v0.10.0', 'v0.9.0', 'v0.8.1', 'v0.8.0']);

      for (final entry in changelogEntries) {
        expect(entry.highlightsZh, isNotEmpty);
        expect(entry.highlightsEn, isNotEmpty);
        expect(entry.detailsZh.trim(), isNotEmpty);
        expect(entry.detailsEn.trim(), isNotEmpty);
        expect(
          entry.highlightsFor('zh'),
          entry.highlightsZh,
          reason: '${entry.version} zh highlights',
        );
        expect(
          entry.highlightsFor('en'),
          entry.highlightsEn,
          reason: '${entry.version} en highlights',
        );
        expect(entry.detailsFor('zh'), entry.detailsZh);
        expect(entry.detailsFor('en'), entry.detailsEn);
      }
    });

    test('v0.10.0 covers the mood palette and the changelog itself', () {
      final entry = changelogEntries.first;
      expect(entry.version, 'v0.10.0');
      expect(
        entry.highlightsZh.any((highlight) => highlight.contains('心情色板')),
        isTrue,
      );
      expect(entry.detailsZh, contains('着色强度'));
      expect(entry.detailsZh, contains('纸张随基调染色'));
      expect(entry.detailsEn, contains('Mood palette'));
    });
  });

  group('ChangelogPage', () {
    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChangelogPage(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders version cards with highlights', (
      WidgetTester tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('v0.10.0'), findsOneWidget);
      expect(find.text('v0.9.0'), findsOneWidget);
      expect(find.text('v0.8.1'), findsOneWidget);
      // 版本要点直接可见，完整内容默认收起。
      expect(find.textContaining('心情色板'), findsWidgets);
      expect(
        find.textContaining('十种心情各有自己的颜色，从靛紫'),
        findsNothing,
      );
      // 末尾的卡片在首屏之外，滚到可见再断言。
      await tester.scrollUntilVisible(find.text('v0.8.0'), 300);
      expect(find.text('v0.8.0'), findsOneWidget);
    });

    testWidgets('expand-all reveals the full notes of a card', (
      WidgetTester tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('展开全部').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('十种心情各有自己的颜色，从靛紫'),
        findsOneWidget,
      );

      // 展开后按钮被顶到首屏之外，先滚回来再点收起。
      await tester.ensureVisible(find.text('收起').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('收起').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('十种心情各有自己的颜色，从靛紫'),
        findsNothing,
      );
    });
  });
}
