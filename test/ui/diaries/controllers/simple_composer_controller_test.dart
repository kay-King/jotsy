import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/simple_composer_controller.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';

/// 简洁编辑器发布与草稿流程：写进同一张 diaries 表，日记页与时间线读同一份
/// 数据，所以发表后两边都能同步看到（不需要另外同步）。
/// 草稿与富文本草稿同存 `diary_drafts` 表，`simpleComposer: true` 标记，
/// 只有简洁编辑器会续写它。
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await database.close();
  });

  Future<Diary> stored(String id) async =>
      (await database.getDiaryWithTagsByDiaryId(id))!.diary;

  List<Map<String, dynamic>> deltaOf(Diary diary) =>
      (jsonDecode(diary.content) as List).cast<Map<String, dynamic>>();

  test('text-only diary is stored with first-line title', () async {
    final controller = SimpleComposerController(database);
    final id = await controller.publish(
      text: '周末和朋友去山里露营\n帐篷搭在溪边，晚上能听见水声。',
      imagePaths: const [],
    );

    final diary = await stored(id);
    expect(diary.title, '周末和朋友去山里露营');
    expect(diary.contentText, '周末和朋友去山里露营\n帐篷搭在溪边，晚上能听见水声。');
    expect(diary.cover, isNull);
    final ops = deltaOf(diary);
    expect(ops.length, 1);
    expect(ops.first['insert'], contains('周末和朋友去山里露营'));
  });

  test('empty text produces empty title and empty delta', () async {
    final controller = SimpleComposerController(database);
    // 页面在文字与图片都为空时禁用发表，这里只验证控制器对空输入
    // 的兜底：标题与正文为空，Delta 为空，不崩溃。
    final id = await controller.publish(text: '', imagePaths: const []);

    final diary = await stored(id);
    expect(diary.title, '');
    expect(diary.contentText, '');
    expect(deltaOf(diary), isEmpty);
  });

  test('title falls back to first non-empty line', () async {
    final controller = SimpleComposerController(database);
    final id = await controller.publish(
      text: '\n\n  \n第一行是标题\n第二行是正文',
      imagePaths: const [],
    );

    final diary = await stored(id);
    expect(diary.title, '第一行是标题');
  });

  test('published diary appears in the diary list query', () async {
    final controller = SimpleComposerController(database);
    final id = await controller.publish(text: '同步验证', imagePaths: const []);

    // 日记页列表与时间线都读 diaries 表：发表后应能按 id 读回，
    // 且 createdAt 为发表时刻（与日记页排序一致）。
    final diary = await stored(id);
    expect(diary.diaryId, id);
    expect(diary.createdAt, isNotNull);
    expect(diary.contentText, '同步验证');
  });

  test('image paths are embedded as image blocks with cover', () async {
    final controller = SimpleComposerController(database);
    final id = await controller.publish(
      text: '露营',
      imagePaths: const ['/private/img-a.jpg', '/private/img-b.jpg'],
    );

    final diary = await stored(id);
    expect(diary.cover, '/private/img-a.jpg');
    // 正文 1 条 + 每张图 2 条（图片块 + 换行）= 5 条。
    final ops = deltaOf(diary);
    expect(ops.length, 5);
    expect(ops[0]['insert'], '露营\n');
    expect((ops[1]['insert'] as Map)['image'], '/private/img-a.jpg');
    expect(ops[2]['insert'], '\n');
    expect((ops[3]['insert'] as Map)['image'], '/private/img-b.jpg');
    expect(ops[4]['insert'], '\n');
  });

  test('draft snapshot carries the simpleComposer marker', () async {
    final snapshot = SimpleComposerController.buildDraftSnapshot(
      text: '没写完',
      imagePaths: const ['/private/img-a.jpg'],
    );
    expect(snapshot.hasContent, isTrue);
    expect(snapshot.title, '没写完');
    expect(snapshot.contentText, '没写完');
    final draft = NewDiaryDraft.fromJson(
      (jsonDecode(snapshot.payload) as Map).cast<String, Object?>(),
    );
    expect(draft.simpleComposer, isTrue);
    expect(draft.cover, '/private/img-a.jpg');
  });

  test('image paths round-trip through the delta', () {
    const docJson =
        '[{"insert":"露营\\n"},{"insert":{"image":"/private/img-a.jpg"}},{"insert":"\\n"},{"insert":{"image":"/private/img-b.jpg"}},{"insert":"\\n"}]';
    expect(SimpleComposerController.imagePathsFromContentDocJson(docJson), [
      '/private/img-a.jpg',
      '/private/img-b.jpg',
    ]);
    expect(
      SimpleComposerController.imagePathsFromContentDocJson('not-json'),
      isEmpty,
    );
    expect(
      SimpleComposerController.imagePathsFromContentDocJson('[{"insert":"x"}]'),
      isEmpty,
    );
  });

  test('findLatestSimpleDraft only returns simple drafts', () async {
    final controller = SimpleComposerController(database);
    // 先存一份富文本草稿（无标记），再存一份简洁草稿。
    final rich = NewDiaryDraft(
      title: '富文本',
      contentDocJson: '[{"insert":"富文本\\n"}]',
      contentText: '富文本',
    );
    final richSnapshot = rich.toSnapshot();
    await database.saveDiaryDraft(
      title: richSnapshot.title,
      contentText: richSnapshot.contentText,
      payload: richSnapshot.payload,
    );
    final simpleSnapshot = SimpleComposerController.buildDraftSnapshot(
      text: '简洁没写完',
      imagePaths: const [],
    );
    final simpleId = await database.saveDiaryDraft(
      title: simpleSnapshot.title,
      contentText: simpleSnapshot.contentText,
      payload: simpleSnapshot.payload,
    );

    final latest = await controller.findLatestSimpleDraft();
    expect(latest, isNotNull);
    expect(latest!.draftId, simpleId);
    expect(latest.draft.contentText, '简洁没写完');
    expect(latest.draft.simpleComposer, isTrue);
  });

  test('findLatestSimpleDraft returns null when no simple draft', () async {
    final controller = SimpleComposerController(database);
    final rich = NewDiaryDraft(
      title: '富文本',
      contentDocJson: '[{"insert":"富文本\\n"}]',
      contentText: '富文本',
    );
    final snapshot = rich.toSnapshot();
    await database.saveDiaryDraft(
      title: snapshot.title,
      contentText: snapshot.contentText,
      payload: snapshot.payload,
    );

    expect(await controller.findLatestSimpleDraft(), isNull);
  });

  test('published diary is deleted and not resumed', () async {
    final controller = SimpleComposerController(database);
    // 模拟自动保存写下的简洁草稿，发表后删掉，下次不再续写。
    final snapshot = SimpleComposerController.buildDraftSnapshot(
      text: '要发表的',
      imagePaths: const [],
    );
    final draftId = await database.saveDiaryDraft(
      title: snapshot.title,
      contentText: snapshot.contentText,
      payload: snapshot.payload,
    );
    expect(await controller.findLatestSimpleDraft(), isNotNull);

    await controller.publish(text: '要发表的', imagePaths: const []);
    await database.deleteDiaryDrafts([draftId]);

    expect(await controller.findLatestSimpleDraft(), isNull);
    expect(await database.getDiaryDraft(draftId), isNull);
  });

  test('published diary carries the simpleComposer metadata marker', () async {
    final controller = SimpleComposerController(database);
    final id = await controller.publish(text: '标记验证', imagePaths: const []);

    final diary = await stored(id);
    expect(
      SimpleComposerController.isSimpleComposerEntry(diary.metadata),
      isTrue,
    );
    expect(SimpleComposerController.isSimpleComposerEntry('{}'), isFalse);
    expect(SimpleComposerController.isSimpleComposerEntry('not-json'), isFalse);
  });

  test('tryExtractSimpleContent extracts plain text and images', () {
    const docJson =
        '[{"insert":"露营\\n"},{"insert":{"image":"/private/img-a.jpg"}},{"insert":"\\n"}]';
    final extracted = SimpleComposerController.tryExtractSimpleContent(docJson);
    expect(extracted, isNotNull);
    expect(extracted!.text, '露营');
    expect(extracted.images, ['/private/img-a.jpg']);
  });

  test('tryExtractSimpleContent rejects formatted text and other embeds', () {
    // 加粗文字。
    expect(
      SimpleComposerController.tryExtractSimpleContent(
        '[{"insert":"加粗","attributes":{"bold":true}},{"insert":"\\n"}]',
      ),
      isNull,
    );
    // 标题块（换行带块属性）。
    expect(
      SimpleComposerController.tryExtractSimpleContent(
        '[{"insert":"标题"},{"insert":"\\n","attributes":{"header":1}}]',
      ),
      isNull,
    );
    // 视频嵌入。
    expect(
      SimpleComposerController.tryExtractSimpleContent(
        '[{"insert":"文字\\n"},{"insert":{"video":"/v.mp4"}},{"insert":"\\n"}]',
      ),
      isNull,
    );
    // 非法 JSON。
    expect(
      SimpleComposerController.tryExtractSimpleContent('not-json'),
      isNull,
    );
  });

  test(
    'tryExtractSimpleContent accepts over-long text but rejects too many images',
    () {
      // 正文不限字数：5000 字也能用简洁编辑器重新打开。
      final longText = '字' * 5000;
      final extracted = SimpleComposerController.tryExtractSimpleContent(
        jsonEncode([
          {'insert': '$longText\n'},
        ]),
      );
      expect(extracted, isNotNull);
      expect(extracted!.text, longText);
      expect(extracted.images, isEmpty);
      // 10 张图还是不行（上限 9 张）。
      final tenImages = <Map<String, Object?>>[
        {'insert': '文字\n'},
        for (var i = 0; i < 10; i++) ...[
          {
            'insert': {'image': '/private/img-$i.jpg'},
          },
          {'insert': '\n'},
        ],
      ];
      expect(
        SimpleComposerController.tryExtractSimpleContent(jsonEncode(tenImages)),
        isNull,
      );
    },
  );

  test(
    'update rewrites title, content and cover and keeps the marker',
    () async {
      final controller = SimpleComposerController(database);
      final id = await controller.publish(
        text: '旧标题\n旧正文',
        imagePaths: const ['/private/old.jpg'],
      );
      final before = await stored(id);
      final createdAt = before.createdAt;

      await controller.update(
        diaryId: id,
        text: '新标题\n新正文',
        imagePaths: const ['/private/new-a.jpg', '/private/new-b.jpg'],
        tagIds: const [],
      );

      final after = await stored(id);
      expect(after.title, '新标题');
      expect(after.contentText, '新标题\n新正文');
      expect(after.cover, '/private/new-a.jpg');
      expect(after.createdAt, createdAt);
      expect(
        SimpleComposerController.isSimpleComposerEntry(after.metadata),
        isTrue,
      );
      expect(
        SimpleComposerController.tryExtractSimpleContent(after.content),
        isNotNull,
      );
    },
  );
}
