import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// 某篇日记的留言列表（按时间升序）：预览页留言区订阅；写入与删除经
/// 数据库 watch 实时推送，不读整库。
final diaryCommentsProvider = StreamProvider.family
    .autoDispose<List<DiaryCommentRow>, String>((Ref ref, String diaryId) {
      final database = ref.watch(appDatabaseProvider);
      return database.watchDiaryComments(diaryId);
    });

/// 某篇日记的留言数：卡片角标只订阅计数，不读留言内容；无留言时为 0，
/// 卡片据此隐藏角标。
final diaryCommentCountProvider = StreamProvider.family
    .autoDispose<int, String>((Ref ref, String diaryId) {
      final database = ref.watch(appDatabaseProvider);
      return database.watchDiaryCommentCount(diaryId);
    });

/// 留言内容搜索：返回含匹配留言的日记业务 id 列表（去重，不排序）。
/// 调用方与日记关键词搜索结果合并去重。
final searchDiaryIdsByCommentProvider = FutureProvider.family
    .autoDispose<List<String>, String>((Ref ref, String keyword) async {
      final trimmed = keyword.trim();
      if (trimmed.isEmpty) {
        return const <String>[];
      }
      final database = ref.watch(appDatabaseProvider);
      return database.searchDiaryCommentDiaryIds(trimmed);
    });

/// 搜留言开关用的留言匹配日记列表：按关键词查留言，逐条取日记 + 标签，
/// 排除软删除，按更新时间倒序。调用方自行与关键词搜索结果去重（避免
/// 同一篇在两个分组重复出现）。
final commentMatchedDiariesProvider = FutureProvider.family
    .autoDispose<List<DiaryWithTags>, String>((Ref ref, String keyword) async {
      final trimmed = keyword.trim();
      if (trimmed.isEmpty) {
        return const <DiaryWithTags>[];
      }
      final database = ref.watch(appDatabaseProvider);
      final ids = await database.searchDiaryCommentDiaryIds(trimmed);
      final diaries = <DiaryWithTags>[];
      for (final id in ids) {
        final diary = await database.getDiaryWithTagsByDiaryId(id);
        if (diary != null && !diary.diary.isDeleted) {
          diaries.add(diary);
        }
      }
      diaries.sort((a, b) => b.diary.updatedAt.compareTo(a.diary.updatedAt));
      return diaries;
    });
