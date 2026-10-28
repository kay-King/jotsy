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

/// 探索页媒体画廊的图片来源（每篇日记的全部图片，封面优先、去重）。
///
/// 概览流不带富文本正文，所以画廊预览只能看到封面（每篇 1 张）；
/// 这里单独取封面 + 正文原文解析出每篇的全部图片，供画廊预览与
/// 全量媒体页共用同一口径。跟随日记流刷新；加载中或失败时调用方
/// 回落到只用封面（预览仍可渲染，不会空白）。
final exploreMediaSourcesProvider = FutureProvider<Map<String, List<String>>>((
  ref,
) async {
  // 跟随日记流：日记增删改时重新解析。
  await ref.watch(exploreDiariesProvider.future);
  final db = ref.watch(appDatabaseProvider);
  const extractor = ExploreContentExtractor();
  final refs = await db.getDiaryImageSourceRefs();
  return <String, List<String>>{
    for (final item in refs)
      item.diaryId: extractor.resolveMediaSourcesFrom(
        cover: item.cover,
        content: item.content,
      ),
  };
});
