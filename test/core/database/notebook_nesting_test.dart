import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/notebooks/models/notebook_tree.dart';
import 'package:sqlite3/sqlite3.dart';

/// #84 日记本嵌套：parent_id 列、树操作、防环、删除/合并时的子本处理。
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('NotebookTree', () {
    test('children / descendants / ancestors', () {
      final tree = NotebookTree(const <NotebookNode>[
        NotebookNode('a', null),
        NotebookNode('b', 'a'),
        NotebookNode('c', 'a'),
        NotebookNode('d', 'b'),
      ]);
      expect(tree.childrenOf('a'), <String>['b', 'c']);
      expect(tree.childrenOf('b'), <String>['d']);
      expect(tree.childrenOf('d'), isEmpty);
      expect(tree.descendantsOf('a'), <String>{'b', 'c', 'd'});
      expect(tree.descendantsOf('b'), <String>{'d'});
      expect(tree.ancestorsOf('d'), <String>['b', 'a']);
      expect(tree.ancestorsOf('a'), isEmpty);
      expect(tree.isTopLevel('a'), isTrue);
      expect(tree.isTopLevel('b'), isFalse);
    });

    test('wouldCycle', () {
      final tree = NotebookTree(const <NotebookNode>[
        NotebookNode('a', null),
        NotebookNode('b', 'a'),
        NotebookNode('c', 'b'),
      ]);
      // 指自己、指后代都成环；指祖先、指无关本子、移到顶级不成环。
      expect(tree.wouldCycle('a', 'a'), isTrue);
      expect(tree.wouldCycle('a', 'b'), isTrue);
      expect(tree.wouldCycle('a', 'c'), isTrue);
      expect(tree.wouldCycle('b', 'a'), isFalse);
      expect(tree.wouldCycle('c', 'a'), isFalse);
      expect(tree.wouldCycle('b', null), isFalse);
    });
  });

  group('parent_id 读写', () {
    test('createNotebook 可指定父本', () async {
      final parent = await db.createNotebook(name: '父本');
      final child = await db.createNotebook(name: '子本', parentId: parent);
      final row = await db.getNotebook(child);
      expect(row?.parentId, parent);
    });

    test('createNotebook 父本不存在时抛错', () async {
      expect(
        () => db.createNotebook(name: '子本', parentId: 'not-exist'),
        throwsArgumentError,
      );
    });

    test('updateNotebook 改父本与移到顶级', () async {
      final p1 = await db.createNotebook(name: '父本1');
      final p2 = await db.createNotebook(name: '父本2');
      final child = await db.createNotebook(name: '子本', parentId: p1);
      expect((await db.getNotebook(child))?.parentId, p1);

      await db.updateNotebook(child, parentId: Value(p2));
      expect((await db.getNotebook(child))?.parentId, p2);

      await db.updateNotebook(child, parentId: const Value(null));
      expect((await db.getNotebook(child))?.parentId, isNull);
    });

    test('updateNotebook 指向自己抛错', () async {
      final id = await db.createNotebook(name: '本子');
      expect(
        () => db.updateNotebook(id, parentId: Value(id)),
        throwsArgumentError,
      );
    });

    test('updateNotebook 指后代时抛错（防环）', () async {
      final a = await db.createNotebook(name: 'A');
      final b = await db.createNotebook(name: 'B', parentId: a);
      expect(
        () => db.updateNotebook(a, parentId: Value(b)),
        throwsArgumentError,
      );
    });

    test('deleteNotebook 时子本变为顶级', () async {
      final parent = await db.createNotebook(name: '父本');
      final child = await db.createNotebook(name: '子本', parentId: parent);
      await db.deleteNotebook(parent);
      final row = await db.getNotebook(child);
      expect(row?.parentId, isNull);
    });

    test('mergeNotebook 时子本上移一级', () async {
      final grandparent = await db.createNotebook(name: '祖父');
      final source = await db.createNotebook(
        name: '源本',
        parentId: grandparent,
      );
      final target = await db.createNotebook(name: '目标');
      final child = await db.createNotebook(name: '子本', parentId: source);
      await db.mergeNotebook(sourceId: source, targetId: target);
      final row = await db.getNotebook(child);
      // 源本的父本是祖父，子本上移到祖父下。
      expect(row?.parentId, grandparent);
    });
  });

  group('schema v15 migration', () {
    test('v14 升级加 parent_id 列，老数据全为 null', () async {
      final root = await Directory.systemTemp.createTemp('jotsy_v15_nb');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/v14.sqlite');
      final original = AppDatabase.forTesting(NativeDatabase(file));
      String bookId;
      try {
        bookId = await original.createNotebook(name: '升级前的本子');
      } finally {
        await original.close();
      }
      final legacy = sqlite3.open(file.path);
      legacy.execute('PRAGMA user_version = 14');
      legacy.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final book = await migrated.getNotebook(bookId);
        expect(book, isNotNull);
        expect(book!.parentId, isNull);
        // 升级后可正常嵌套。
        final child = await migrated.createNotebook(
          name: '升级后子本',
          parentId: bookId,
        );
        expect((await migrated.getNotebook(child))?.parentId, bookId);
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 15);
      } finally {
        await migrated.close();
      }
    });
  });

  group('范围查询', () {
    Future<String> diary(String title, {List<String>? notebookIds}) {
      return db.createDiary(
        title: title,
        contentDocJson: '[{"insert":"$title body\\n"}]',
        contentText: '$title body',
        metadataJson: '{}',
        notebookIds: notebookIds,
      );
    }

    test('父本范围含子本日记', () async {
      final parent = await db.createNotebook(name: '父本');
      final child = await db.createNotebook(name: '子本', parentId: parent);
      final other = await db.createNotebook(name: '别的本');
      await diary('父本日记', notebookIds: <String>[parent]);
      await diary('子本日记', notebookIds: <String>[child]);
      await diary('别的本日记', notebookIds: <String>[other]);
      await diary('没进本日记');

      final scope = DiaryNotebookScope(
        notebookId: parent,
        descendantIds: <String>[child, parent]..sort(),
      );
      final rows = await db.watchDiaries(scope: scope).first;
      final titles = <String>{for (final r in rows) r.diary.title};
      expect(titles, <String>{'父本日记', '子本日记'});
    });

    test('未收录范围只含没进本的日记', () async {
      final book = await db.createNotebook(name: '本子');
      await diary('进本日记', notebookIds: <String>[book]);
      await diary('没进本日记1');
      await diary('没进本日记2');

      final rows = await db
          .watchDiaries(scope: const DiaryUnfiledScope())
          .first;
      final titles = <String>{for (final r in rows) r.diary.title};
      expect(titles, <String>{'没进本日记1', '没进本日记2'});
    });

    test('未收录计数', () async {
      final book = await db.createNotebook(name: '本子');
      await diary('进本日记', notebookIds: <String>[book]);
      await diary('没进本日记');
      expect(await db.watchUnfiledDiaryCount().first, 1);
    });
  });
}
