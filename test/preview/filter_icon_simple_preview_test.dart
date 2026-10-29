// 筛选图标极简预览：只渲染图标按钮本身（灰色无筛选 / 主题色+小圆点有筛选）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('MaterialIcons');
  loader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await loader.load();
}

/// 跟 diary_head_section.dart 里 _TrailingActions 的筛选按钮同款。
Widget _filterButton({required bool hasActiveFilter}) {
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0470E6));
  return Material(
    color: const Color(0xFFFAFBFC),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 无筛选：灰色
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_outlined),
                color: Colors.grey,
                onPressed: () {},
              ),
              if (hasActiveFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 24),
          // 有筛选：主题色 + 小圆点
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_outlined),
                color: colorScheme.primary,
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('filter icon simple preview', (tester) async {
    await _loadFonts();
    final binding = tester.binding;
    binding.window.physicalSizeTestValue = const Size(600, 200);
    binding.window.devicePixelRatioTestValue = 2.0;
    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _filterButton(hasActiveFilter: false))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/filter_icon_simple.png'),
    );
  });
}
