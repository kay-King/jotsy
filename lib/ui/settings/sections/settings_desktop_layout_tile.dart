import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/models/desktop_layout/desktop_layout.dart';
import '../pages/desktop_layout_page.dart';

/// 外观与语言页的“首页布局”入口。
///
/// 副标题显示当前布局的摘要：全部默认时显示“默认布局”，自定义后显示
/// 可见区块的数量，跟随 raw notifier 实时更新。
class SettingsDesktopLayoutTile extends StatelessWidget {
  const SettingsDesktopLayoutTile({super.key, required this.settingsAsync});

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    return settingsAsync.when(
      data: (SettingsService settings) => ValueListenableBuilder<String?>(
        valueListenable: settings.desktopLayoutRawNotifier,
        builder: (BuildContext context, String? raw, Widget? child) {
          final layout = DesktopLayout.decode(raw);
          final visibleCount = layout.visibleModuleIds.length;
          final subtitle = layout.isDefault
              ? l10n.desktopLayoutEntryDefault
              : l10n.desktopLayoutEntryCustom(visibleCount);
          return ListTile(
            contentPadding: padding,
            title: Text(l10n.desktopLayoutTitle),
            subtitle: Text(subtitle),
            trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    DesktopLayoutPage(settingsService: settings),
              ),
            ),
          );
        },
      ),
      loading: () => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.desktopLayoutTitle),
      ),
      error: (Object error, StackTrace stackTrace) => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.desktopLayoutTitle),
      ),
    );
  }
}
