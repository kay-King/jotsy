import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/app/theme/theme.dart';

/// 组件回归使用与应用相同的主题装配，避免只在 Flutter 默认主题下验证。
ThemeData expressiveTestTheme(
  Brightness brightness, {
  Color seedColor = const Color(0xff1e6586),
}) =>
    MaterialTheme(
      brightness == Brightness.light
          ? Typography.material2021().black
          : Typography.material2021().white,
    ).theme(
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
    );

bool _defaultFontMetricsLoaded = false;

/// 把随包字体的真实度量注册到默认字族 Roboto 名下（只需调一次）。
///
/// 主题已不指定 UI 字族（走系统默认），测试环境里 Roboto 没有真实
/// 字体承接时会按 Ahem 假字体（一字一格）排版，布局敏感的断言
/// （表项高度、页签适配）会测到假度量。在布局敏感测试文件的
/// `setUpAll` 里调用。
Future<void> loadExpressiveTestFontMetrics() async {
  if (_defaultFontMetricsLoaded) return;
  _defaultFontMetricsLoaded = true;
  final loader = FontLoader('Roboto');
  for (final weight in <String>['Regular', 'Medium', 'Bold']) {
    loader.addFont(
      rootBundle.load(
        'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_$weight.ttf',
      ),
    );
  }
  await loader.load();
}
