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

  /// 写作统计（概况 / 节奏 / 内容三段）。日记本统计页只复用
  /// [onThisDayDiaries] 时取默认值，不画这三段。
  final ExploreWritingStats writingStats;
}

/// 近 6 个月单月走势：年份、月份、篇数、平均每篇字数。
class ExploreTrendMonth {
  const ExploreTrendMonth({
    required this.year,
    required this.month,
    required this.count,
    required this.avgWords,
  });

  final int year;
  final int month;
  final int count;
  final int avgWords;
}

/// 句式习惯档位：按每 100 字逗号数划分（<3 短句流；3~6 行文平实；>6 长句流）。
enum ExploreSentenceTone { short, plain, long }

/// 写作统计（概况 / 节奏 / 内容三段），由写作统计聚合器从探索页概览
/// + 配图计数聚合。口径与 fakeWechat 统计页一致，见聚合器注释。
class ExploreWritingStats {
  const ExploreWritingStats({
    required this.totalWords,
    required this.avgWordsPerDiary,
    required this.firstDiaryAt,
    required this.recordDays,
    required this.lastDiaryAt,
    required this.recent7Days,
    required this.longestGapDays,
    required this.wordsByDay,
    required this.monthWords,
    required this.monthCounts,
    required this.trendMonths,
    required this.hourCounts,
    required this.weekdayCounts,
    required this.bestHour,
    required this.bestWeekday,
    required this.maxSingleWords,
    required this.diariesWithImages,
    required this.totalImages,
    required this.avgImagesPerDiary,
    required this.commaPer100,
    required this.sentenceTone,
    required this.exclamationCount,
    required this.questionCount,
    required this.ellipsisCount,
    required this.emojiCount,
  });

  const ExploreWritingStats.empty()
    : totalWords = 0,
      avgWordsPerDiary = 0,
      firstDiaryAt = null,
      recordDays = 0,
      lastDiaryAt = null,
      recent7Days = 0,
      longestGapDays = null,
      wordsByDay = const <int, int>{},
      monthWords = const <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      monthCounts = const <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      trendMonths = const <ExploreTrendMonth>[],
      hourCounts = const <int>[
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ],
      weekdayCounts = const <int>[0, 0, 0, 0, 0, 0, 0],
      bestHour = -1,
      bestWeekday = -1,
      maxSingleWords = 0,
      diariesWithImages = 0,
      totalImages = 0,
      avgImagesPerDiary = 0,
      commaPer100 = 0,
      sentenceTone = null,
      exclamationCount = 0,
      questionCount = 0,
      ellipsisCount = 0,
      emojiCount = 0;

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

  /// 近 7 天的篇数（含今天）。
  final int recent7Days;

  /// 相邻两个有记录的日子之间最多空了多少天；0 表示没有空档，
  /// null 表示不足两天记录、无从计算。
  final int? longestGapDays;

  /// 每天的字数：键为本地年月日 `yyyyMMdd`，值为当天各篇字数之和。
  final Map<int, int> wordsByDay;

  /// 今年每月字数（下标 0 为 1 月）。
  final List<int> monthWords;

  /// 今年每月篇数（下标 0 为 1 月）。
  final List<int> monthCounts;

  /// 近 6 个月走势（含本月，由早到晚）。
  final List<ExploreTrendMonth> trendMonths;

  /// 一天里各小时的篇数（下标为小时 0~23）。
  final List<int> hourCounts;

  /// 一周里各天的篇数（下标 0 为周日）。
  final List<int> weekdayCounts;

  /// 写得最多的小时；样本不足（<5 篇）时为 -1，不下结论。
  final int bestHour;

  /// 写得最多的星期几（0 为周日）；样本不足时为 -1。
  final int bestWeekday;

  /// 最长一篇的字数。
  final int maxSingleWords;

  /// 带图日记的篇数。
  final int diariesWithImages;

  /// 图片总数（每篇内按来源去重）。
  final int totalImages;

  /// 平均每篇配图数（按全部日记算，保留一位小数）。
  final double avgImagesPerDiary;

  /// 每 100 字的逗号数（保留一位小数）。
  final double commaPer100;

  /// 句式习惯档位；没有正文时为 null。
  final ExploreSentenceTone? sentenceTone;

  /// 全文标点计数（注脚用）：感叹号、问号、省略号、表情。
  final int exclamationCount;
  final int questionCount;
  final int ellipsisCount;
  final int emojiCount;
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
