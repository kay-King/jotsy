import '../../../diaries/models/style_library/style_code.dart';
import 'desktop_layout.dart';

export '../../../diaries/models/style_library/style_code.dart'
    show StyleCodeResult, StyleCodeStatus;

/// 首页布局码：`jotsy-home:v1:<base64url(JSON)>`，格式与解析规则见
/// [StyleCodeFormat]。只携带四个区块的顺序与显隐。
abstract final class DesktopLayoutCode {
  static const String scheme = 'jotsy-home';
  static const int version = 1;

  static final StyleCodeFormat<DesktopLayout> format =
      StyleCodeFormat<DesktopLayout>(
        scheme: scheme,
        version: version,
        fromJson: DesktopLayout.fromJson,
        toJson: (DesktopLayout layout) => layout.toJson(),
      );

  static String encode(DesktopLayout layout, {String? name}) =>
      format.encode(layout, name: name);

  static StyleCodeResult<DesktopLayout> decode(String? text) =>
      format.decode(text);
}
