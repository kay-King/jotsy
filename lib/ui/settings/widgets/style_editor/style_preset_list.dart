import 'package:flutter/material.dart';

import 'style_editor_common.dart';

/// 内置预设的药丸按钮：每颗药丸就是预设名，自动换行排布（阅读软件风，
/// 只借感觉：选中 Salt 蓝底白字、未选中白底灰字灰边，不照搬阅读软件的
/// 红色选中态）。不要卡片格子（占空间）、不要迷你缩略图（灰块显丑）、
/// 不要纯文字列表行（太干）。
@immutable
class StylePresetOption<T> {
  const StylePresetOption({required this.id, required this.name});

  final T id;
  final String name;
}

/// 内置预设的药丸组：选中态由 [StylePillGroup] 按 Salt 蓝底白字画；
/// 当前样式不是任何内置预设时（自定义）没有选中项。
class StylePresetList<T> extends StatelessWidget {
  const StylePresetList({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<StylePresetOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return StylePillGroup<T>(
      segments: <ButtonSegment<T>>[
        for (final option in options)
          ButtonSegment<T>(value: option.id, label: Text(option.name)),
      ],
      selected: current == null ? <T>{} : <T>{current},
      onSelectionChanged: (Set<T> value) => onSelected(value.single),
    );
  }
}
