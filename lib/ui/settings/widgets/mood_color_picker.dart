import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/color_swatch_button.dart';
import '../models/mood_palette.dart';

/// 心情颜色选择器：底部面板，点色块即选中并返回。
///
/// 输入：[initial] 当前颜色（用于标出选中态）；
/// 输出：点中的颜色；下滑关闭或点空白处返回 null。
/// 分两组：推荐（10 个默认心情色）与更多（16 个 Material 色系 × 深浅两档，
/// 去掉与推荐重复的值）。
Future<Color?> showMoodColorPicker(
  BuildContext context, {
  required Color initial,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) =>
        _MoodColorPickerSheet(initial: initial),
  );
}

class _MoodColorPickerSheet extends StatelessWidget {
  const _MoodColorPickerSheet({required this.initial});

  final Color initial;

  static final List<Color> _recommended = <Color>[
    for (final value in MoodPalette.defaultColors) Color(value),
  ];

  static final List<Color> _more = <Color>[
    for (final family in <MaterialColor>[
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
    ])
      for (final shade in <int>[400, 700])
        family[shade]!,
  ].where((color) => !_recommended.contains(color)).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initialValue = initial.toARGB32();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsMoodColorPickerTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _SectionLabel(l10n.settingsMoodColorPickerRecommended),
                    _SwatchWrap(
                      colors: _recommended,
                      initialValue: initialValue,
                    ),
                    const SizedBox(height: 8),
                    _SectionLabel(l10n.settingsMoodColorPickerMore),
                    _SwatchWrap(colors: _more, initialValue: initialValue),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SwatchWrap extends StatelessWidget {
  const _SwatchWrap({required this.colors, required this.initialValue});

  final List<Color> colors;
  final int initialValue;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: <Widget>[
        for (final color in colors)
          ColorSwatchButton(
            color: color,
            selected: color.toARGB32() == initialValue,
            semanticLabel: colorSwatchHex(color),
            onTap: () => Navigator.of(context).pop(color),
          ),
      ],
    );
  }
}
