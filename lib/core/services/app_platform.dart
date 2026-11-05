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

  /// 移动端（Android / iOS）。
  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Android。
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// macOS。
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  /// 是否支持把文字交给系统分享面板（手机）。
  static bool get supportsTextShare => isMobile;

  /// 是否支持其他应用的文字处理动作（Android `ACTION_PROCESS_TEXT`）。
  static bool get supportsProcessText => isAndroid;

  /// 正文里直接拍照 / 录像：只有 Android 原生通道（交给系统相机应用，
  /// `diary_camera_capture_service.dart`）。桌面没有可调用的相机应用，iOS
  /// 没有接这条通道，那里的图片 / 视频按钮仍直接打开选择器。
  static bool get supportsCameraCapture => isAndroid;
}
