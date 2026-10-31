part of 'diary_toggle_block.dart';

// 折叠块的只读预览：标题行 + 简化的子块文字，点箭头只改本地展开状态。

/// 预览页用的折叠块渲染（只读）。
///
/// 点箭头只翻本地展开状态，不写文档（预览页没有 EditorState）；初值跟文档
/// 的 `collapsed` 属性。
class DiaryToggleBlockPreview extends StatefulWidget {
  const DiaryToggleBlockPreview({
    super.key,
    required this.node,
    required this.textStyle,
  });

  final Node node;
  final TextStyle textStyle;

  @override
  State<DiaryToggleBlockPreview> createState() =>
      _DiaryToggleBlockPreviewState();
}

class _DiaryToggleBlockPreviewState extends State<DiaryToggleBlockPreview> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.node.attributes[kDiaryToggleCollapsedKey] != true;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.textStyle;
    final indent = textStyle.fontSize ?? 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ToggleArrow(
              collapsed: !_expanded,
              onTap: () => setState(() => _expanded = !_expanded),
              height: indent * (textStyle.height ?? 1.0),
            ),
            Expanded(
              child: RichText(
                text: _toggleDeltaSpan(widget.node.delta, textStyle),
              ),
            ),
          ],
        ),
        // 子块显隐走 AnimatedSize：时长取 fast 档；减少动画时用
        // durationNonZero（1ms），避免 AnimatedSize 在 0 时长下于
        // performLayout 里同步 forward 触发 debug 断言。
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.fast,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _childWidgets(widget.node, textStyle, indent),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 子块简化渲染：每块的 delta 转 TextSpan 纵向排列，每级缩进一个正文字号。
///
/// 只取文字（加粗/斜体/下划线/删除线/颜色/字号档位）；图片等无 delta 的块
/// 不占位，但其子块的文字照常递归渲染，避免丢内容。
List<Widget> _childWidgets(Node parent, TextStyle textStyle, double indent) {
  return [
    for (final child in parent.children)
      Padding(
        padding: EdgeInsets.only(left: indent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (child.delta != null)
              RichText(text: _toggleDeltaSpan(child.delta, textStyle)),
            ..._childWidgets(child, textStyle, indent),
          ],
        ),
      ),
  ];
}

/// Delta → TextSpan（简化版）：只处理正文常用的行内格式。
TextSpan _toggleDeltaSpan(Delta? delta, TextStyle base) {
  final children = <InlineSpan>[];
  if (delta != null) {
    for (final op in delta) {
      if (op is! TextInsert) continue;
      children.add(_toggleOpSpan(op, base.fontSize ?? 16.0));
    }
  }
  if (children.isEmpty) {
    // 空标题/空段落也要占一行高度，否则会被压掉。
    return TextSpan(text: ' ', style: base);
  }
  return TextSpan(style: base, children: children);
}

TextSpan _toggleOpSpan(TextInsert op, double bodyFontSize) {
  final attributes = op.attributes ?? const <String, dynamic>{};
  var style = const TextStyle();
  if (attributes[kDiaryInlineBold] == true) {
    style = style.copyWith(fontWeight: FontWeight.bold);
  }
  if (attributes[kDiaryInlineItalic] == true) {
    style = style.copyWith(fontStyle: FontStyle.italic);
  }
  final decorations = <TextDecoration>[
    if (attributes[kDiaryInlineUnderline] == true) TextDecoration.underline,
    if (attributes[kDiaryInlineStrikethrough] == true)
      TextDecoration.lineThrough,
  ];
  if (decorations.isNotEmpty) {
    style = style.copyWith(decoration: TextDecoration.combine(decorations));
  }
  final fontColor = _parseDiaryColor(attributes[kDiaryInlineTextColor]);
  if (fontColor != null) {
    style = style.copyWith(color: fontColor);
  }
  final backgroundColor = _parseDiaryColor(
    attributes[kDiaryInlineBackgroundColor],
  );
  if (backgroundColor != null) {
    style = style.copyWith(backgroundColor: backgroundColor);
  }
  final fontSize = _toggleInlineFontSize(
    attributes[kDiaryInlineSize],
    bodyFontSize,
  );
  if (fontSize != null) {
    style = style.copyWith(fontSize: fontSize);
  }
  return TextSpan(text: op.text, style: style);
}

/// `#AARRGGBB` → Color；非法值返回 null（忽略），与预览页主渲染同口径。
Color? _parseDiaryColor(Object? value) {
  if (value is! String) return null;
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final intValue = int.tryParse(hex, radix: 16);
  if (intValue == null) return null;
  return Color(intValue);
}

/// 行内字号：small/large/huge 三档按正文字号缩放，数字按绝对字号
/// （与预览页主渲染同口径）。
double? _toggleInlineFontSize(Object? value, double bodyFontSize) {
  return switch (value) {
    'small' => bodyFontSize * 0.85,
    'large' => bodyFontSize * 1.25,
    'huge' => bodyFontSize * 1.5,
    num _ => value.toDouble(),
    _ => null,
  };
}
