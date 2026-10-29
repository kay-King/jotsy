import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> diary() {
    return db.createDiary(
      title: '有留言的日记',
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
    );
  }

  test('adding comments lists them oldest first with content and time',
      () async {
    final diaryId = await diary();
    final first = await db.addDiaryComment(
      diaryId: diaryId,
      content: '  第一条  ',
      now: DateTime(2026, 10, 29, 9),
    );
    await db.addDiaryComment(
      diaryId: diaryId,
      content: '第二条',
      now: DateTime(2026, 10, 29, 10),
    );
    // 另一篇日记的留言不串篇。
    final otherDiaryId = await db.createDiary(
      title: '另一篇',
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
    );
    await db.addDiaryComment(
      diaryId: otherDiaryId,
      content: '别篇的',
      now: DateTime(2026, 10, 29, 8),
    );

    final rows = await db.watchDiaryComments(diaryId).first;
    expect(rows.map((row) => row.content), ['第一条', '第二条']);
    expect(rows.first.commentId, first);
    expect(rows.first.createdAt, DateTime(2026, 10, 29, 9));
    expect(rows.first.updatedAt, DateTime(2026, 10, 29, 9));
    expect(rows.first.diaryId, diaryId);
  });

  test('comment count only counts this diary and updates on delete',
      () async {
    final diaryId = await diary();
    expect(await db.countDiaryComments(diaryId), 0);
    expect(await db.watchDiaryCommentCount(diaryId).first, 0);
    final commentId = await db.addDiaryComment(
      diaryId: diaryId,
      content: '一条',
    );
    expect(await db.countDiaryComments(diaryId), 1);
    expect(await db.watchDiaryCommentCount(diaryId).first, 1);

    await db.deleteDiaryComment(diaryId: diaryId, commentId: commentId);
    expect(await db.countDiaryComments(diaryId), 0);
    expect(await db.watchDiaryComments(diaryId).first, isEmpty);
  });

  test('deleting with a mismatched diary id does not delete', () async {
    final diaryId = await diary();
    final commentId = await db.addDiaryComment(
      diaryId: diaryId,
      content: '一条',
    );
    await db.deleteDiaryComment(diaryId: 'not-this-diary', commentId: commentId);
    expect(await db.countDiaryComments(diaryId), 1);
  });

  group('schema v14 migration', () {
    Future<File> v13DatabaseFile({required bool keepCommentsTable}) async {
      final root = await Directory.systemTemp.createTemp('jotsy_v14_comments');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v13.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      String? keptCommentId;
      try {
        final diaryId = await original.createDiary(
          title: '升级前的日记',
          contentDocJson: '[{"insert":"正文\\n"}]',
          contentText: '正文',
          metadataJson: '{}',
        );
        if (keepCommentsTable) {
          keptCommentId = await original.addDiaryComment(
            diaryId: diaryId,
            content: '降级时留下的留言',
          );
        }
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      if (!keepCommentsTable) legacy.execute('DROP TABLE diary_comments');
      legacy.execute('PRAGMA user_version = 13');
      legacy.close();
      // 降级留下的留言 id 由调用方经文件外的变量带回：这里用内容反查。
      expect(keptCommentId != null, keepCommentsTable);
      return file;
    }

    test('v13 upgrade creates the comments table and keeps diaries',
        () async {
      final file = await v13DatabaseFile(keepCommentsTable: false);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        // #84 把 schema 升到 v15，migrated.schemaVersion 取的是代码里的最新版。
        expect(migrated.schemaVersion, 15);
        final diaries = await migrated.select(migrated.diaries).get();
        expect(diaries.single.title, '升级前的日记');
        expect(await migrated.countDiaryComments(diaries.single.diaryId), 0);
        await migrated.addDiaryComment(
          diaryId: diaries.single.diaryId,
          content: '升级后新写的',
        );
        expect(await migrated.countDiaryComments(diaries.single.diaryId), 1);
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        // #84 把 schema 升到 v15，v13 库迁移后停在最新版 v15。
        expect(version.read<int>('user_version'), 15);
      } finally {
        await migrated.close();
      }
    });

    test('upgrading over a comments table a downgrade left keeps its rows',
        () async {
      final file = await v13DatabaseFile(keepCommentsTable: true);
      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final diaries = await migrated.select(migrated.diaries).get();
        final rows = await migrated
            .watchDiaryComments(diaries.single.diaryId)
            .first;
        expect(rows.single.content, '降级时留下的留言');
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        // #84 把 schema 升到 v15，v13 库迁移后停在最新版 v15（v14 留言表仍在）。
        expect(version.read<int>('user_version'), 15);
      } finally {
        await migrated.close();
      }
    });
  });
}
