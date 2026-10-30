import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/models/desktop_layout/desktop_layout.dart';
import 'package:node_diary/ui/home/models/desktop_layout/desktop_layout_code.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/expressive_reorder_proxy.dart';
import 'package:node_diary/ui/widgets/triple_bar_drag_handle.dart';

/// 首页布局页：四个区块（题头 / 写点什么 / 快捷入口 / 最近记录）的
/// 顺序与显隐。
///
/// 拖拽排序、勾选开关，改动即时保存（首页实时跟随，不用点保存）。
/// 布局码（`jotsy-home:v1:…`）可经剪贴板分享与导入，格式与样式码同源。
class DesktopLayoutPage extends StatefulWidget {
  const DesktopLayoutPage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<DesktopLayoutPage> createState() => _DesktopLayoutPageState();
}

class _DesktopLayoutPageState extends State<DesktopLayoutPage> {
  late DesktopLayout _layout;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _layout = DesktopLayout.decode(widget.settingsService.desktopLayoutRaw);
  }

  Future<void> _persist() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.settingsService.setDesktopLayoutRaw(_layout.encode());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    final modules = _layout.modules.toList();
    final moved = modules.removeAt(oldIndex);
    modules.insert(newIndex, moved);
    setState(() {
      _layout = DesktopLayout(modules: List.unmodifiable(modules));
    });
    unawaited(_persist());
  }

  void _handleToggle(DesktopModuleId id, bool? visible) {
    setState(() {
      _layout = _layout.withVisibility(id, visible ?? true);
    });
    unawaited(_persist());
  }

  Future<void> _handleReset() async {
    setState(() => _layout = DesktopLayout.defaults);
    await _persist();
  }

  Future<void> _copyCode() async {
    final code = DesktopLayoutCode.encode(_layout);
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(context.l10n.desktopLayoutCodeCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _importCode() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final pasted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.desktopLayoutImportTitle),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.desktopLayoutImportHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    final result = DesktopLayoutCode.decode(pasted);
    final message = switch (result.status) {
      StyleCodeStatus.empty => l10n.desktopLayoutImportEmpty,
      StyleCodeStatus.invalid => l10n.desktopLayoutImportInvalid,
      StyleCodeStatus.ok ||
      StyleCodeStatus.newerVersion => l10n.desktopLayoutImported,
    };
    if (result.status == StyleCodeStatus.ok ||
        result.status == StyleCodeStatus.newerVersion) {
      final layout = result.style;
      if (layout != null) {
        setState(() => _layout = layout);
        await _persist();
      }
    }
    if (!mounted) return;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _iconFor(DesktopModuleId id, Color color) {
    switch (id) {
      case DesktopModuleId.header:
        return FaIcon(FontAwesomeIcons.calendarDay, size: 20, color: color);
      case DesktopModuleId.writeButton:
        return FaIcon(FontAwesomeIcons.pen, size: 20, color: color);
      case DesktopModuleId.quickEntry:
        return Icon(Icons.grid_view_outlined, size: 20, color: color);
      case DesktopModuleId.recent:
        return FaIcon(FontAwesomeIcons.clockRotateLeft, size: 20, color: color);
    }
  }

  String _titleFor(AppLocalizations l10n, DesktopModuleId id) => switch (id) {
    DesktopModuleId.header => l10n.desktopLayoutModuleHeader,
    DesktopModuleId.writeButton => l10n.desktopLayoutModuleWriteButton,
    DesktopModuleId.quickEntry => l10n.desktopLayoutModuleQuickEntry,
    DesktopModuleId.recent => l10n.desktopLayoutModuleRecent,
  };

  String _subtitleFor(AppLocalizations l10n, DesktopModuleId id) =>
      switch (id) {
        DesktopModuleId.header => l10n.desktopLayoutModuleHeaderDesc,
        DesktopModuleId.writeButton => l10n.desktopLayoutModuleWriteButtonDesc,
        DesktopModuleId.quickEntry => l10n.desktopLayoutModuleQuickEntryDesc,
        DesktopModuleId.recent => l10n.desktopLayoutModuleRecentDesc,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final modules = _layout.modules;
    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.desktopLayoutTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.desktopLayoutReset,
            onPressed: _saving ? null : _handleReset,
            icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 16),
          ),
          IconButton(
            tooltip: l10n.desktopLayoutCopyCode,
            onPressed: _saving ? null : _copyCode,
            icon: const FaIcon(FontAwesomeIcons.copy, size: 16),
          ),
          IconButton(
            tooltip: l10n.desktopLayoutImportCode,
            onPressed: _saving ? null : _importCode,
            icon: const FaIcon(FontAwesomeIcons.paste, size: 16),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          Text(
            l10n.desktopLayoutIntro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: ExpressiveSurfaces.cardColor(Theme.of(context).colorScheme),
            borderRadius: BorderRadius.circular(AppRadii.card),
            clipBehavior: Clip.antiAlias,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              buildDefaultDragHandles: false,
              proxyDecorator: expressiveReorderProxyDecorator,
              itemCount: modules.length,
              onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
              // onReorderItem 的 newIndex 已按移除做过调整，直接插入即可。
              onReorderItem: _handleReorder,
              itemBuilder: (BuildContext context, int index) {
                final spec = modules[index];
                final id = spec.id;
                return ListTile(
                  key: ValueKey<String>('desktop-layout-${id.name}'),
                  leading: Checkbox(
                    value: spec.visible,
                    onChanged: _saving
                        ? null
                        : (value) => _handleToggle(id, value),
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _iconFor(
                        id,
                        spec.visible
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _titleFor(l10n, id),
                          style: spec.visible
                              ? null
                              : TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(_subtitleFor(l10n, id)),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const SizedBox(
                      width: 44,
                      height: 40,
                      child: ColoredBox(
                        color: Colors.transparent,
                        child: Center(child: TripleBarDragHandle()),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
