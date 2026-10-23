import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/appearance_language_page.dart';
import 'package:node_diary/ui/settings/pages/about_page.dart';
import 'package:node_diary/ui/settings/pages/app_features_page.dart';
import 'package:node_diary/ui/settings/pages/data_privacy_page.dart';
import 'package:node_diary/ui/settings/pages/editor_settings_page.dart';
import 'package:node_diary/ui/settings/pages/tag_management_page.dart';
import '../../../app/theme/app_spacing.dart';
import '../../home/widgets/home_bar/home_chrome_scope.dart';
import '../../notebooks/pages/notebooks_page.dart';
import '../../widgets/page_header.dart';
import '../controllers/app_update_controller.dart';
import '../providers/app_features_provider.dart';
import '../widgets/app_update_badge.dart';
import '../widgets/settings_card_group.dart';

/// 设置页：一级入口按语义收进两张分组大卡（照 IdeaMemo 设置页的结构：
/// 组标题在卡内顶部、行在卡内平铺），不再一项一张卡摞满屏。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.pageBackgroundColor});

  final Color? pageBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 玻璃顶栏底缘有细线，第一张卡片紧贴它显得挤（实色时同色无线、看不出
    // 来），玻璃时多留 12，与探索页、日历页标题下的间距一致；实色时不变。
    final glassTopGap = HomeChromeScope.glassTopBarsOf(context)
        ? AppSpacing.m
        : 0.0;
    final headerHeight =
        MediaQuery.paddingOf(context).top + PageHeader.contentHeight;
    // 玻璃底栏悬浮在内容之上时，底部 padding 是底栏槽位高度（实色时为 0）：
    // 列表滚到胶囊下方，末尾多留这一段让最后一项完整露出。
    final listBottomPadding = 8.0 + MediaQuery.paddingOf(context).bottom;
    final pageBgColor =
        pageBackgroundColor ?? Theme.of(context).colorScheme.surface;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: ColoredBox(color: pageBgColor)),
        ListView(
          padding: EdgeInsets.only(
            top: headerHeight + glassTopGap,
            bottom: listBottomPadding,
          ),
          children: <Widget>[
            SettingsCardGroup(
              title: l10n.settingsGroupInterface,
              children: <Widget>[
                _SettingsDestination(
                  icon: Icons.palette_outlined,
                  title: l10n.settingsAppearanceLanguage,
                  subtitle: l10n.settingsLanguageSubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return const AppearanceLanguagePage();
                        },
                      ),
                    );
                  },
                ),
                _SettingsDestination(
                  icon: Icons.mode_edit_outlined,
                  title: l10n.settingsEditorTitle,
                  subtitle: l10n.settingsEditorSubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return const EditorSettingsPage();
                        },
                      ),
                    );
                  },
                ),
                _SettingsDestination(
                  icon: Icons.toggle_on_outlined,
                  title: l10n.settingsFeaturesTitle,
                  subtitle: l10n.settingsFeaturesSubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return const AppFeaturesPage();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsCardGroup(
              title: l10n.settingsGroupContent,
              children: <Widget>[
                _SettingsDestination(
                  icon: Icons.label_outlined,
                  title: l10n.settingsTagManagement,
                  subtitle: l10n.settingsTagManagementSubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return const TagManagementPage();
                        },
                      ),
                    );
                  },
                ),
                // 日记本功能关闭时整行隐藏（分组卡内的隐形分割垫片无视觉
                // 影响，不会留双倍间隔）。
                Consumer(
                  builder:
                      (BuildContext context, WidgetRef ref, Widget? child) {
                        final enabled = ref.watch(
                          appFeaturesProvider.select((f) => f.notebooks),
                        );
                        if (!enabled) return const SizedBox.shrink();
                        return _SettingsDestination(
                          icon: Icons.book_outlined,
                          title: l10n.notebookTitle,
                          subtitle: l10n.notebookSettingsSubtitle,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return const NotebooksPage();
                                },
                              ),
                            );
                          },
                        );
                      },
                ),
                _SettingsDestination(
                  icon: Icons.shield_outlined,
                  title: l10n.settingsDataPrivacy,
                  subtitle: l10n.settingsDataPrivacySubtitle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) {
                          return const DataPrivacyPage();
                        },
                      ),
                    );
                  },
                ),
                // 有新版本时在“关于”入口上提示（自动检查或手动检查发现的）。
                Consumer(
                  builder:
                      (BuildContext context, WidgetRef ref, Widget? child) {
                        final hasUpdate = ref.watch(
                          appUpdateControllerProvider.select(
                            (state) => state.hasUpdate,
                          ),
                        );
                        return _SettingsDestination(
                          icon: Icons.info_outlined,
                          title: l10n.settingsAbout,
                          subtitle: l10n.settingsAboutSubtitle,
                          badge: hasUpdate ? const AppUpdateBadge() : null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return const AboutPage();
                                },
                              ),
                            );
                          },
                        );
                      },
                ),
              ],
            ),
          ],
        ),
        PageHeader(title: l10n.settingsTitle),
      ],
    );
  }
}

/// 分组卡内的一行入口：自身不带卡片底，底色与圆角由外层
/// [SettingsCardGroup] 统一提供。
class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// 显示在右侧箭头之前的标记（如“新版本”）。
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // 照 IdeaMemo 设置页：图标裸置、无底块，正文色单色线条感，
      // 固定 40 宽槽位保持各行标题对齐。
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Center(child: Icon(icon, size: 24, color: colors.onSurface)),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (badge != null) ...<Widget>[badge!, const SizedBox(width: 8)],
          Icon(
            Icons.chevron_right,
            size: 18,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
