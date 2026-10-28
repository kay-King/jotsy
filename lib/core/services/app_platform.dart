import 'package:flutter/foundation.dart';

/// 最小平台判断（仅供侧滑归档等少数按平台区分的开关使用）。
///
/// 本 fork 目前只做移动端，没有上游的桌面布局与桌面能力体系，所以这里不照搬
/// 上游 `AppPlatform` 的全部能力开关，只保留 [isDesktop]：由
/// [defaultTargetPlatform] 推出，widget 测试可用
/// `debugDefaultTargetPlatformOverride` 切换验证桌面分支。
abstract final class AppPlatform {
  /// 桌面（Linux / Windows / macOS）。
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
