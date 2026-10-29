import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/timeline_page.dart';
import 'package:node_diary/ui/explore/pages/explore_media_gallery_page.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';

import '../widgets/desktop_card.dart';

/// 六个快捷入口：一张白卡，组标题 + 两行三格 + 分隔线。
///
/// 只留点进去新页面的入口：时间线（时间线页）/ 相册（画廊页）/ 日历
/// （完整日历页）/ 标签（标签管理页）/ 那年今日（概况 + 那年今日页）/
/// 情绪与精力趋势（洞察页）。切底栏 Tab 的「日记」「设置」不在这里——
/// 底栏本来就能切，首页留着是多余的；「备份」「我的」也已拿掉。
///
/// 去重原则：首页上加了按钮，原来的整卡就不要了——标签云、媒体画廊、
/// 那年今日整卡、情绪趋势整卡、首页概况卡都已拿掉，只留按钮。
class DesktopTiles extends ConsumerWidget {
  const DesktopTiles({
    super.key,
    required this.onOpenMemory,
    required this.onOpenInsight,
  });

  /// 点「那年今日」：打开概况 + 那年今日页（由首页传入，带着当页数据）。
  final VoidCallback onOpenMemory;

  /// 点「情绪与精力趋势」：打开洞察页（由首页传入，带着当页数据）。
  final VoidCallback onOpenInsight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DesktopCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DesktopTile(
                  icon: Icons.view_timeline_outlined,
                  label: l10n.desktopTimeline,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TimelinePage(),
                    ),
                  ),
                ),
              ),
              _DesktopTileDivider(colorScheme: colorScheme),
              Expanded(
                child: DesktopTile(
                  icon: Icons.photo_library_outlined,
                  label: l10n.desktopGallery,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ExploreMediaGalleryPage(),
                    ),
                  ),
                ),
              ),
              _DesktopTileDivider(colorScheme: colorScheme),
              Expanded(
                child: DesktopTile(
                  icon: Icons.calendar_month_outlined,
                  label: l10n.desktopCalendar,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CalendarPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: DesktopTile(
                  icon: Icons.label_outlined,
                  label: l10n.desktopTags,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TagManagementPage(),
                    ),
                  ),
                ),
              ),
              _DesktopTileDivider(colorScheme: colorScheme),
              Expanded(
                child: DesktopTile(
                  icon: Icons.history_outlined,
                  label: l10n.autoT0063,
                  onTap: onOpenMemory,
                ),
              ),
              _DesktopTileDivider(colorScheme: colorScheme),
              Expanded(
                child: DesktopTile(
                  icon: Icons.show_chart_outlined,
                  label: l10n.autoT0060,
                  onTap: onOpenInsight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopTileDivider extends StatelessWidget {
  const _DesktopTileDivider({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

/// 单个快捷入口：描边图标 + 文案。
class DesktopTile extends StatelessWidget {
  const DesktopTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 26, color: colorScheme.onSurface),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
