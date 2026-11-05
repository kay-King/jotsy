import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import 'package:node_diary/ui/widgets/color_swatch_button.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';
import '../models/mood_palette.dart';
import '../widgets/mood_color_picker.dart';
import '../widgets/settings_card_group.dart';

/// 心情符号与颜色自定义页。
///
/// 职责边界：
/// - 输入/输出固定 10 个心情槽位，顺序从低落到高兴；
/// - 符号与颜色一起存进 [MoodPalette]（单个 JSON 键），供发布/编辑面板、
///   日历聚合、探索趋势与预览页配色共用；
/// - “重置”同时恢复符号与颜色；
/// - 不负责历史日记迁移，历史默认符号仍由权重映射兼容。
class MoodOptionsPage extends StatefulWidget {
  const MoodOptionsPage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<MoodOptionsPage> createState() => _MoodOptionsPageState();
}

class _MoodOptionsPageState extends State<MoodOptionsPage> {
  late final List<TextEditingController> _controllers;
  late List<Color> _colors;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final palette = widget.settingsService.moodPalette;
    _controllers = List<TextEditingController>.generate(
      MoodPalette.slotCount,
      (index) => TextEditingController(text: palette.symbols[index]),
    );
    _colors = <Color>[for (final value in palette.colors) Color(value)];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final palette = MoodPalette(
      symbols: <String>[for (final controller in _controllers) controller.text],
      colors: <int>[for (final color in _colors) color.toARGB32()],
    );
    setState(() => _saving = true);
    try {
      await widget.settingsService.setMoodPalette(palette);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(
            context.l10n.settingsMoodOptionsSaveFailed(error.toString()),
          ),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      for (var index = 0; index < _controllers.length; index += 1) {
        _controllers[index].text = MoodPalette.defaultSymbols[index];
        _colors[index] = Color(MoodPalette.defaultColors[index]);
      }
    });
  }

  Future<void> _pickColor(int index) async {
    if (_saving) {
      return;
    }
    final picked = await showMoodColorPicker(context, initial: _colors[index]);
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _colors[index] = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppTopBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(l10n.settingsMoodOptionsTitle),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _reset,
            child: Text(l10n.commonReset),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: <Widget>[
          // 10 个心情槽位收进一张分组白卡（与其他设置页统一）：每行左侧是
          // 颜色块（点开换颜色），中间是标签与默认值提示，右侧是表情输入位。
          SettingsCardGroup(
            title: l10n.settingsMoodOptionsTitle,
            children: <Widget>[
              for (var index = 0; index < _controllers.length; index += 1)
                _MoodOptionField(
                  controller: _controllers[index],
                  index: index,
                  color: _colors[index],
                  enabled: !_saving,
                  onPickColor: () => _pickColor(index),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodOptionField extends StatelessWidget {
  const _MoodOptionField({
    required this.controller,
    required this.index,
    required this.color,
    required this.enabled,
    required this.onPickColor,
  });

  final TextEditingController controller;
  final int index;
  final Color color;
  final bool enabled;
  final VoidCallback onPickColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.settingsMoodOptionsSlotLabel((index + 1).toString());
    final defaultEmoji = MoodPalette.defaultSymbols[index];
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: <Widget>[
          ColorSwatchButton(
            color: color,
            selected: false,
            showCheck: false,
            swatchSize: 28,
            semanticLabel: l10n.settingsMoodColorSemanticLabel(
              (index + 1).toString(),
            ),
            onTap: enabled ? onPickColor : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.settingsMoodOptionsSlotHelper(defaultEmoji),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: TextField(
              contextMenuBuilder: appTextContextMenuBuilder,
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              maxLength: 8,
              style: textTheme.headlineSmall,
              decoration: const InputDecoration(
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
