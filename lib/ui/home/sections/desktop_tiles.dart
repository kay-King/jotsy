import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/explore/pages/explore_media_gallery_page.dart';
import 'package:node_diary/ui/settings/pages/data_management_page.dart';
import 'package:node_diary/ui/settings/pages/profile_page.dart';

import '../models/home_tab.dart';
import '../providers/home_tab_request_provider.dart';
import '../widgets/desktop_card.dart';

/// 六个快捷入口：一张白卡里两行三格 + 分隔线（用户说角标不需要，已去掉）。
///
/// 第一行：时间线（日记页）/ 相册（画廊页）/ 日记（日记页）；
/// 第二行：备份（数据管理页）/ 设置（设置 Tab）/ 我的（个人资料页）。
class DesktopTiles extends ConsumerWidget {
  const DesktopTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DesktopCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: DesktopTile(
                  icon: Icons.view_timeline_outlined,
                  label: l10n.desktopTimeline,
                  onTap: () => ref
                      .read(homeTabRequestProvider.notifier)
                      .request(HomeTab.diaries),
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
                  icon: Icons.book_outlined,
                  label: l10n.desktopDiary,
                  onTap: () => ref
                      .read(homeTabRequestProvider.notifier)
                      .request(HomeTab.diaries),
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
                  icon: Icons.backup_outlined,
                  label: l10n.desktopBackup,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DataManagementPage(),
                    ),
                  ),
                ),
              ),
              _DesktopTileDivider(colorScheme: colorScheme),
              Expanded(
                child: DesktopTile(
                  icon: Icons.settings_outlined,
                  label: l10n.navSettings,
                  onTap: () => ref
                      .read(homeTabRequestProvider.notifier)
                      .request(HomeTab.settings),
                ),
              ),
              _DesktopTileDivider(colorScheme: colorScheme),
              Expanded(
                child: DesktopTile(
                  icon: Icons.person_outlined,
                  label: l10n.desktopMine,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfilePage(),
                    ),
                  ),
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
