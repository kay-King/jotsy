// AI 洞察：最近一次回顾的摘录（点按打开），下面是“生成本周回顾”与
// “问问我的日记”。
//
// fork 适配（上游 883d470e 挂在探索页模块系统 `ExploreModuleSpec` /
// `ExploreActionsScope` 上，fork 没有模块系统，探索页是
// `ExploreMemoryPage` 里两张卡的直接组合）：
// - 标题用 fork 探索页的 `ExploreSectionTitle`，卡片容器复用 `ExploreCard`；
// - 没有 `ExploreCardHeader` / `ExploreInlineHint`，提示行就地写；
// - 导航不经 `ExploreActionsScope`，直接推回顾页 / 助手主页 / 设置页；
// - AI 开关关闭时整张不显示（由调用方 `ExploreMemoryPage` 按
//   `aiHubAvailableProvider` 决定是否放这张卡）；开着但还没配好服务时
//   提示去设置；回顾模块关闭时不给“生成”按钮，已有的回顾照常显示。
// 渲染时不联网，只读已保存的回顾（[aiRecapsProvider]）；生成经回顾页
// （进入即生成，仍经发送前确认）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../ai/models/ai_preference_parts.dart';
import '../../ai/models/ai_recap_range.dart';
import '../../ai/pages/ai_hub_page.dart';
import '../../ai/pages/ai_recap_page.dart';
import '../../ai/pages/ai_recap_view_page.dart';
import '../../ai/pages/settings/ai_settings_page.dart';
import '../../ai/providers/ai_providers.dart';
import '../../ai/providers/ai_records_providers.dart';
import '../../ai/viewmodels/ai_labels.dart';
import '../widgets/explore_shared_widgets.dart';

class ExploreAiInsightCard extends ConsumerWidget {
  const ExploreAiInsightCard({super.key});

  void _openRecap(
    BuildContext context, {
    String? resultId,
    bool weekly = false,
  }) {
    final id = resultId;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => id != null
              ? AiRecapViewPage(resultId: id)
              : AiRecapPage(autoStart: weekly),
        ),
      ),
    );
  }

  void _openHub(BuildContext context) {
    unawaited(
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => const AiHubPage())),
    );
  }

  void _openSettings(BuildContext context) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AiSettingsPage()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final available = ref.watch(aiAvailableProvider);
    final recapOn = ref.watch(aiModuleAvailableProvider(AiModule.recap));
    final chatOn = ref.watch(aiModuleAvailableProvider(AiModule.chat));
    final recaps = ref.watch(aiRecapsProvider).value;
    final latest = recaps == null || recaps.isEmpty ? null : recaps.first;
    final children = <Widget>[
      ExploreSectionTitle(
        icon: FontAwesomeIcons.wandMagicSparkles,
        title: l10n.exploreModuleAi,
      ),
    ];
    if (!available) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.aiExploreNotConfigured,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openSettings(context),
                child: Text(l10n.aiErrorOpenSettings),
              ),
            ],
          ),
        ),
      );
    } else {
      if (latest != null) {
        final decoded = AiRecapScope.decode(latest.scope);
        final preset = decoded.preset;
        final heading = [
          if (preset != null && preset != AiRecapPreset.custom)
            aiRecapPresetLabel(l10n, preset),
          latest.title,
          ?decoded.scope.notebookName,
        ].where((part) => part.trim().isNotEmpty).join(' · ');
        children.add(
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openRecap(context, resultId: latest.resultId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aiRecapExcerpt(latest.content, max: 160),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (recaps != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.aiExploreNoRecap,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      if (recapOn || chatOn) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                if (recapOn)
                  TextButton.icon(
                    onPressed: () => _openRecap(context, weekly: true),
                    icon: const FaIcon(FontAwesomeIcons.calendarWeek, size: 14),
                    label: Text(l10n.aiExploreWeekly),
                  ),
                if (chatOn)
                  TextButton.icon(
                    onPressed: () => _openHub(context),
                    icon: const FaIcon(FontAwesomeIcons.comments, size: 14),
                    label: Text(l10n.aiExploreAsk),
                  ),
              ],
            ),
          ),
        );
      }
    }
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
