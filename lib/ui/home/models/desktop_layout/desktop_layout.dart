import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 首页区块的模块 id：题头 / 写点什么 / 快捷入口 / 最近记录。
///
/// 四个都是首页 v4 已有的区块；布局自定义只做这四个的显隐与排序，
/// 不新增区块种类（新增种类要改首页渲染，先不做）。
enum DesktopModuleId {
  header,
  writeButton,
  quickEntry,
  recent;

  static DesktopModuleId? fromName(String? name) {
    if (name == null) return null;
    for (final value in DesktopModuleId.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// 单个模块的配置：id + 是否显示。顺序由它在 [DesktopLayout.modules]
/// 列表里的位置决定。
@immutable
class DesktopModuleSpec {
  const DesktopModuleSpec({required this.id, this.visible = true});

  final DesktopModuleId id;
  final bool visible;

  factory DesktopModuleSpec.fromJson(Object? json) {
    final id = json is Map
        ? DesktopModuleId.fromName(json['id'] as String?)
        : null;
    return DesktopModuleSpec(
      id: id ?? DesktopModuleId.header,
      visible: json is Map && json['visible'] is bool
          ? json['visible'] as bool
          : true,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'id': id.name,
    'visible': visible,
  };

  DesktopModuleSpec copyWith({bool? visible}) =>
      DesktopModuleSpec(id: id, visible: visible ?? this.visible);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopModuleSpec &&
          other.id == id &&
          other.visible == visible;

  @override
  int get hashCode => Object.hash(id, visible);
}

/// 首页布局：四个区块的顺序 + 显隐。
///
/// 持久化为单个 JSON 键（`desktopLayoutRaw`）：
/// `{"v":1,"modules":[{"id":"header","visible":true},...]}`。放在一个键里，
/// 备份恢复与失败回滚都是原子的，也只需一个通知源。全为默认时编码为
/// null，由设置服务删除该键。
@immutable
class DesktopLayout {
  const DesktopLayout({this.modules = defaultModules});

  /// 默认布局：v4 的四部分顺序，全部显示。
  static const List<DesktopModuleSpec> defaultModules = <DesktopModuleSpec>[
    DesktopModuleSpec(id: DesktopModuleId.header),
    DesktopModuleSpec(id: DesktopModuleId.writeButton),
    DesktopModuleSpec(id: DesktopModuleId.quickEntry),
    DesktopModuleSpec(id: DesktopModuleId.recent),
  ];

  static const DesktopLayout defaults = DesktopLayout();
  static const int schemaVersion = 1;

  final List<DesktopModuleSpec> modules;

  /// 解析持久化的 JSON；null、空串或损坏时返回默认布局。各部分逐项容错：
  /// 认不出的 id 丢弃、重复的只留第一次出现、缺的模块按默认顺序补到末尾
  /// （以后加新区块时，旧布局自动带上）。
  factory DesktopLayout.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // 损坏的配置按默认布局展示，不能让首页布局偏好阻断启动。
      return defaults;
    }
    return DesktopLayout.fromJson(decoded);
  }

  factory DesktopLayout.fromJson(Object? json) {
    if (json is! Map) {
      return defaults;
    }
    final rawModules = json['modules'];
    if (rawModules is! List) {
      return defaults;
    }
    final seen = <DesktopModuleId>{};
    final modules = <DesktopModuleSpec>[];
    for (final item in rawModules) {
      // 非法 id 直接丢弃（不回退成 header，避免把坏数据洗成正常模块）。
      final rawId = item is Map ? item['id'] : null;
      final id = DesktopModuleId.fromName(rawId as String?);
      if (id == null || !seen.add(id)) {
        continue;
      }
      final visible = item is Map && item['visible'] is bool
          ? item['visible'] as bool
          : true;
      modules.add(DesktopModuleSpec(id: id, visible: visible));
    }
    // 缺的模块按默认顺序补到末尾，默认显示。
    for (final def in defaultModules) {
      if (seen.add(def.id)) {
        modules.add(def);
      }
    }
    if (modules.isEmpty) {
      return defaults;
    }
    return DesktopLayout(modules: List.unmodifiable(modules));
  }

  Map<String, Object> toJson() => <String, Object>{
    'v': schemaVersion,
    'modules': <Object>[for (final m in modules) m.toJson()],
  };

  bool get isDefault {
    if (modules.length != defaultModules.length) return false;
    for (var i = 0; i < modules.length; i++) {
      if (modules[i] != defaultModules[i]) return false;
    }
    return true;
  }

  /// 默认布局编码为 null（删除键）。
  String? encode() {
    if (isDefault) return null;
    return jsonEncode(toJson());
  }

  /// 按顺序列出显示中的模块 id（渲染用）。
  List<DesktopModuleId> get visibleModuleIds => <DesktopModuleId>[
    for (final m in modules)
      if (m.visible) m.id,
  ];

  DesktopLayout withVisibility(DesktopModuleId id, bool visible) {
    return DesktopLayout(
      modules: <DesktopModuleSpec>[
        for (final m in modules)
          m.id == id ? m.copyWith(visible: visible) : m,
      ],
    );
  }

  /// 把 [id] 移动到 [newIndex]（按 modules 列表计，含隐藏的模块）。
  DesktopLayout moved(DesktopModuleId id, int newIndex) {
    final list = modules.toList();
    final oldIndex = list.indexWhere((m) => m.id == id);
    if (oldIndex < 0) return this;
    final clamped = newIndex.clamp(0, list.length - 1);
    final movedSpec = list.removeAt(oldIndex);
    list.insert(clamped, movedSpec);
    return DesktopLayout(modules: List.unmodifiable(list));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopLayout && listEquals(other.modules, modules);

  @override
  int get hashCode => Object.hashAll(modules);
}
