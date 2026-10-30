part of 'app_database.dart';

/// 日记留言读写（#95 本地改造版核心）。
///
/// 输入：日记业务 id 与留言内容；输出：按时间排序的留言流与按日记计数的
/// 流。删除是硬删除——留言没有回收站，调用方（预览页留言区）在删除前弹
/// 确认框。导出、搜索、备份均不带留言（任务明确不做），这里也不提供相关
/// 查询，避免以后误接。
mixin _AppDatabaseDiaryCommentOps on _$AppDatabase {
  /// 某篇日记的全部留言：按创建时间升序、同一时刻按本地 id 升序，保证顺序
  /// 稳定；写入与删除都会经 watch 推送到预览页与卡片角标。
  Stream<List<DiaryCommentRow>> watchDiaryComments(String diaryId) {
    return (select(diaryComments)
          ..where((t) => t.diaryId.equals(diaryId))
          ..orderBy(<OrderClauseGenerator<$DiaryCommentsTable>>[
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// 某篇日记的留言数：只对这一篇做 `COUNT`（走
  /// `idx_diary_comments_diary_id`），不读留言内容、不全表扫，供卡片角标
  /// 订阅；无留言时为 0，卡片据此隐藏角标。
  Stream<int> watchDiaryCommentCount(String diaryId) {
    final count = diaryComments.id.count();
    return (selectOnly(diaryComments)
          ..where(diaryComments.diaryId.equals(diaryId))
          ..addColumns(<Expression<Object>>[count]))
        .map((row) => row.read(count)!)
        .watchSingle();
  }

  Future<int> countDiaryComments(String diaryId) async {
    final count = diaryComments.id.count();
    final row =
        await (selectOnly(diaryComments)
              ..where(diaryComments.diaryId.equals(diaryId))
              ..addColumns(<Expression<Object>>[count]))
            .getSingle();
    return row.read(count)!;
  }

  /// 写一条留言并返回它的业务 id。内容由调用方先 trim、空内容不写入；
  /// `createdAt` 只在插入时写，之后（编辑留后做）才刷新 `updatedAt`。
  Future<String> addDiaryComment({
    required String diaryId,
    required String content,
    DateTime? now,
  }) async {
    final trimmed = content.trim();
    assert(trimmed.isNotEmpty, 'comment content must not be empty');
    final timestamp = now ?? DateTime.now();
    final commentId = _newBusinessUuid();
    await into(diaryComments).insert(
      DiaryCommentsCompanion.insert(
        commentId: commentId,
        diaryId: diaryId,
        content: trimmed,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    return commentId;
  }

  /// 按业务 id 删除一条留言（只删这一篇里的这一行：`commentId` 全局唯一，
  /// 再按 `diaryId` 限定一次，避免 id 串篇时误删）。
  Future<void> deleteDiaryComment({
    required String diaryId,
    required String commentId,
  }) async {
    await (delete(diaryComments)..where(
          (t) => t.commentId.equals(commentId) & t.diaryId.equals(diaryId),
        ))
        .go();
  }

  /// 按业务 id 改一条留言的内容：内容由调用方先 trim、空内容不写入；
  /// 只刷新 `updatedAt`，`createdAt` 不动（排序仍按创建时间）。
  Future<void> updateDiaryComment({
    required String diaryId,
    required String commentId,
    required String content,
    DateTime? now,
  }) async {
    final trimmed = content.trim();
    assert(trimmed.isNotEmpty, 'comment content must not be empty');
    await (update(diaryComments)..where(
          (t) => t.commentId.equals(commentId) & t.diaryId.equals(diaryId),
        ))
        .write(
          DiaryCommentsCompanion(
            content: Value(trimmed),
            updatedAt: Value(now ?? DateTime.now()),
          ),
        );
  }

  /// 导出用：某篇日记的全部留言（按创建时间升序），一次读出，不订阅。
  Future<List<DiaryCommentRow>> getDiaryComments(String diaryId) {
    return (select(diaryComments)
          ..where((t) => t.diaryId.equals(diaryId))
          ..orderBy(<OrderClauseGenerator<$DiaryCommentsTable>>[
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// 搜索用：在留言内容里找关键字，返回含匹配留言的日记业务 id（去重）。
  /// 私密日记的留言不搜：调用方先按日记可见性过滤 id 列表。
  Future<List<String>> searchDiaryCommentDiaryIds(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const <String>[];
    final rows =
        await (selectOnly(diaryComments, distinct: true)
              ..where(diaryComments.content.contains(trimmed))
              ..addColumns(<Expression<Object>>[diaryComments.diaryId]))
            .map((row) => row.read(diaryComments.diaryId)!)
            .get();
    return rows;
  }
}
