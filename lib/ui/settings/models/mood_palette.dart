import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 心情色板：10 个心情槽位各自的符号与颜色。
///
/// 持久化为单个 JSON 键（`app.settings.mood_palette`）：
/// `{"v":1,"symbols":[…],"colors":["#FF…",…]}`。全为默认时编码为 null，由
/// 设置服务删除该键。解码逐字段容错：坏掉的符号/颜色逐个回退到默认值，
/// 绝不因单个脏字段丢掉整套配置。
///
/// - 符号顺序从低落到高兴，与旧版 `mood_options` 键一致；旧键只在迁移时
///   读一次（见 [SettingsService.moodPalette]），之后不再使用；
/// - 颜色默认从靛紫、蓝、青、绿一路暖到橙、珊瑚与玫红；
/// - 年视图心情像素与探索页心情图表继续用 [MoodBandPalette]，不受这里影响。
@immutable
class MoodPalette {
  const MoodPalette._(this.symbols, this.colors);

  /// 归一化构造：符号逐个 trim、空位回退默认符号；颜色逐个解析、坏值回退
  /// 默认颜色；数量不足 10 按默认补齐，多余的丢弃。
  factory MoodPalette({List<String>? symbols, List<int>? colors}) {
    return MoodPalette._(
      List<String>.unmodifiable(_normalizeSymbols(symbols)),
      List<int>.unmodifiable(_normalizeColors(colors)),
    );
  }

  /// 10 个槽位。
  static const int slotCount = 10;

  static const int schemaVersion = 1;

  /// 默认符号（从低落到高兴）。
  static const List<String> defaultSymbols = <String>[
    '😭',
    '😢',
    '😞',
    '😕',
    '😐',
    '🙂',
    '😊',
    '😄',
    '😀',
    '🤩',
  ];

  /// 默认颜色：靛紫、蓝、青、绿一路暖到橙、珊瑚、玫红（Material 400 色阶）。
  static const List<int> defaultColors = <int>[
    0xFF5C6BC0, // 靛紫
    0xFF42A5F5, // 蓝
    0xFF26C6DA, // 青
    0xFF66BB6A, // 绿
    0xFF9CCC65, // 浅绿
    0xFFD4E157, // 柠檬
    0xFFFFCA28, // 琥珀
    0xFFFFA726, // 橙
    0xFFFF7043, // 珊瑚
    0xFFEC407A, // 玫红
  ];

  static const MoodPalette defaults = MoodPalette._(
    defaultSymbols,
    defaultColors,
  );

  /// 解析持久化的 JSON；null、空串、损坏或结构不对时返回默认配置。
  /// 各字段逐项容错，见类文档。
  factory MoodPalette.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return defaults;
    }
    if (decoded is! Map) {
      return defaults;
    }
    return MoodPalette(
      symbols: _symbolList(decoded['symbols']),
      colors: _colorList(decoded['colors']),
    );
  }

  final List<String> symbols;
  final List<int> colors;

  bool get isDefault => this == defaults;

  /// 默认配置编码为 null（删除键）。
  String? encode() {
    if (isDefault) {
      return null;
    }
    return jsonEncode(<String, Object>{
      'v': schemaVersion,
      'symbols': symbols,
      'colors': <String>[for (final color in colors) _toHex(color)],
    });
  }

  /// 第 [weight] 档（1~10）心情的颜色。
  Color colorForWeight(int weight) =>
      Color(colors[weight.clamp(1, slotCount) - 1]);

  /// 按符号找颜色；符号为空或不在 10 个槽位里时返回 null，
  /// 调用方回退到应用主题色。
  Color? colorForSymbol(String? symbol) {
    final normalized = symbol?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final index = symbols.indexOf(normalized);
    if (index < 0) {
      return null;
    }
    return Color(colors[index]);
  }

  MoodPalette withSymbol(int index, String symbol) {
    final next = List<String>.from(symbols);
    final clamped = index.clamp(0, slotCount - 1);
    final trimmed = symbol.trim();
    next[clamped] = trimmed.isEmpty ? defaultSymbols[clamped] : trimmed;
    return MoodPalette(symbols: next, colors: colors);
  }

  MoodPalette withColor(int index, Color color) {
    final next = List<int>.from(colors);
    next[index.clamp(0, slotCount - 1)] = color.toARGB32();
    return MoodPalette(symbols: symbols, colors: next);
  }

  static List<String> _normalizeSymbols(List<String>? symbols) {
    final result = List<String>.from(defaultSymbols);
    if (symbols == null) {
      return result;
    }
    for (var index = 0; index < slotCount; index += 1) {
      if (index >= symbols.length) {
        break;
      }
      final candidate = symbols[index].trim();
      if (candidate.isNotEmpty) {
        result[index] = candidate;
      }
    }
    return result;
  }

  static List<int> _normalizeColors(List<int>? colors) {
    final result = List<int>.from(defaultColors);
    if (colors == null) {
      return result;
    }
    for (var index = 0; index < slotCount; index += 1) {
      if (index >= colors.length) {
        break;
      }
      final candidate = colors[index];
      if (candidate >= 0 && candidate <= 0xFFFFFFFF) {
        result[index] = candidate;
      }
    }
    return result;
  }

  static List<String>? _symbolList(Object? raw) {
    if (raw is! List) {
      return null;
    }
    return <String>[for (final item in raw) item?.toString() ?? ''];
  }

  static List<int>? _colorList(Object? raw) {
    if (raw is! List) {
      return null;
    }
    final result = <int>[];
    for (final item in raw) {
      final parsed = _parseColor(item);
      // 坏值用 -1 占位，归一化时回退到默认颜色。
      result.add(parsed ?? -1);
    }
    return result;
  }

  static int? _parseColor(Object? raw) {
    if (raw is int) {
      return (raw >= 0 && raw <= 0xFFFFFFFF) ? raw : null;
    }
    if (raw is String) {
      var text = raw.trim();
      if (text.startsWith('#')) {
        text = text.substring(1);
      }
      if (text.length == 6) {
        text = 'FF$text';
      }
      if (text.length == 8) {
        final value = int.tryParse(text, radix: 16);
        if (value != null) {
          return value;
        }
      }
    }
    return null;
  }

  static String _toHex(int color) =>
      '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  @override
  bool operator ==(Object other) {
    return other is MoodPalette &&
        listEquals(other.symbols, symbols) &&
        listEquals(other.colors, colors);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(symbols), Object.hashAll(colors));
}
