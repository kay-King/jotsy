import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../explore/controllers/explore_content_extractor.dart';

/// 桌面页数据：总数、连续天数、最新一篇、图片总数。
class DesktopData {
  const DesktopData({
    required this.totalRecords,
    required this.streakDays,
    required this.latestDiary,
    required this.totalImages,
  });

  const DesktopData.empty()
    : totalRecords = 0,
      streakDays = 0,
      latestDiary = null,
      totalImages = 0;

  /// 日记总数（未删除，含归档）。
  final int totalRecords;

  /// 连续记录天数（口径与探索页一致：从今天起往前数连续有记录的天数）。
  final int streakDays;

  /// 最新一篇（按创建时间取最大）；没有日记时为 null。
  final ExploreDiaryOverview? latestDiary;

  /// 全库图片总数：每篇去重后的图片来源数累加（封面 + 正文图片）。
  final int totalImages;
}

/// 纯函数：从探索页的轻量日记流聚合桌面数据。
///
/// 图片总数不从轻量流里算（它只带纯文本镜像，不含富文本正文）：调用方另用
/// [desktopTotalImagesProvider] 读 [DiaryImageSourceRef] 再累加。
class DesktopDataBuilder {
  const DesktopDataBuilder();

  DesktopData build(
    List<ExploreDiaryOverview> diaries, {
    required DateTime now,
    int totalImages = 0,
  }) {
    if (diaries.isEmpty) {
      return const DesktopData.empty();
    }
    // 连续记录只需“年月日”键，避免为全历史逐条构造本地零点（与探索页
    // ExplorePageController._buildStats 同一套算法与口径）。
    int dayKey(DateTime date) =>
        date.year * 10000 + date.month * 100 + date.day;
    final daySet = <int>{
      for (final item in diaries) dayKey(item.createdAt.toLocal()),
    };
    var streak = 0;
    var probe = DateUtils.dateOnly(now);
    while (probe == DateUtils.dateOnly(probe) &&
        daySet.contains(dayKey(probe))) {
      streak += 1;
      probe = probe.subtract(const Duration(days: 1));
    }
    var latest = diaries.first;
    for (final item in diaries) {
      if (item.createdAt.isAfter(latest.createdAt)) {
        latest = item;
      }
    }
    return DesktopData(
      totalRecords: diaries.length,
      streakDays: streak,
      latestDiary: latest,
      totalImages: totalImages,
    );
  }
}

/// 单篇日记的图片数：去重后的图片来源数（封面 + 正文图片）。
int countDiaryImages(DiaryImageSourceRef ref) {
  const extractor = ExploreContentExtractor();
  return extractor
      .resolveMediaSourcesFrom(cover: ref.cover, content: ref.content)
      .length;
}

/// 全库图片总数：每篇去重后的图片来源数累加。
int countDesktopTotalImages(List<DiaryImageSourceRef> refs) {
  var total = 0;
  for (final ref in refs) {
    total += countDiaryImages(ref);
  }
  return total;
}
