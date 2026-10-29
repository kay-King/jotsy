part of 'app_database.dart';

/// 日记留言：只挂在日记业务 id 上的一行行短评（#95 本地改造版核心）。
///
/// 设计要点：
/// 1. 不改 `diaries` 表：留言是独立表，日记的查询、列表、导出、备份都不用
///    跟着改条件；删日记时留言由调用方在同一事务里清理（本库从不开启
///    外键，与日记本关联表同理）；
/// 2. `diaryId` 存日记业务 id（`Diaries.diaryId`），不存本地自增 id：备份
///    恢复与合并后本地 id 会变，业务 id 不变（与纪念日 `linkedDiaryId`
///    同理）；
/// 3. `commentId` 是业务唯一标识（UUID v4，[AppDatabase.newBusinessId]），
///    删除按它定位；`id` 只用于本地排序稳定；
/// 4. 只有作者本人的留言：本应用是单人日记，没有多用户与他人的留言，
///    “删除自己的留言”就是按 `commentId` 删除，不另设作者列；
/// 5. `idx_diary_comments_diary_id` 覆盖“某篇日记的留言列表与计数”：列表
///    按 `created_at, id` 排序、计数只走索引过滤，不全表扫。
@DataClassName('DiaryCommentRow')
@TableIndex(name: 'idx_diary_comments_diary_id', columns: <Symbol>{#diaryId})
class DiaryComments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get commentId => text().named('comment_id').unique()();

  TextColumn get diaryId => text().named('diary_id')();

  TextColumn get content => text().withLength(min: 1, max: 2000)();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
}
