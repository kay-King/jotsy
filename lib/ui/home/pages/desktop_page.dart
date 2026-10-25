import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/ui/diaries/providers/diary_profile_provider.dart';
import 'package:node_diary/ui/explore/providers/explore_providers.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/launch_reveal.dart';

import '../models/desktop_view_data.dart';
import '../providers/desktop_providers.dart';
import '../sections/desktop_header.dart';
import '../sections/desktop_latest.dart';
import '../sections/desktop_tiles.dart';
import '../sections/desktop_write_button.dart';

/// 桌面页（首页底栏第一个 Tab，可在设置 → 功能管理关闭）。
///
/// 从 my-diary-fakeWechat 的桌面页搬过来（只搬样子与思路，代码按 jotsy
/// 自己的数据与组件重写）：日期 + 按时间变的问候 + 一行总览数 + 三个带数
/// 字角标的快捷入口（时间线 / 相册 / 我的）+ 最新一篇。
///
/// 数据只读、不改写任何功能逻辑：总数与连续天数来自探索页的轻量日记流，
/// 图片数来自桌面自己的统计 provider，最新一篇点进去是现有的预览页。
class DesktopPage extends ConsumerWidget {
  const DesktopPage({super.key, required this.pageBackgroundColor});

  final Color pageBackgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final profile = ref.watch(diaryProfileProvider);
    final diariesAsync = ref.watch(exploreDiariesProvider);
    final imageCountsAsync = ref.watch(desktopDiaryImageCountsProvider);
    final diaries = diariesAsync.asData?.value;
    final imageCounts = imageCountsAsync.asData?.value;
    final totalImages = imageCounts == null
        ? 0
        : imageCounts.values.fold<int>(0, (sum, count) => sum + count);
    final data = diaries == null
        ? null
        : const DesktopDataBuilder().build(
            diaries,
            now: now,
            totalImages: totalImages,
          );
    final latestImageCount = data?.latestDiary == null
        ? 0
        : imageCounts?[data!.latestDiary!.diaryId] ?? 0;

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            // 启动编排：首页首屏的一级区块经 LaunchReveal 声明槽位（仓库规范），
            // 与日记页的顶栏/标签栏/导航/FAB 一样按错峰浮起；没有 scope
            // （单独挂载的预览/测试）时原样返回子树，不影响画面。
            LaunchReveal(
              slot: LaunchRevealSlot.masthead,
              child: DesktopHeader(now: now, nickname: profile.displayNickname),
            ),
            const SizedBox(height: 6),
            LaunchReveal(
              slot: LaunchRevealSlot.content(0),
              child: DesktopStatsLine(data: data, now: now),
            ),
            const SizedBox(height: 20),
            if (data == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: ExpressiveLoadingIndicator()),
              )
            else ...<Widget>[
              LaunchReveal(
                slot: LaunchRevealSlot.content(1),
                child: const DesktopWriteButton(),
              ),
              const SizedBox(height: 16),
              LaunchReveal(
                slot: LaunchRevealSlot.content(2),
                child: const DesktopTiles(),
              ),
              const SizedBox(height: 16),
              LaunchReveal(
                slot: LaunchRevealSlot.content(3),
                child: DesktopLatest(
                  latest: data.latestDiary,
                  imageCount: latestImageCount,
                  now: now,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
