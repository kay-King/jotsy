import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../controllers/explore_content_extractor.dart';

/// 探索页轻量日记流：
/// - 读取全部未删除日记（含归档）的概览字段；
/// - 不携带富文本 Delta 正文，避免切入探索页时做全量大字段传输；
/// - 与日记列表页筛选条件解耦，保证探索统计口径稳定。
final exploreDiariesProvider = StreamProvider<List<ExploreDiaryOverview>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchExploreDiaryOverviews();
});

/// 探索页配图统计：日记业务 id → 去重后的图片数。
///
/// 一次性读全量（与概览流同一口径：未删除、已解封、排除私密日记，含归
/// 档）；监听概览流使它在日记增删改后重算，与总数、字数等统计保持同一
/// 口径。页面层缓存上一次结果，避免重算期间配图行闪空。
final exploreDiaryImageCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
      // 只作失效触发：概览流发出新列表时重读一次配图来源。
      ref.watch(exploreDiariesProvider);
      final db = ref.watch(appDatabaseProvider);
      const extractor = ExploreContentExtractor();
      final rows = await db.getDiaryImageSourceRefs();
      return <String, int>{
        for (final row in rows)
          row.diaryId: extractor
              .resolveMediaSourcesFrom(cover: row.cover, content: row.content)
              .length,
      };
    });
