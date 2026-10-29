// 功能管理开关（设置 → 功能管理）。
//
// 职责：描述用户可整体关闭的功能——桌面 Tab、日记本、纪念日、
// 日记模板、时间胶囊——是否开启；默认全部开启。关闭只是在各处隐藏入口与
// 展示，数据一律保留，重新开启即恢复原样。
//
// 探索与日历已经并进桌面页（首页），不再占底栏 Tab，这里也不再有
// 这两项开关；纪念日不再依附日历，只看自己的开关。
//
// 存储：单个 JSON 设置键 `app.settings.app_features`（经
// `SettingsService.setAppFeaturesRaw`），逐字段容错解析，随完整备份导出，
// 导入失败时随设置快照回滚。全部为默认值时不落盘（[encode] 返回 null）。

import 'dart:convert';

/// 各功能是否开启。不可变；修改经 [copyWith] 得到新值后保存。
class AppFeatures {
  const AppFeatures({
    this.desktop = true,
    this.notebooks = true,
    this.anniversaries = true,
    this.templates = true,
    this.timeCapsules = true,
  });

  /// 全部开启：从未设置、读不出或恢复默认时都是它。
  static const AppFeatures defaults = AppFeatures();

  /// 桌面 Tab。
  final bool desktop;

  /// 日记本。
  final bool notebooks;

  /// 纪念日的开关值；界面判断是否可用请读 [anniversariesEnabled]。
  final bool anniversaries;

  /// 日记模板。
  final bool templates;

  /// 时间胶囊。
  final bool timeCapsules;

  /// 纪念日是否可用：只看自己的开关（以前依附日历，日历并进首页后
  /// 不再有日历开关）。界面一律读这个 getter，不直接读 [anniversaries]。
  bool get anniversariesEnabled => anniversaries;

  static const _keyDesktop = 'desktop';
  static const _keyNotebooks = 'notebooks';
  static const _keyAnniversaries = 'anniversaries';
  static const _keyTemplates = 'templates';
  static const _keyTimeCapsules = 'timeCapsules';

  /// 解析设置原文。空值、坏 JSON 或不是对象时回到 [defaults]；每个字段
  /// 单独读取，类型不对只让这一项回到默认，认不出的键忽略——这样新旧版本
  /// 互相导入备份时，不会因为一项坏值把用户关掉的其他功能全部重新打开。
  static AppFeatures decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return defaults;
    final Object? node;
    try {
      node = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (node is! Map) return defaults;
    final map = node;
    bool read(String key, bool fallback) {
      final value = map[key];
      return value is bool ? value : fallback;
    }

    return AppFeatures(
      desktop: read(_keyDesktop, defaults.desktop),
      notebooks: read(_keyNotebooks, defaults.notebooks),
      anniversaries: read(_keyAnniversaries, defaults.anniversaries),
      templates: read(_keyTemplates, defaults.templates),
      timeCapsules: read(_keyTimeCapsules, defaults.timeCapsules),
    );
  }

  /// 编码为设置原文；等于默认值时返回 null，让设置层移除该键而不是存一份
  /// 与默认相同的 JSON。
  String? encode() {
    if (this == defaults) return null;
    return jsonEncode(<String, bool>{
      _keyDesktop: desktop,
      _keyNotebooks: notebooks,
      _keyAnniversaries: anniversaries,
      _keyTemplates: templates,
      _keyTimeCapsules: timeCapsules,
    });
  }

  AppFeatures copyWith({
    bool? desktop,
    bool? notebooks,
    bool? anniversaries,
    bool? templates,
    bool? timeCapsules,
  }) {
    return AppFeatures(
      desktop: desktop ?? this.desktop,
      notebooks: notebooks ?? this.notebooks,
      anniversaries: anniversaries ?? this.anniversaries,
      templates: templates ?? this.templates,
      timeCapsules: timeCapsules ?? this.timeCapsules,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppFeatures &&
      other.desktop == desktop &&
      other.notebooks == notebooks &&
      other.anniversaries == anniversaries &&
      other.templates == templates &&
      other.timeCapsules == timeCapsules;

  @override
  int get hashCode => Object.hash(
    desktop,
    notebooks,
    anniversaries,
    templates,
    timeCapsules,
  );

  @override
  String toString() =>
      'AppFeatures(desktop: $desktop, '
      'notebooks: $notebooks, anniversaries: $anniversaries, '
      'templates: $templates, timeCapsules: $timeCapsules)';
}
