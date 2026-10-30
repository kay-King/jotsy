import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_comment_providers.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

void main() {
  const badgeKey = ValueKey<String>('diary-comment-count-badge');

  DiaryWithTags diary() {
    final now = DateTime(2026, 10, 5, 14, 30);
    return DiaryWithTags(
      diary: Diary(
        id: 1,
        diaryId: 'diary-1',
        title: '标题',
        content: '{"ops":[{"insert":"Hello World\\n"}]}',
        contentText: 'Hello World',
        metadata: '{}',
        createdAt: now,
        updatedAt: now,
        isArchived: false,
        isPinned: false,
        isDeleted: false,
      ),
      tags: const <Tag>[],
    );
  }

  Future<void> pumpList(WidgetTester tester, int count) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diaryCommentCountProvider.overrideWith(
            (ref, diaryId) => Stream.value(count),
          ),
        ],
        child: MaterialApp(
          theme: const MaterialTheme(TextTheme()).light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                DiariesListSection(
                  diaries: <DiaryWithTags>[diary()],
                  layoutMode: DiaryLayoutMode.list,
                  selectedDiaryIds: const <String>{},
                  isSelectionMode: false,
                  maxVisibleTags: 3,
                  watchCommentCounts: true,
                  onCreate: () {},
                  onOpenEditor: (_, _) {},
                  onToggleSelection: (_, __) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('card shows the comment count badge when there are comments', (
    WidgetTester tester,
  ) async {
    await pumpList(tester, 3);
    expect(find.byKey(badgeKey), findsOneWidget);
    // 徽章里是留言数本身。
    expect(
      find.descendant(of: find.byKey(badgeKey), matching: find.text('3')),
      findsOneWidget,
    );
  });

  testWidgets('card hides the badge when there are no comments', (
    WidgetTester tester,
  ) async {
    await pumpList(tester, 0);
    expect(find.byKey(badgeKey), findsNothing);
  });
}
