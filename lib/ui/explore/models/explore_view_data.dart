/// 探索页聚合后的只读视图模型。
///
/// 作用：
/// - 将“统计/趋势/回顾”数据统一收敛为页面可直接消费的数据结构；
/// - 避免页面层重复进行 JSON 解析与集合聚合；
/// - 让 UI 组件只关心渲染，不关心计算过程。
class ExploreViewData {
  const ExploreViewData({
    required this.stats,
    required this.onThisDayDiaries,
    required this.fallbackPrompt,
    required this.moodWeights30,
    required this.energyValues7,
    required this.tagUsages,
    required this.mediaItems,
    this.writingStats = const ExploreWritingStats.empty(),
  });

  final ExploreStats stats;
  final List<ExploreOnThisDayItem> onThisDayDiaries;
  final String fallbackPrompt;
  final List<double?> moodWeights30;
  final List<double?> energyValues7;
  final List<ExploreTagUsage> tagUsages;
  final List<ExploreMediaItem> mediaItems;

  /// 写作统计（只剩概况卡要的字段）。日记本统计页只复用
  /// [onThisDayDiaries] 时取默认值，不画概况卡。
  final ExploreWritingStats writingStats;
}

/// 写作统计（概况卡），由写作统计聚合器从探索页概览聚合。
/// 节奏 / 内容两张卡与概况里的热力图已下线（2026-10-25），
/// 只留概况三行要的字段。
class ExploreWritingStats {
  const ExploreWritingStats({
    required this.totalWords,
    required this.avgWordsPerDiary,
    required this.firstDiaryAt,
    required this.recordDays,
    required this.lastDiaryAt,
  });

  const ExploreWritingStats.empty()
    : totalWords = 0,
      avgWordsPerDiary = 0,
      firstDiaryAt = null,
      recordDays = 0,
      lastDiaryAt = null;

  /// 累计字数。
  final int totalWords;

  /// 平均每篇字数（四舍五入）。
  final int avgWordsPerDiary;

  /// 第一篇的创建时间；没有日记时为 null。
  final DateTime? firstDiaryAt;

  /// 有记录的天数。
  final int recordDays;

  /// 最近一篇的创建时间；没有日记时为 null。
  final DateTime? lastDiaryAt;
}

/// “那年今日”轮播项。
///
/// 回忆卡只需要轻量字段，不再持有完整 `DiaryWithTags`，避免探索页为了
/// 卡片摘要和图片预览加载富文本 Delta 正文。
class ExploreOnThisDayItem {
  const ExploreOnThisDayItem({
    required this.diaryId,
    required this.title,
    required this.summaryText,
    required this.timeLabel,
    this.mediaSource,
  });

  final String diaryId;
  final String title;
  final String summaryText;
  final String timeLabel;
  final String? mediaSource;
}

/// 顶部轻量看板数据。
class ExploreStats {
  const ExploreStats({
    required this.totalRecords,
    required this.streakDays,
    required this.currentMonthWords,
  });

  final int totalRecords;
  final int streakDays;
  final int currentMonthWords;
}

/// 标签云展示项。
class ExploreTagUsage {
  const ExploreTagUsage({
    required this.id,
    required this.name,
    required this.color,
    required this.count,
    required this.latestDiaryId,
    required this.latestAt,
    required this.maxCount,
  });

  final int id;
  final String name;
  final int color;
  final int count;
  final String latestDiaryId;
  final DateTime latestAt;
  final int maxCount;

  ExploreTagUsage copyWith({
    int? count,
    String? latestDiaryId,
    DateTime? latestAt,
    int? maxCount,
  }) {
    return ExploreTagUsage(
      id: id,
      name: name,
      color: color,
      count: count ?? this.count,
      latestDiaryId: latestDiaryId ?? this.latestDiaryId,
      latestAt: latestAt ?? this.latestAt,
      maxCount: maxCount ?? this.maxCount,
    );
  }
}

/// 媒体画廊项。
/// 媒体画廊的分组粒度：按年 / 按月 / 按日分段（替代原来的年月筛选，
/// 照 ente 的 GroupType 做法：粒度只决定分段，不筛掉任何照片）。
enum GalleryGroupType { year, month, day }

/// 解析持久化的分组粒度；未知值回退为按月（画廊一直以来的默认分段）。
GalleryGroupType galleryGroupTypeFromRaw(String? raw) => switch (raw) {
  'year' => GalleryGroupType.year,
  'day' => GalleryGroupType.day,
  _ => GalleryGroupType.month,
};

/// 画廊分段：按视图粒度把已排序的图片切成段（保持传入顺序，不筛掉任何
/// 照片）。段键是截到粒度的本地日期：年视图只留年，月视图留年月，
/// 日视图留年月日；标题层按同一粒度格式化。
List<({DateTime key, List<ExploreMediaItem> items})> groupGalleryItems(
  List<ExploreMediaItem> items,
  GalleryGroupType view,
) {
  final groups = <DateTime, List<ExploreMediaItem>>{};
  final order = <DateTime>[];
  for (final item in items) {
    final created = item.createdAt.toLocal();
    final key = switch (view) {
      GalleryGroupType.year => DateTime(created.year),
      GalleryGroupType.month => DateTime(created.year, created.month),
      GalleryGroupType.day => DateTime(
        created.year,
        created.month,
        created.day,
      ),
    };
    if (!groups.containsKey(key)) {
      groups[key] = <ExploreMediaItem>[];
      order.add(key);
    }
    groups[key]!.add(item);
  }
  return <({DateTime key, List<ExploreMediaItem> items})>[
    for (final key in order) (key: key, items: groups[key]!),
  ];
}

class ExploreMediaItem {
  const ExploreMediaItem({
    required this.source,
    required this.diaryId,
    required this.updatedAt,
    required this.createdAt,
  });

  final String source;
  final String diaryId;
  final DateTime updatedAt;

  /// 所在日记的创建时间：相册按月分组与正倒排序都按它算（不是修改时间）。
  final DateTime createdAt;
}
