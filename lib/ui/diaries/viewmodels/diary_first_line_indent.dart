import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/widgets.dart';

import '../../../core/services/diary_typography.dart';

/// 首行缩进的 AppFlowy 属性键。
///
/// 与 Quill 时代不同（那时是渲染层用 WidgetSpan 垫，见 git 历史），AppFlowy
/// 时代把缩进记在块属性上：`data` 里带 `"first_line_indent": true` 的段落
/// 在渲染时首行缩进。属性由保存/排版逻辑写入，渲染层只读属性。
const String kFirstLineIndentAttribute = 'first_line_indent';

/// 只读正文的首行缩进：AppFlowy 没有“首行缩进”样式，所以缩进记在块属性上，
/// 渲染层读到属性后在首行垫出定宽空白，不动存档的文字内容。
///
/// 做法：自定义段落块组件在构建 TextSpan 时，若节点带
/// [kFirstLineIndentAttribute] 且为普通段落，在第一个文字 span 前插一个
/// 定宽的 WidgetSpan。RichText 换行时只有首行带这个占位，后续折行回到
/// 左缘——正好是首行缩进；原文一个字没改。
///
/// 只缩进普通段落：标题、列表（含待办）、引用、代码块不缩；居中 / 右对齐
/// 的段落不缩（缩进会破坏对齐意图），两端对齐照常缩；行首已有空白
/// （用户手动空了格）的段落不重复缩。
///
/// 宽度：1 字 = 当前字号（1em），与 Word 导出（`w:firstLine`，同口径换算）
/// 对得上。0 表示关闭，调用方直接不写属性。
double diaryFirstLineIndentWidth(DiaryTypography typography) =>
    typography.firstLineIndent * typography.fontSize;

/// 判断一个 AppFlowy 段落节点是否应该应用首行缩进。
///
/// [node] 为段落节点；[typography] 为当前排版设置（首行缩进开关与字号）。
bool shouldApplyFirstLineIndent(Node node, DiaryTypography typography) {
  if (typography.firstLineIndent <= 0) return false;
  // 只有普通段落参与；标题、列表、引用、代码块等不缩。
  if (node.type != ParagraphBlockKeys.type) return false;
  // 块属性里显式关掉的不缩（预留）。
  if (node.attributes[kFirstLineIndentAttribute] == false) return false;
  // 对齐方式：居中 / 右对齐不缩，两端对齐照常缩。
  final align = node.attributes[blockComponentAlign] as String?;
  if (align == 'center' || align == 'right') return false;
  // 空段落或行首已有空白的不缩。
  final delta = node.delta;
  if (delta == null || delta.isEmpty) return false;
  final text = delta.toPlainText();
  if (text.isEmpty || text.trimLeft().length != text.length) return false;
  return true;
}

/// 为首行缩进构建前导占位 span。
///
/// 返回一个定宽 [WidgetSpan]，调用方把它插在段落 TextSpan 的 children 最前面。
InlineSpan buildFirstLineIndentLeading(double width, double fontSize) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: SizedBox(width: width, height: fontSize),
  );
}

/// 把首行缩进属性写进段落节点的 attributes（保存/排版时调用）。
///
/// [attributes] 为节点原有的 attributes，返回带缩进标记的新 map。
/// 缩进开关关闭时（width <= 0）移除标记。
Map<String, dynamic> withFirstLineIndentAttribute(
  Map<String, dynamic> attributes,
  double width,
) {
  final result = Map<String, dynamic>.from(attributes);
  if (width > 0) {
    result[kFirstLineIndentAttribute] = true;
  } else {
    result.remove(kFirstLineIndentAttribute);
  }
  return result;
}
