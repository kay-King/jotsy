import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_preview/diary_preview_comments.dart';

void main() {
  late AppDatabase db;
  late String diaryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    diaryId = await db.createDiary(
      title: '一篇日记',
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
    );
  });
  tearDown(() => db.close());

  /// 收尾：先把 ProviderScope 卸载（drift 的 watch 订阅取消时会起一个
  /// 零延时的内部 Timer），再推进一次 fake 时钟让它触发，否则框架在
  /// post-test 校验里会报 "A Timer is still pending"（归档页测试同款写法）。
  Future<void> unmountSection(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: const MaterialTheme(TextTheme()).light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiaryPreviewCommentsSection(diaryId: diaryId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('comments section shows empty state, then a written comment',
      (WidgetTester tester) async {
    await pumpSection(tester);
    expect(find.text('还没有留言，写下第一条吧。'), findsOneWidget);
    expect(find.text('留言'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('diary-comment-input')),
      '写给自己的话',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('diary-comment-send')));
    await tester.pumpAndSettle();

    expect(find.text('写给自己的话'), findsOneWidget);
    expect(find.text('还没有留言，写下第一条吧。'), findsNothing);
    // 留言数角标经计数流实时更新：有一条留言即显示 "1"。
    // 注意：不要在这里直接 await 数据库的 select 查询——在 testWidgets 的
    // FakeAsync 环境里它不会完成（见本次任务排查记录）；读数断言走 UI。
    expect(find.text('1'), findsOneWidget);
    await unmountSection(tester);
  });

  testWidgets('blank input does not send', (WidgetTester tester) async {
    await pumpSection(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('diary-comment-input')),
      '   ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('diary-comment-send')));
    await tester.pumpAndSettle();
    // 空内容不会写入：仍显示空态。
    expect(find.text('还没有留言，写下第一条吧。'), findsOneWidget);
    await unmountSection(tester);
  });

  testWidgets('deleting a comment asks for confirmation, then removes it',
      (WidgetTester tester) async {
    await db.addDiaryComment(diaryId: diaryId, content: '要删掉的一条');
    await pumpSection(tester);
    expect(find.text('要删掉的一条'), findsOneWidget);

    await tester.tap(find.byIcon(FontAwesomeIcons.ellipsis.data));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除这条留言'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条留言'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('要删掉的一条'), findsNothing);
    expect(find.text('还没有留言，写下第一条吧。'), findsOneWidget);
    await unmountSection(tester);
  });

  testWidgets('editing a comment updates its content', (
    WidgetTester tester,
  ) async {
    await db.addDiaryComment(diaryId: diaryId, content: '原来的内容');
    await pumpSection(tester);
    expect(find.text('原来的内容'), findsOneWidget);

    await tester.tap(find.byIcon(FontAwesomeIcons.ellipsis.data));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑留言'));
    await tester.pumpAndSettle();
    expect(find.text('编辑留言'), findsOneWidget);

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, '改后的内容');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('改后的内容'), findsOneWidget);
    expect(find.text('原来的内容'), findsNothing);
    await unmountSection(tester);
  });
}
