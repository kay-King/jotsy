import 'package:flutter/material.dart';

import '../../controllers/home_bar_style_editor_controller.dart';
import '../../widgets/style_editor/style_editor_common.dart';

/// 预览工具条：只有预览明暗切换（导航栏没有需要在预览里切换的布局）。
class HomeBarStylePreviewToolbar extends StatelessWidget {
  const HomeBarStylePreviewToolbar({super.key, required this.controller});

  final HomeBarStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    // 与其它三页统一：白底圆 32px 明暗按钮，不用 IconButton.filledTonal
    //（MD3 色调按钮，48px、带色调底色，和顶栏其它白圆按钮不统一）。
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          const Spacer(),
          StylePreviewBrightnessButton(controller: controller),
        ],
      ),
    );
  }
}
