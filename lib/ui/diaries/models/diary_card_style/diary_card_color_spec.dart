part of 'diary_card_style.dart';

/// 卡片上一个颜色位（底色、渐变终点、描边、强调条、阴影、文字）的配置。
///
/// - [source] 为 theme 时沿用该颜色位原本的主题语义色；
/// - [strength] 是着色强度：底色与渐变为叠在卡片表面上的不透明度（1 即
///   纯色），描边、强调条与阴影为颜色本身的不透明度。文字颜色不使用强度。
@immutable
class DiaryCardColorSpec {
  const DiaryCardColorSpec({
    this.source = DiaryCardColorSource.theme,
    this.strength = 0.14,
  });

  final DiaryCardColorSource source;

  final double strength;

  /// 是否真正改变了外观。
  bool get isThemed => source == DiaryCardColorSource.theme;

  DiaryCardColorSpec copyWith({
    DiaryCardColorSource? source,
    double? strength,
  }) {
    return DiaryCardColorSpec(
      source: source ?? this.source,
      strength: strength ?? this.strength,
    );
  }

  static DiaryCardColorSpec _fromJson(
    Object? raw,
    DiaryCardColorSpec defaults,
  ) {
    final json = _map(raw);
    if (json == null) {
      return defaults;
    }
    return DiaryCardColorSpec(
      source: _enumByName(
        DiaryCardColorSource.values,
        json['source'],
        defaults.source,
      ),
      strength: _double(
        json['strength'],
        defaults.strength,
        DiaryCardStyleLimits.strength,
      ),
    );
  }

  Map<String, Object> _toJson(DiaryCardColorSpec defaults) {
    final json = <String, Object>{};
    _putEnum(json, 'source', source, defaults.source);
    _put(json, 'strength', strength, defaults.strength);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardColorSpec &&
        other.source == source &&
        other.strength == strength;
  }

  @override
  int get hashCode => Object.hash(source, strength);
}
