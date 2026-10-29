import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../sections/explore_insight_card.dart';

/// 情绪与精力趋势页：就是原来首页上那张洞察卡，整卡挪到新页面里。
///
/// 首页不再单独放这张整卡（避免与快捷入口里的按钮重复），点快捷入口
/// 里的「情绪与精力趋势」按钮进这里。卡片本身是现成的复用，本页只
/// 负责组合与顶栏。
class ExploreInsightPage extends StatelessWidget {
  const ExploreInsightPage({
    super.key,
    required this.moodWeights30,
    required this.energyValues7,
  });

  final List<double?> moodWeights30;
  final List<double?> energyValues7;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppTopBar(
        centerTitle: true,
        title: Text(l10n.autoT0060),
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          ExploreInsightCard(
            moodWeights30: moodWeights30,
            energyValues7: energyValues7,
          ),
        ],
      ),
    );
  }
}
