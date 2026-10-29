import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../controllers/explore_page_controller.dart';
import '../models/explore_view_data.dart';
import '../sections/explore_memory_card.dart';
import '../sections/explore_overview_card.dart';

/// 那年今日页：上面是概况（写作统计、连续天数），下面是那年今日内容。
///
/// 首页不再单独放概况卡（避免重复），概况随那年今日按钮进这个页面。
/// 两张卡都是现成的探索卡复用，本页只负责组合与顶栏。
class ExploreMemoryPage extends StatelessWidget {
  const ExploreMemoryPage({
    super.key,
    required this.viewData,
    required this.controller,
    required this.onOpenDiary,
    required this.onCreateToday,
  });

  final ExploreViewData viewData;
  final ExplorePageController controller;
  final ValueChanged<String> onOpenDiary;
  final VoidCallback onCreateToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppTopBar(
        centerTitle: true,
        title: Text(l10n.autoT0063),
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          ExploreOverviewCard(
            stats: viewData.writingStats,
            totalRecords: viewData.stats.totalRecords,
            streakDays: viewData.stats.streakDays,
            currentMonthWords: viewData.stats.currentMonthWords,
            now: DateTime.now(),
          ),
          const SizedBox(height: 12),
          ExploreMemoryCard(
            viewData: viewData,
            controller: controller,
            onOpenDiary: onOpenDiary,
            onCreateToday: onCreateToday,
          ),
        ],
      ),
    );
  }
}
