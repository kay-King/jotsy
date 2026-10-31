import 'dart:math' as math;
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/content_codec.dart';
import '../../../core/services/font_file_info.dart';
import 'diary_export_book.dart';
import 'diary_export_code.dart';
import 'diary_export_entry.dart';
import 'diary_export_font.dart';
import 'diary_export_format.dart';
import 'diary_export_media.dart';
import 'diary_export_pdf_appflowy.dart';
import 'diary_export_pdf_text_effects.dart';

/// PDF 用的字体，生成时按实际字符做子集嵌入。字体文件各约 8MB 起，加载一次
/// 后由调用方复用。
///
/// - 默认为内置 HarmonyOS Sans SC 常规与粗体；
/// - 正文排版选了导入字体（[load] 给出 `bodyFont`）且 pdf 库能嵌入时，整份
///   文档（标题、信息行、正文、目录与页码）改用它。导入字体只有一个字重，
///   粗体也用它（正文经 [DiaryPdfTextEffects] 补粗），避免在同一段里混用
///   两种字形；
/// - [bundled] 始终是内置常规体：导入字体缺字时回落到它（如只含西文的字体
///   遇到中文），代码块也用它（应用内代码块同样不跟随正文字体）。
class DiaryPdfFonts {
  const DiaryPdfFonts(this.regular, this.bold, {pw.Font? bundled})
    : bundled = bundled ?? regular;

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font bundled;

  static Future<DiaryPdfFonts> load([DiaryExportFont? bodyFont]) async {
    const base = 'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC';
    // 依次加载：资源包可能返回 SynchronousFuture，交给 Future.wait 会在
    // 结果写入前就完成，得到空列表。
    final regular = pw.Font.ttf(await rootBundle.load('${base}_Regular.ttf'));
    final imported = bodyFont == null ? null : embeddable(bodyFont.bytes);
    if (imported != null) {
      // 用不到内置粗体，不再读入。
      return DiaryPdfFonts(imported, imported, bundled: regular);
    }
    final bold = pw.Font.ttf(await rootBundle.load('${base}_Bold.ttf'));
    return DiaryPdfFonts(regular, bold);
  }

  /// 导入字体能否交给 pdf 库：先取出 TrueType 字面（TTC 取第一个），再试
  /// 解析一遍。CFF 轮廓、缺表、没有 Unicode 字符映射或解析出错时返回 null，
  /// 整份文档回落内置字体——字体在排版途中才被解析，那时出错会让整次导出
  /// 失败。
  @visibleForTesting
  static pw.Font? embeddable(Uint8List bytes) {
    final face = extractTrueTypeFace(bytes);
    if (face == null) {
      return null;
    }
    final data = ByteData.sublistView(face);
    try {
      final parser = TtfParser(data);
      // 子集写出时空格的字形是直接取用的（没有就会抛出）。
      if (parser.glyphOffsets.isEmpty ||
          !parser.charToGlyphIndexMap.containsKey(0x20)) {
        return null;
      }
    } catch (_) {
      // 调试模式下是断言失败，发布模式下多为越界；都按无法嵌入处理。
      return null;
    }
    return pw.Font.ttf(data);
  }
}

/// PDF 写出器：多篇日记连续排版进一个 A4 文档，页脚为页码。
///
/// 正文由 [DiaryPdfAppFlowyRenderer] 直接把 AppFlowy Document 渲染为块级
/// 组件（标题、列表、引用、代码块、表格、提示块、折叠块等），再与自绘的
/// 抬头（标题、日期、信息行、标签、封面）拼进同一个 MultiPage，不再经过
/// Quill Delta。
///
/// 送进渲染器前先处理正文（[_prepareBody]）：
/// - 本地图片文件不存在时跳过，缺失的图片不进文档；
/// - 录音、视频、附件写成名称说明，远程地址保留链接；
/// - 没有可见内容的正文不渲染；
/// - pdf 库填色时丢掉透明度，半透明的背景色会印成不透明的原色——文字色与
///   背景色先按纸面压平成不透明色；
/// - 代码块给了配色（[DiaryExportCodeTheme]）时用配色的底色与文字色。
///
/// 心情 emoji 不写进 PDF：内置字体没有 emoji 字形，会印成方框。
///
/// 排版库生成文档时要同时持有全部图片；图片总量超过 [maxImageBytes] 时
/// 抛出 [DiaryExportTooLargeException]，请用户缩小范围或关闭图片，而不是
/// 让应用因内存不足被系统结束。
///
/// 导出成书（`book` 不为 null）时文档分三部分：扉页（单页：封面、书名、
/// 简介、统计行与导出日期，封面同样计入图片总量）、目录、正文（每章另起
/// 一页，以章节标题开头）。章节与各篇标题同时是 PDF 书签与命名目标，目录
/// 每行可点按跳转，并带真实页码：
/// - 页码只有正文绘制时才确定（`MultiPage` 排版时放不下的组件会挪到下一页
///   重排，排版阶段记下的页码不可靠），所以由 [_BookAnchor] 在绘制时记下；
/// - pdf 库按 `addPage` 的先后绘制，目录因此最后加入、以 `index` 插在扉页
///   之后：正文先绘制、页码已记下，目录绘制时再填（[pw.DelayedWidget]）。
///   页码与页脚同一套编号（扉页算第 1 页）。
class DiaryPdfWriter {
  const DiaryPdfWriter._();

  /// 图片总量上限（字节）：手机照片约 3~5MB 一张，约等于 40 张左右。
  static const int maxImageBytes = 160 * 1024 * 1024;
  static final PdfPageFormat _pageFormat = PdfPageFormat(
    21.0 * PdfPageFormat.cm,
    29.7 * PdfPageFormat.cm,
    marginAll: 2.0 * PdfPageFormat.cm,
  );

  /// 扉页封面的最大高度：书名、简介与统计行要留在同一页。
  static const double _maxCoverHeight = 11.0 * PdfPageFormat.cm;

  static Future<DiaryExportOutput> write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required DiaryPdfFonts fonts,
    required String documentTitle,
    TextDirection textDirection = TextDirection.ltr,
    DiaryExportBookLayout? book,
    DiaryExportCodeTheme? code,
  }) async {
    final textEffects = DiaryPdfTextEffects(
      regular: fonts.regular,
      bold: fonts.bold,
      bundled: fonts.bundled,
    );
    final theme = pw.ThemeData.withFont(
      base: fonts.regular,
      bold: fonts.bold,
      italic: fonts.regular,
      boldItalic: fonts.bold,
      fontFallback: <pw.Font>[fonts.bundled],
    );
    final images = <Uint8List>[];
    final document = pw.Document(
      theme: theme,
      title: documentTitle,
      creator: 'Jotsy',
      producer: 'Jotsy',
    );
    if (book != null) {
      await _writeBook(
        document,
        book,
        options: options,
        labels: labels,
        media: media,
        fonts: fonts,
        theme: theme,
        textEffects: textEffects,
        images: images,
        textDirection: textDirection,
        code: code,
      );
      return DiaryExportOutput.single(await document.save());
    }

    final content = <pw.Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) {
        content.addAll(_entrySeparator());
      }
      content.addAll(
        await _entryWidgets(
          entries[i],
          options: options,
          labels: labels,
          media: media,
          fonts: fonts,
          theme: theme,
          textEffects: textEffects,
          images: images,
          textDirection: textDirection,
          code: code,
        ),
      );
    }
    document.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        theme: theme,
        maxPages: 100000,
        footer: _footer,
        build: (pw.Context context) => content,
      ),
    );
    return DiaryExportOutput.single(await document.save());
  }

  static pw.Widget _footer(pw.Context context) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      '${context.pageNumber} / ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
  );

  /// 篇与篇之间的细分隔线。
  static List<pw.Widget> _entrySeparator() => <pw.Widget>[
    pw.SizedBox(height: 20),
    pw.Divider(color: PdfColors.grey400, thickness: 0.5),
    pw.SizedBox(height: 16),
  ];

  /// 一篇日记的抬头与正文；[wrapTitle] 给标题套上书签锚点（成书时）。
  static Future<List<pw.Widget>> _entryWidgets(
    DiaryExportEntry entry, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required DiaryPdfFonts fonts,
    required pw.ThemeData theme,
    required DiaryPdfTextEffects textEffects,
    required List<Uint8List> images,
    required TextDirection textDirection,
    DiaryExportCodeTheme? code,
    pw.Widget Function(pw.Widget title)? wrapTitle,
  }) async {
    final widgets = await _header(
      entry,
      options: options,
      labels: labels,
      media: media,
      images: images,
      wrapTitle: wrapTitle,
    );
    final body = await prepareBody(
      entry,
      includeImages: options.includeMedia,
      labels: labels,
      media: media,
      images: images,
      code: code,
    );
    if (body != null) {
      widgets.addAll(
        _renderBody(
          body.document,
          imageIndex: body.imageIndex,
          theme: theme,
          fonts: fonts,
          effects: textEffects,
          images: images,
          labels: labels,
          media: media,
          includeImages: options.includeMedia,
          textDirection: textDirection,
          code: code,
        ),
      );
    }
    return widgets;
  }

  /// 成书：扉页 → 目录 → 正文（见类注释里的页码与绘制顺序）。
  static Future<void> _writeBook(
    pw.Document document,
    DiaryExportBookLayout book, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required DiaryPdfFonts fonts,
    required pw.ThemeData theme,
    required DiaryPdfTextEffects textEffects,
    required List<Uint8List> images,
    required TextDirection textDirection,
    DiaryExportCodeTheme? code,
  }) async {
    // 锚点 → 页码：正文绘制时由 _BookAnchor 写入，目录绘制时读取。
    final pages = <String, int>{};
    Uint8List? cover;
    if (options.includeMedia && book.coverPath != null) {
      final bytes = await media.bytesOf(book.coverPath!);
      if (bytes != null && ExportImageInfo.read(bytes) != null) {
        _addImage(images, bytes);
        cover = bytes;
      }
    }

    final content = <pw.Widget>[];
    final entryLevel = book.hasChapterHeadings ? 1 : 0;
    for (var s = 0; s < book.sections.length; s++) {
      final section = book.sections[s];
      final title = section.title;
      if (title != null) {
        // 正文本身从新的一页开始，之后每章另起一页。
        if (s > 0) {
          content.add(pw.NewPage());
        }
        content.add(
          _BookAnchor(
            name: section.anchor,
            title: title,
            level: 0,
            pages: pages,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }
      for (var i = 0; i < section.entries.length; i++) {
        final entry = section.entries[i];
        if (i > 0) {
          content.addAll(_entrySeparator());
        }
        content.addAll(
          await _entryWidgets(
            entry,
            options: options,
            labels: labels,
            media: media,
            fonts: fonts,
            theme: theme,
            textEffects: textEffects,
            images: images,
            textDirection: textDirection,
            code: code,
            wrapTitle: (pw.Widget child) => _BookAnchor(
              name: book.anchorOf(entry),
              title: labels.titleOf(entry),
              level: entryLevel,
              pages: pages,
              child: child,
            ),
          ),
        );
      }
    }

    document
      ..addPage(
        pw.Page(
          pageFormat: _pageFormat,
          theme: theme,
          build: (pw.Context context) => _titlePage(book, cover),
        ),
      )
      ..addPage(
        pw.MultiPage(
          pageFormat: _pageFormat,
          theme: theme,
          maxPages: 100000,
          footer: _footer,
          build: (pw.Context context) => content,
        ),
      )
      // 最后加入、插在扉页之后：绘制排在正文之后，页码已经记下。
      ..addPage(
        pw.MultiPage(
          pageFormat: _pageFormat,
          theme: theme,
          maxPages: 100000,
          footer: _footer,
          build: (pw.Context context) => _contents(book, labels, pages),
        ),
        index: 1,
      );
  }

  static pw.Widget _titlePage(DiaryExportBookLayout book, Uint8List? cover) {
    final info = cover == null ? null : ExportImageInfo.read(cover);
    pw.Widget? coverImage;
    if (cover != null && info != null && info.width > 0 && info.height > 0) {
      final scale = math.min(
        _pageFormat.availableWidth / info.width,
        _maxCoverHeight / info.height,
      );
      coverImage = pw.ClipRRect(
        horizontalRadius: 8,
        verticalRadius: 8,
        child: pw.Image(
          pw.MemoryImage(cover),
          width: info.width * scale,
          height: info.height * scale,
          fit: pw.BoxFit.contain,
        ),
      );
    }
    const muted = pw.TextStyle(fontSize: 11, color: PdfColors.grey700);
    return pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: <pw.Widget>[
          if (coverImage != null) ...<pw.Widget>[
            coverImage,
            pw.SizedBox(height: 28),
          ],
          pw.Text(
            book.title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
          ),
          if (book.description != null) ...<pw.Widget>[
            pw.SizedBox(height: 12),
            pw.Text(
              book.description!,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 20),
          if (book.summaryLine.isNotEmpty)
            pw.Text(
              book.summaryLine,
              textAlign: pw.TextAlign.center,
              style: muted,
            ),
          pw.SizedBox(height: 4),
          pw.Text(
            book.exportedLine,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _contents(
    DiaryExportBookLayout book,
    DiaryExportLabels labels,
    Map<String, int> pages,
  ) {
    final widgets = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pw.Text(
          book.contentsTitle,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    final indent = book.hasChapterHeadings ? 16.0 : 0.0;
    for (final section in book.sections) {
      if (section.title != null) {
        widgets.add(
          _contentsRow(
            section.title!,
            section.anchor,
            pages,
            style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold),
            top: widgets.length > 1 ? 10 : 0,
          ),
        );
      }
      for (final entry in section.entries) {
        widgets.add(
          _contentsRow(
            '${labels.formatDate(entry.createdAt.toLocal())}  '
            '${labels.titleOf(entry)}',
            book.anchorOf(entry),
            pages,
            style: const pw.TextStyle(fontSize: 11),
            indent: indent,
          ),
        );
      }
    }
    return widgets;
  }

  /// 目录的一行：点按跳到 [anchor]，右侧是它所在的页码。
  static pw.Widget _contentsRow(
    String text,
    String anchor,
    Map<String, int> pages, {
    required pw.TextStyle style,
    double indent = 0,
    double top = 0,
  }) {
    return pw.Link(
      destination: anchor,
      child: pw.Padding(
        padding: pw.EdgeInsets.only(left: indent, top: top + 3, bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Expanded(child: pw.Text(text, style: style)),
            pw.SizedBox(width: 12),
            // 排版时页码还不知道，先占一格；绘制时（正文已绘制完）再取。
            pw.SizedBox(
              width: 36,
              child: pw.DelayedWidget(
                build: (pw.Context context) => pw.Text(
                  pages[anchor]?.toString() ?? ' ',
                  style: style,
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<List<pw.Widget>> _header(
    DiaryExportEntry entry, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required List<Uint8List> images,
    pw.Widget Function(pw.Widget title)? wrapTitle,
  }) async {
    const muted = pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700);
    final title = pw.Text(
      labels.titleOf(entry),
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    );
    final widgets = <pw.Widget>[
      wrapTitle == null ? title : wrapTitle(title),
      pw.SizedBox(height: 4),
      pw.Text(labels.formatDateTime(entry.createdAt.toLocal()), style: muted),
    ];
    if (options.includeMeta) {
      final meta = labels.metaLine(entry, includeMood: false);
      if (meta.isNotEmpty) {
        widgets.add(pw.Text(meta, style: muted));
      }
      if (entry.tagNames.isNotEmpty) {
        widgets.add(
          pw.Text(
            entry.tagNames.map((String tag) => '#$tag').join('  '),
            style: const pw.TextStyle(
              fontSize: 10.5,
              color: PdfColors.blueGrey700,
            ),
          ),
        );
      }
    }
    if (options.includeMedia && entry.cover != null) {
      final bytes = await media.bytesOf(entry.cover!);
      if (bytes != null && ExportImageInfo.read(bytes) != null) {
        // 计入总量（虚拟地址按下标取图，封面不经插件，放在列表里不影响）。
        _addImage(images, bytes);
        widgets
          ..add(pw.SizedBox(height: 12))
          ..add(
            pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(
                pw.MemoryImage(bytes),
                height: 260,
                fit: pw.BoxFit.cover,
              ),
            ),
          );
      }
    }
    widgets.add(pw.SizedBox(height: 14));
    return widgets;
  }

  /// 改写正文 Delta（见类注释）；没有可见内容时返回 null。给了 [code] 时
  /// 先为代码行着色：要在下面把语言值改写为 `true` 之前，着色要用到语言。
  @visibleForTesting
  /// 处理正文 Document：收集图片、检查可见内容。
  ///
  /// 返回处理后的文档与图片 URL 到下标的映射；没有可见内容时返回 null。
  /// 图片缺失时跳过，不中断导出。颜色压平在渲染时由
  /// [DiaryPdfAppFlowyRenderer] 处理。
  @visibleForTesting
  static Future<({af.Document document, Map<String, int> imageIndex})?>
  prepareBody(
    DiaryExportEntry entry, {
    required bool includeImages,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required List<Uint8List> images,
    DiaryExportCodeTheme? code,
  }) async {
    final document = entry.document;
    final imageIndex = <String, int>{};
    
    // 收集图片：遍历所有图片节点，读取字节并建立 URL 到下标的映射。
    if (includeImages) {
      await _collectImages(document.root, media, images, imageIndex);
    }
    
    // 检查可见内容。
    if (!appFlowyDocumentHasVisibleContent(document) && imageIndex.isEmpty) {
      return null;
    }
    
    return (document: document, imageIndex: imageIndex);
  }

  /// 递归收集文档中的图片。
  static Future<void> _collectImages(
    af.Node node,
    DiaryExportMediaLibrary media,
    List<Uint8List> images,
    Map<String, int> imageIndex,
  ) async {
    if (node.type == 'image') {
      final url = node.attributes['url']?.toString();
      if (url != null && url.isNotEmpty && !imageIndex.containsKey(url)) {
        final bytes = await media.bytesOf(url);
        if (bytes != null && ExportImageInfo.read(bytes) != null) {
          _addImage(images, bytes);
          imageIndex[url] = images.length - 1;
        }
      }
    }
    for (final child in node.children) {
      await _collectImages(child, media, images, imageIndex);
    }
  }

  static void _addImage(List<Uint8List> images, Uint8List bytes) {
    images.add(bytes);
    final total = images.fold<int>(0, (int sum, Uint8List b) => sum + b.length);
    if (total > maxImageBytes) {
      throw DiaryExportTooLargeException(total);
    }
  }

  /// 把 AppFlowy Document 渲染为 PDF 组件。
  ///
  /// 直接经 [DiaryPdfAppFlowyRenderer] 逐节点渲染，不经过 Quill。
  static List<pw.Widget> _renderBody(
    af.Document body, {
    required Map<String, int> imageIndex,
    required pw.ThemeData theme,
    required DiaryPdfFonts fonts,
    required DiaryPdfTextEffects effects,
    required List<Uint8List> images,
    required DiaryExportLabels labels,
    required DiaryExportMediaLibrary media,
    required bool includeImages,
    required TextDirection textDirection,
    DiaryExportCodeTheme? code,
  }) {
    final widgets = DiaryPdfAppFlowyRenderer.render(
      body,
      theme: theme,
      effects: effects,
      images: images,
      imageIndex: imageIndex,
      labels: labels,
      media: media,
      includeImages: includeImages,
      code: code,
    );
    return widgets.map(effects.wrap).toList();
  }
}

/// 成书的章节与篇标题：PDF 书签（大纲）+ 命名目标，并在绘制时记下自己所在
/// 的页码供目录使用（见 [DiaryPdfWriter] 的类注释）。
class _BookAnchor extends pw.Outline {
  _BookAnchor({
    required super.name,
    required super.title,
    required super.level,
    required this.pages,
    required pw.Widget super.child,
  });

  final Map<String, int> pages;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    pages[name] = context.pageNumber;
  }
}
