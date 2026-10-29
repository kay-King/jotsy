import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../core/services/diary_typography.dart';

/// 只读正文的首行缩进：flutter_quill 没有“首行缩进”样式（它的 `indent`
/// 是整段左缩进），也不能在编辑器里为此加自定义属性（光标与撤销有风险，
/// 留后做），所以缩进只在渲染层垫出来，不动存档 Delta。
///
/// 做法：包住 Quill 的 `textSpanBuilder`，在普通段落第一个文字叶子的 span
/// 前面插一个定宽 [WidgetSpan]。RichText 换行时只有首行带这个占位，后续
/// 折行回到左缘——正好是首行缩进；原文一个字没改，复制、待办勾选、看图
/// 仍走原来的控制器与 span（链接的 recognizer 留在原 span 上）。
///
/// 只缩进普通段落：标题、列表（含待办）、引用、代码块、已有 Quill 缩进的
/// 行不缩；居中 / 右对齐的段落不缩（缩进会破坏对齐意图），两端对齐照常
/// 缩；行首已有空白（用户手动空了格）的段落不重复缩；图片打头的行（首
/// 个叶子不是文字）也不缩。
///
/// 宽度：1 字 = 当前字号（1em），与 Word 导出（`w:firstLine`，同口径换算）
/// 对得上。0 表示关闭，调用方直接不用包装器。
double diaryFirstLineIndentWidth(DiaryTypography typography) =>
    typography.firstLineIndent * typography.fontSize;

/// [base] 之外、首行再垫 [width] 逻辑像素的 span 构建器。
quill.TextSpanBuilder buildFirstLineIndentSpanBuilder(
  quill.TextSpanBuilder base,
  double width,
) {
  assert(width > 0);
  return (
    BuildContext context,
    quill.Node node,
    int nodeOffset,
    String text,
    TextStyle? style,
    GestureRecognizer? recognizer,
  ) {
    final span = base(context, node, nodeOffset, text, style, recognizer);
    if (!_isFirstLineIndentTarget(node, nodeOffset, text) ||
        span is! TextSpan) {
      return span;
    }
    return TextSpan(
      style: span.style,
      children: <InlineSpan>[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: width,
            height: style?.fontSize ?? 16,
          ),
        ),
        span,
      ],
    );
  };
}

bool _isFirstLineIndentTarget(
  quill.Node node,
  int nodeOffset,
  String text,
) {
  // 组字切片（nodeOffset > 0）与空文本不垫；已手动空过格的不重复垫。
  if (nodeOffset != 0 || text.isEmpty || text.trimLeft().length != text.length) {
    return false;
  }
  if (node is! quill.QuillText) {
    return false;
  }
  final line = node.parent;
  if (line is! quill.Line || !node.isFirst) {
    return false;
  }
  // 行自身的样式与父块的样式都要看：标题 / 列表 / 引用 / 代码块 / 缩进
  // 可能挂在任意一处；普通段落两处都干净。
  final block = line.parent;
  final styles = <quill.Style>[
    line.style,
    if (block is quill.Block) block.style,
  ];
  for (final style in styles) {
    final attributes = style.attributes;
    for (final key in <String>[
      quill.Attribute.header.key,
      quill.Attribute.list.key,
      quill.Attribute.codeBlock.key,
      quill.Attribute.blockQuote.key,
      quill.Attribute.indent.key,
    ]) {
      if (attributes.containsKey(key)) {
        return false;
      }
    }
    final align = attributes[quill.Attribute.align.key]?.value;
    if (align == quill.Attribute.centerAlignment.value ||
        align == quill.Attribute.rightAlignment.value) {
      return false;
    }
  }
  return true;
}
