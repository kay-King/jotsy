import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/diary_text_colors.dart';
import 'diary_export_blocks.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_media.dart';
import 'diary_export_pdf_inline.dart';
import 'diary_export_pdf_text_effects.dart';

/// AppFlowy Document 直接渲染为 PDF 组件，不经过 Quill Delta。
///
/// 取代 flutter_quill_to_pdf：逐节点遍历 Document，把每种块类型转成
/// pdf 库的 Widget。行内样式经 [ExportInline] 复用既有的
/// [buildDiaryPdfInline]，颜色已在解析时压平到纸面上。
///
/// 支持的块类型：paragraph、heading、bulleted_list、numbered_list、
/// todo_list、quote、code、image、video、audio、attachment、divider，
/// 以及前瞻的 table、callout、toggle_list（编辑器尚未生成，遇到时合理降级）。
class DiaryPdfAppFlowyRenderer {
  const DiaryPdfAppFlowyRenderer._();

  /// 把一篇日记的 AppFlowy Document 渲染为 PDF 组件列表。
  ///
  /// [images] 为已收集的图片字节（与虚拟地址一一对应），渲染图片块时
  /// 按序号取用；缺失的图片跳过。没有可见内容时返回空列表。
  /// [imageIndex] 为图片 URL 到 [images] 下标的映射，由 prepare 阶段建立。
  static List<pw.Widget> render(
    af.Document document, {
    required pw.ThemeData theme,
    required DiaryPdfTextEffects effects,
    required List<Uint8List> images,
    required Map<String, int> imageIndex,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required bool includeImages,
    DiaryExportCodeTheme? code,
  }) {
    final context = _RenderContext(
      theme: theme,
      effects: effects,
      images: images,
      imageIndex: imageIndex,
      labels: labels,
      media: media,
      includeImages: includeImages,
      code: code,
      bodyFontSize: theme.defaultTextStyle.fontSize ?? 12,
    );
    final widgets = <pw.Widget>[];
    final nodes = document.root.children;
    var orderedCounter = 0;
    String? lastListType;

    for (final node in nodes) {
      // 有序列表的编号在连续的同类型列表内递增，遇到其他块重置。
      final listType = _listTypeOf(node);
      if (listType == 'numbered_list') {
        orderedCounter = (lastListType == 'numbered_list')
            ? orderedCounter + 1
            : 1;
      } else {
        orderedCounter = 0;
      }
      lastListType = listType;

      final widget = _renderNode(
        node,
        context,
        indent: 0,
        orderedNumber: orderedCounter,
      );
      if (widget != null) {
        widgets.add(widget);
      }
    }
    return widgets;
  }

  static String? _listTypeOf(af.Node node) {
    return switch (node.type) {
      'bulleted_list' => 'bulleted_list',
      'numbered_list' => 'numbered_list',
      'todo_list' => 'todo_list',
      _ => null,
    };
  }

  static pw.Widget? _renderNode(
    af.Node node,
    _RenderContext context, {
    required int indent,
    int orderedNumber = 0,
  }) {
    return switch (node.type) {
      'paragraph' => _paragraph(node, context, indent: indent),
      'heading' => _heading(node, context, indent: indent),
      'bulleted_list' => _bulletedList(node, context, indent: indent),
      'numbered_list' => _numberedList(
        node,
        context,
        indent: indent,
        number: orderedNumber,
      ),
      'todo_list' => _todoList(node, context, indent: indent),
      'quote' => _quote(node, context, indent: indent),
      'code' => _codeBlock(node, context),
      'image' => _image(node, context),
      'divider' => _divider(),
      'video' || 'audio' || 'attachment' => _mediaLabel(node, context),
      'table' => _table(node, context),
      'callout' => _callout(node, context, indent: indent),
      'toggle_list' => _toggleList(node, context, indent: indent),
      // 认不出的块：尝试渲染文字内容，避免丢字。
      _ => _fallback(node, context, indent: indent),
    };
  }

  /// 把 AppFlowy Delta 的行内属性转为 ExportInline（键名映射）。
  ///
  /// 颜色先按纸面压平成不透明色（pdf 库填色时只写 RGB、丢掉透明度）。
  static List<ExportInline> _inlinesFromDelta(af.Delta? delta) {
    if (delta == null) return const <ExportInline>[];
    final inlines = <ExportInline>[];
    for (final op in delta.toList()) {
      if (op is! af.TextInsert) continue;
      final text = op.text;
      if (text.isEmpty) continue;
      final attrs = op.attributes;
      final color = _flattenColor(
        _colorOf(attrs?['font_color']),
        _colorOf(attrs?['bg_color']),
      );
      inlines.add(
        ExportInline(
          text,
          bold: attrs?['bold'] == true,
          italic: attrs?['italic'] == true,
          underline: attrs?['underline'] == true,
          strike: attrs?['strikethrough'] == true,
          code: attrs?['code'] == true,
          link: _linkOf(attrs?['href']),
          color: color.text,
          background: color.background,
          size: _sizeOf(attrs?['size']),
        ),
      );
    }
    return inlines;
  }

  /// 把文字色 / 背景色压平成叠在白纸上的不透明色。
  static ({Color? text, Color? background}) _flattenColor(
    Color? text,
    Color? background,
  ) {
    if (text == null && background == null) {
      return (text: null, background: null);
    }
    final flat = flattenDiaryColors(
      text: text,
      background: background,
      paper: const Color(0xFFFFFFFF),
    );
    return (text: flat.text, background: flat.background);
  }

  static String? _linkOf(Object? value) {
    if (value is! String) return null;
    final url = value.trim();
    return url.isEmpty ? null : url;
  }

  static Color? _colorOf(Object? value) {
    if (value is! String) return null;
    return parseDiaryColorValue(value);
  }

  static String? _sizeOf(Object? value) {
    if (value is String || value is num) return value.toString();
    return null;
  }

  static pw.TextAlign _textAlignOf(af.Node node) {
    return switch (node.attributes['align']) {
      'center' => pw.TextAlign.center,
      'right' => pw.TextAlign.right,
      'justify' => pw.TextAlign.justify,
      _ => pw.TextAlign.left,
    };
  }

  static pw.Widget _richText(
    af.Node node,
    _RenderContext context, {
    pw.TextStyle? style,
    pw.TextAlign? align,
  }) {
    final inlines = _inlinesFromDelta(node.delta);
    final base = style ?? context.theme.defaultTextStyle;
    return pw.RichText(
      textAlign: align ?? _textAlignOf(node),
      softWrap: true,
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(
        children: <pw.InlineSpan>[
          for (final run in inlines)
            buildDiaryPdfInline(
              run,
              base,
              effects: context.effects,
              bodyFontSize: context.bodyFontSize,
            ),
        ],
      ),
    );
  }

  static pw.Widget _paragraph(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    final childWidgets = <pw.Widget>[
      pw.Padding(
        padding: pw.EdgeInsets.only(left: indent * 12.0, bottom: 4),
        child: _richText(node, context),
      ),
    ];
    // 子块缩进显示在父块之下。
    for (final child in node.children) {
      final widget = _renderNode(child, context, indent: indent + 1);
      if (widget != null) childWidgets.add(widget);
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: childWidgets,
    );
  }

  static pw.Widget _heading(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    final level = (node.attributes['level'] as num?)?.toInt().clamp(1, 6) ?? 1;
    final base = switch (level) {
      1 => context.theme.header1,
      2 => context.theme.header2,
      3 => context.theme.header3,
      4 => context.theme.header4,
      5 => context.theme.header5,
      _ => context.theme.defaultTextStyle.copyWith(fontSize: 15),
    };
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 12.0, top: 8, bottom: 4),
      child: _richText(node, context, style: base),
    );
  }

  static pw.Widget _bulletedList(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 12.0, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 16,
            child: pw.Text(
              '•',
              style: context.theme.defaultTextStyle.copyWith(fontSize: 12),
            ),
          ),
          pw.Expanded(child: _richText(node, context)),
        ],
      ),
    );
  }

  static pw.Widget _numberedList(
    af.Node node,
    _RenderContext context, {
    required int indent,
    required int number,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 12.0, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 24,
            child: pw.Text(
              '$number.',
              style: context.theme.defaultTextStyle.copyWith(fontSize: 12),
            ),
          ),
          pw.Expanded(child: _richText(node, context)),
        ],
      ),
    );
  }

  static pw.Widget _todoList(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    final checked = node.attributes['checked'] == true;
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 12.0, bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 20,
            child: pw.Container(
              width: 12,
              height: 12,
              margin: const pw.EdgeInsets.only(top: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600, width: 1),
                borderRadius: pw.BorderRadius.circular(2),
                color: checked ? PdfColors.blue : null,
              ),
              child: checked
                  ? pw.Center(
                      child: pw.Text(
                        '✓',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          pw.Expanded(child: _richText(node, context)),
        ],
      ),
    );
  }

  static pw.Widget _quote(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 12.0 + 8, bottom: 4),
      child: pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.grey400, width: 2),
          ),
        ),
        padding: const pw.EdgeInsets.only(left: 8),
        child: _richText(
          node,
          context,
          style: context.theme.defaultTextStyle.copyWith(
            color: PdfColors.grey700,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ),
    );
  }

  static pw.Widget _codeBlock(af.Node node, _RenderContext context) {
    final delta = node.delta;
    final code = delta?.toPlainText() ?? '';
    if (code.trim().isEmpty) return pw.SizedBox();

    final palette = context.code?.paper;
    final background = palette != null
        ? PdfColor.fromInt(palette.background.toARGB32())
        : const PdfColor.fromInt(0xFFF5F5F5);
    final foreground = palette != null
        ? PdfColor.fromInt(palette.foreground.toARGB32())
        : PdfColors.black;

    // 代码块按行拆分，每行一个 Text，避免长代码的换行问题。
    final lines = code.split('\n');
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            for (final line in lines)
              pw.Text(
                line.isEmpty ? ' ' : line,
                style: pw.TextStyle(
                  font: context.effects.bundled,
                  fontSize: 10,
                  color: foreground,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static pw.Widget? _image(af.Node node, _RenderContext context) {
    if (!context.includeImages) return null;
    final url = node.attributes['url']?.toString();
    if (url == null || url.isEmpty) return null;

    final index = context.imageIndex[url];
    if (index == null || index >= context.images.length) return null;

    final bytes = context.images[index];
    final info = ExportImageInfo.read(bytes);
    if (info == null) return null;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
      child: pw.Center(
        child: pw.Image(
          pw.MemoryImage(bytes),
          // 限制最大宽度为页面可用宽度，高度按比例。
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }

  static pw.Widget _divider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Divider(color: PdfColors.grey400, thickness: 0.5),
    );
  }

  static pw.Widget _mediaLabel(af.Node node, _RenderContext context) {
    final labels = context.labels;
    final text = switch (node.type) {
      'video' => '[${labels.video}]',
      'audio' => '[${labels.audio}]',
      'attachment' => '[${labels.attachment}]',
      _ => '[${labels.image}]',
    };
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: context.theme.defaultTextStyle.copyWith(
          color: PdfColors.grey600,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  /// 表格：按行列组织单元格，每个单元格渲染为文字。
  static pw.Widget? _table(af.Node node, _RenderContext context) {
    final colsLen = node.attributes['colsLen'] as int?;
    final rowsLen = node.attributes['rowsLen'] as int?;
    if (colsLen == null || rowsLen == null || colsLen <= 0 || rowsLen <= 0) {
      return null;
    }
    if (node.children.length != colsLen * rowsLen) {
      // 结构不完整时降级为纯文字，避免丢字。
      return _fallback(node, context, indent: 0);
    }

    // 按行列位置组织单元格。
    final cells = List.generate(
      rowsLen,
      (_) => List<af.Node?>.filled(colsLen, null),
    );
    for (final child in node.children) {
      final row = child.attributes['rowPosition'] as int?;
      final col = child.attributes['colPosition'] as int?;
      if (row != null && col != null && row < rowsLen && col < colsLen) {
        cells[row][col] = child;
      }
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        children: <pw.TableRow>[
          for (var r = 0; r < rowsLen; r++)
            pw.TableRow(
              children: <pw.Widget>[
                for (var c = 0; c < colsLen; c++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: cells[r][c] == null
                        ? pw.SizedBox()
                        : _richText(cells[r][c]!, context),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// 提示块：带底色的色块，图标用文字 emoji（PDF 字体无 emoji 时显示方框，
  /// 故只用底色区分）。
  static pw.Widget _callout(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent * 12.0, top: 4, bottom: 4),
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF0F7FF),
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(
            color: const PdfColor.fromInt(0xFFD0E3FF),
            width: 0.5,
          ),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: _richText(node, context),
      ),
    );
  }

  /// 折叠块：标题行 + 展开的内容（PDF 中全部展开，不丢字）。
  static pw.Widget _toggleList(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    final widgets = <pw.Widget>[
      pw.Padding(
        padding: pw.EdgeInsets.only(left: indent * 12.0, bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.SizedBox(
              width: 16,
              child: pw.Text(
                '▸',
                style: context.theme.defaultTextStyle.copyWith(fontSize: 12),
              ),
            ),
            pw.Expanded(
              child: _richText(
                node,
                context,
                style: context.theme.defaultTextStyle.copyWith(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
    // 子块（折叠的内容）在 PDF 中全部展开。
    for (final child in node.children) {
      final widget = _renderNode(child, context, indent: indent + 1);
      if (widget != null) widgets.add(widget);
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// 认不出的块：渲染其文字内容，避免丢字。
  static pw.Widget? _fallback(
    af.Node node,
    _RenderContext context, {
    required int indent,
  }) {
    final text = node.delta?.toPlainText().trim() ?? '';
    if (text.isEmpty && node.children.isEmpty) return null;

    final widgets = <pw.Widget>[];
    if (text.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: indent * 12.0, bottom: 4),
          child: _richText(node, context),
        ),
      );
    }
    for (final child in node.children) {
      final widget = _renderNode(child, context, indent: indent + 1);
      if (widget != null) widgets.add(widget);
    }
    if (widgets.isEmpty) return null;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// 渲染时的共享上下文，避免参数层层传递。
class _RenderContext {
  const _RenderContext({
    required this.theme,
    required this.effects,
    required this.images,
    required this.imageIndex,
    required this.labels,
    required this.media,
    required this.includeImages,
    required this.bodyFontSize,
    this.code,
  });

  final pw.ThemeData theme;
  final DiaryPdfTextEffects effects;
  final List<Uint8List> images;

  /// 图片 URL 到 [images] 下标的映射。
  final Map<String, int> imageIndex;
  final DiaryExportLabels labels;
  final DiaryExportMediaLibrary media;
  final bool includeImages;
  final double bodyFontSize;
  final DiaryExportCodeTheme? code;
}
