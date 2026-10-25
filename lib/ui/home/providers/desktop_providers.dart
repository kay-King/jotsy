import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../explore/providers/explore_providers.dart';
import '../models/desktop_view_data.dart';

/// 桌面页每篇日记的图片数（diaryId → 去重后的图片来源数）。
///
/// 只在桌面页打开时加载一次（autoDispose），桌面关掉即释放；以轻量日记流
/// 为失效触发（有新日记写入时重新统计），本身不取流里的数据，避免常驻监听
/// 全量富文本正文。
///
/// 桌面用它算两处：相册角标 = 全部加总；最近记录的“ N 张图片” = 最新一篇
/// 的那一项。
final desktopDiaryImageCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
      final db = ref.watch(appDatabaseProvider);
      ref.watch(exploreDiariesProvider);
      final refs = await db.getDiaryImageSourceRefs();
      return <String, int>{
        for (final item in refs) item.diaryId: countDiaryImages(item),
      };
    });
