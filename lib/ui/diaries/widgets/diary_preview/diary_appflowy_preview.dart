import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../core/database/audio_embed_codec.dart';
import '../../../../core/database/content_codec.dart';
import '../../../../core/database/file_embed_codec.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../models/diary_code_block/diary_code_highlighter.dart';
import '../../models/diary_code_block/diary_code_language.dart';
import '../../models/diary_code_block/diary_code_theme.dart';
import '../../models/diary_image_embed_data.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../providers/diary_code_block_style_provider.dart';
import '../../viewmodels/diary_code_block_look.dart';
import '../../viewmodels/diary_first_line_indent.dart';
import '../../viewmodels/diary_text_appearance.dart';
import '../diary_attachment_tile.dart';
import '../diary_audio_player.dart';
import '../diary_code_block/diary_code_block_header_painter.dart';
import '../diary_image_embed_builder.dart';
import '../diary_video_player.dart';

/// 预览页正文的 AppFlowy 只读渲染：把 [Document] 逐块建成 widget 树。
///
/// 输入：AppFlowy [Document]（经 [diaryDocumentFromStoredJson] 解析）、正文
/// 外观 [DiaryTextAppearance]，以及可选的图片点按回调与待办勾选回调。
/// 输出：只读的正文 widget 树。视觉与 Quill 时代保持一致：字体、字号、
/// 行距、段间距、标题字阶（沿用 Quill 默认字号/字重，只换字体与字间距）、
/// 列表（项目符号/编号/待办）与引用的排版、代码块整套外观（标题栏、行号、
/// 语法高亮、配色）、行内格式（加粗/斜体/下划线/删除线/行内代码/链接/
/// 颜色/背景色/字号档位）与嵌入渲染（图片/视频/录音/附件/分隔线）。
/// 副作用：链接点按经 url_launcher 打开；代码块复制按钮写剪贴板并提示。
///
/// 为什么不用 `AppFlowyEditor(editable: false)`：日记正文的排版（首行缩进、
/// 段间距、标题字阶、行内字号档位）与代码块外观都是 Quill 时代的定制，
/// 逐块渲染能逐项对齐原有视觉；媒体块复用已有的纯 widget
/// （[DiaryEmbeddedImage]、[DiaryVideoPlayer]、[DiaryAudioPlayer]、
/// [DiaryAttachmentTile]），与迁移后的 AppFlowy 块组件同一套 UI。
///
/// [textSelection] 为 true 时整棵树包进 [SelectionArea]，跨段落选择、复制
/// 与 Quill 时代一致。待办复选框只在 [onToggleTodo] 给出时可点：预览页传入
/// （勾选后经 EditorState 事务写回、由页面的自动保存控制器落库），发布页
/// 预览不传（只读，与 Quill 时代 `checkBoxReadOnly` 默认跟随 readOnly
/// 的行为一致）。
class DiaryAppFlowyPreview extends ConsumerWidget {
  const DiaryAppFlowyPreview({
    super.key,
    required this.document,
    required this.appearance,
    this.onOpenImage,
    this.onToggleTodo,
    this.textSelection = true,
    this.longImageMode = DiaryPreviewLongImageMode.fold,
  });

  final Document document;
  final DiaryTextAppearance appearance;

  /// 点按正文图片：来源与点按处抓取的共享元素；null 时图片不可点按
  ///（发布页预览）。
  final void Function(String source, ImageViewerHero? hero)? onOpenImage;

  /// 待办勾选变化：调用方把 `checked` 写回 EditorState（预览页经事务写回
  /// 并触发自动保存）；null 时复选框只读。
  final void Function(Node node, bool checked)? onToggleTodo;

  /// 允许长按选择文字。
  final bool textSelection;

  /// 正文长图折叠还是完整显示。
  final DiaryPreviewLongImageMode longImageMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeStyle = ref.watch(diaryCodeBlockStyleProvider);
    final importedFontFamily = ref.watch(diaryCodeBlockFontFamilyProvider);
    final code = DiaryCodeBlockLook.resolve(
      context,
      style: codeStyle,
      appearance: appearance,
      importedFontFamily: importedFontFamily,
    );
    final styles = _PreviewTextStyles.resolve(context, appearance);
    final ctx = _BlockBuildContext(
      appearance: appearance,
      styles: styles,
      code: code,
      onOpenImage: onOpenImage,
      onToggleTodo: onToggleTodo,
      foldLongImages: longImageMode == DiaryPreviewLongImageMode.fold,
    );
    final children = document.root.children;
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < children.length; i++)
          _buildBlock(
            context,
            children[i],
            ctx,
            index: i,
            siblings: children,
          ),
      ],
    );
    if (textSelection) {
      body = SelectionArea(child: body);
    }
    return body;
  }
}

/// AppFlowy Document 是否包含可见内容：用 [appFlowyDocumentHasVisibleContent]
///（与 Quill 时代 `diaryDocumentHasVisibleContent` 同口径——有非空白文字的
/// 文本块，或图片、视频与其他嵌入，都算可见内容；不能只看纯文本镜像，
/// 否则“仅图片正文”会被误判为空）。
bool diaryAppFlowyDocumentHasVisibleContent(Document document) =>
    appFlowyDocumentHasVisibleContent(document);

/// 逐块构建时的共享上下文：解析好的文本样式、代码块外观与回调。
class _BlockBuildContext {
  const _BlockBuildContext({
    required this.appearance,
    required this.styles,
    required this.code,
    required this.onOpenImage,
    required this.onToggleTodo,
    required this.foldLongImages,
  });

  final DiaryTextAppearance appearance;
  final _PreviewTextStyles styles;
  final DiaryCodeBlockLook code;
  final void Function(String source, ImageViewerHero? hero)? onOpenImage;
  final void Function(Node node, bool checked)? onToggleTodo;
  final bool foldLongImages;
}

/// 正文位置的文本样式：Quill `DefaultStyles` 经 `buildDiaryQuillStyles`
/// 叠加正文排版后的结果，照搬到这里。
///
/// - 段落：字体、字号、行距、字间距来自 [DiaryTypography]；
/// - 标题：只换字体并叠加字间距，保留 Quill 的标题字号与字重；
/// - 列表 / 引用：同样叠加正文字体排版；
/// - 段间距加在段落之后；列表项与引用不是段落，保持原有间距；
/// - 行内字号三档按正文字号缩放（0.85 / 1.25 / 1.5）。
class _PreviewTextStyles {
  const _PreviewTextStyles({
    required this.baseColor,
    required this.body,
    required this.headings,
    required this.headingTops,
    required this.quote,
    required this.linkColor,
    required this.paragraphSpacing,
    required this.fontSize,
  });

  static _PreviewTextStyles resolve(
    BuildContext context,
    DiaryTextAppearance appearance,
  ) {
    // 自定义正文色经外层的 DefaultTextStyle.merge 传进来（段落、标题都从
    // 它取色）；null 时用主题正文色。与 Quill 时代
    // `DefaultStyles.getInstance(context)` 的取色位置一致。
    final defaultStyle = DefaultTextStyle.of(context).style;
    final baseColor = defaultStyle.color;
    final typography = appearance.typography;

    // 与 Quill 时代 `style.copyWith(fontFamily: …)` 同口径：appearance 没给
    // 字族（字体文件不在了）时回落环境主题字族，而不是 null。
    final family = appearance.fontFamily ?? defaultStyle.fontFamily;

    final body = TextStyle(
      color: baseColor,
      fontFamily: family,
      fontSize: typography.fontSize,
      height: typography.lineHeight,
      letterSpacing: typography.letterSpacing,
    );

    TextStyle heading(
      double size,
      double letterSpacing,
      double height,
    ) => TextStyle(
      color: baseColor,
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.bold,
      letterSpacing: letterSpacing + typography.letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );

    // Quill 默认的标题字号、字重、字间距与行距（见 DefaultStyles）。
    final headings = <TextStyle>[
      heading(34, -0.5, 1.083),
      heading(30, -0.8, 1.067),
      heading(24, -0.5, 1.083),
      heading(20, -0.4, 1.1),
      heading(18, -0.2, 1.11),
      heading(16, -0.1, 1.125),
    ];
    // Quill 默认的标题上间距。
    const headingTops = <double>[16, 8, 8, 6, 6, 4];

    final quote = body.copyWith(color: baseColor?.withValues(alpha: 0.6));

    return _PreviewTextStyles(
      baseColor: baseColor,
      body: body,
      headings: headings,
      headingTops: headingTops,
      quote: quote,
      linkColor: Theme.of(context).colorScheme.secondary,
      paragraphSpacing: typography.paragraphSpacing,
      fontSize: typography.fontSize,
    );
  }

  final Color? baseColor;
  final TextStyle body;

  /// h1–h6 的文本样式。
  final List<TextStyle> headings;

  /// h1–h6 的上间距。
  final List<double> headingTops;

  final TextStyle quote;
  final Color linkColor;
  final double paragraphSpacing;
  final double fontSize;
}

/// 构建单个顶层块（含嵌套子块）。[index]/[siblings] 用于列表编号与“连续
/// 列表首项”的判定。
Widget _buildBlock(
  BuildContext context,
  Node node,
  _BlockBuildContext ctx, {
  required int index,
  required List<Node> siblings,
  int depth = 0,
}) {
  final type = node.type;
  switch (type) {
    case kDiaryBlockParagraph:
      return _ParagraphBlock(node: node, ctx: ctx, depth: depth);
    case kDiaryBlockHeading:
      return _HeadingBlock(node: node, ctx: ctx, depth: depth);
    case kDiaryBlockBulletedList:
    case kDiaryBlockNumberedList:
    case kDiaryBlockTodoList:
      final firstInRun = index == 0 || siblings[index - 1].type != type;
      return _ListItemBlock(
        node: node,
        ctx: ctx,
        depth: depth,
        index: index,
        siblings: siblings,
        firstInRun: firstInRun,
      );
    case kDiaryBlockQuote:
      return _QuoteBlock(node: node, ctx: ctx, depth: depth);
    case kDiaryBlockCode:
      return _CodeBlock(node: node, ctx: ctx, depth: depth);
    case kDiaryBlockDivider:
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      );
    case kDiaryBlockImage:
      return _ImageBlock(node: node, ctx: ctx);
    case kDiaryBlockVideo:
      return _VideoBlock(node: node);
    case kDiaryBlockAudio:
      return _AudioBlock(node: node);
    case kDiaryBlockAttachment:
      return _AttachmentBlock(node: node);
    default:
      // 认不出的块类型（未知嵌入、更新版本写入的新块）：Quill 时代没有
      // 对应的渲染器，这里同样不占位；子块照常渲染，避免丢内容。
      return _ChildBlocks(node: node, ctx: ctx, depth: depth);
  }
}

/// 嵌套子块：缩进显示在父块之下（与 Quill 时代 `indent` 属性的视觉一致，
/// 每级缩进一个正文字号）。
class _ChildBlocks extends StatelessWidget {
  const _ChildBlocks({
    required this.node,
    required this.ctx,
    required this.depth,
  });

  final Node node;
  final _BlockBuildContext ctx;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final children = node.children;
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(left: ctx.styles.fontSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++)
            _buildBlock(
              context,
              children[i],
              ctx,
              index: i,
              siblings: children,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }
}

/// 对齐属性 → TextAlign（缺省为起始侧）。
TextAlign _blockTextAlign(Node node) {
  return switch (node.attributes[kDiaryBlockAlignKey]) {
    kDiaryAlignCenter => TextAlign.center,
    kDiaryAlignRight => TextAlign.right,
    kDiaryAlignJustify => TextAlign.justify,
    _ => TextAlign.start,
  };
}

/// 普通段落：正文排版 + 首行缩进 + 段间距。
class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({
    required this.node,
    required this.ctx,
    required this.depth,
  });

  final Node node;
  final _BlockBuildContext ctx;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final styles = ctx.styles;
    final typography = styles.body;
    final diaryTypography = ctx.appearance.typography;
    // 首行缩进只在这里垫出来：段落首个文字 span 前插定宽占位，原文
    // Delta 不动（与 Quill 时代一致）。
    final indentWidth = diaryFirstLineIndentWidth(diaryTypography);
    final indent = shouldApplyFirstLineIndent(node, diaryTypography);
    final span = _buildDeltaSpan(
      context,
      node.delta,
      typography,
      ctx,
      firstLineIndent: indent
          ? buildFirstLineIndentLeading(
              indentWidth,
              typography.fontSize ?? 16,
            )
          : null,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: depth * styles.fontSize,
        bottom: styles.paragraphSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text.rich(span, textAlign: _blockTextAlign(node)),
          _ChildBlocks(node: node, ctx: ctx, depth: depth),
        ],
      ),
    );
  }
}

/// 标题：字号/字重/行距沿用 Quill 默认字阶，只换字体与字间距。
class _HeadingBlock extends StatelessWidget {
  const _HeadingBlock({
    required this.node,
    required this.ctx,
    required this.depth,
  });

  final Node node;
  final _BlockBuildContext ctx;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final styles = ctx.styles;
    final level = node.attributes[kDiaryBlockLevelKey];
    final index = level is int ? (level - 1).clamp(0, 5) : 0;
    final style = styles.headings[index];
    final span = _buildDeltaSpan(
      context,
      node.delta,
      style,
      ctx,
      headingLevel: index + 1,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: depth * styles.fontSize,
        top: styles.headingTops[index],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text.rich(span, textAlign: _blockTextAlign(node)),
          _ChildBlocks(node: node, ctx: ctx, depth: depth),
        ],
      ),
    );
  }
}

/// 列表项：项目符号 / 编号 / 待办。编号按嵌套层级循环 `1.` `a.` `i.`
///（与 Quill 的 `getIndexNumberByIndent` 一致）；连续同类型列表的首项上方
/// 留 6dp（Quill 列表块的上间距），每项下方 6dp（行间距）。
class _ListItemBlock extends StatelessWidget {
  const _ListItemBlock({
    required this.node,
    required this.ctx,
    required this.depth,
    required this.index,
    required this.siblings,
    required this.firstInRun,
  });

  final Node node;
  final _BlockBuildContext ctx;
  final int depth;
  final int index;
  final List<Node> siblings;
  final bool firstInRun;

  @override
  Widget build(BuildContext context) {
    final styles = ctx.styles;
    final body = styles.body;
    final fontSize = styles.fontSize;
    final type = node.type;
    final Widget leading;
    final double markerWidth;
    if (type == kDiaryBlockTodoList) {
      // 复选框 + 半个字宽的间距（与 Quill 时代一致）；复选框在首行高度
      // 内垂直居中。
      markerWidth = fontSize * 1.5;
      leading = SizedBox(
        height: fontSize * (body.height ?? 1.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _TodoCheckbox(node: node, ctx: ctx, size: fontSize),
            SizedBox(width: fontSize / 2),
          ],
        ),
      );
    } else if (type == kDiaryBlockNumberedList) {
      final number = _itemNumber();
      markerWidth = _numberPointWidth(fontSize, _runLength());
      leading = Text(
        _numberMarker(number, depth),
        style: body,
      );
    } else {
      markerWidth = fontSize * 2;
      leading = Text('•', style: body);
    }
    final span = _buildDeltaSpan(context, node.delta, body, ctx);
    return Padding(
      padding: EdgeInsets.only(
        left: depth * fontSize,
        top: firstInRun ? 6 : 0,
        bottom: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: markerWidth, child: leading),
              Expanded(
                child: Text.rich(span, textAlign: _blockTextAlign(node)),
              ),
            ],
          ),
          _ChildBlocks(node: node, ctx: ctx, depth: depth),
        ],
      ),
    );
  }

  /// 本项在连续同类型兄弟中的序号（1 起）。
  int _itemNumber() {
    var number = 1;
    for (var i = index - 1; i >= 0; i--) {
      if (siblings[i].type != node.type) break;
      number++;
    }
    return number;
  }

  /// 连续同类型兄弟的总数（编号列宽用）。
  int _runLength() {
    var count = 1;
    for (var i = index - 1; i >= 0; i--) {
      if (siblings[i].type != node.type) break;
      count++;
    }
    for (var i = index + 1; i < siblings.length; i++) {
      if (siblings[i].type != node.type) break;
      count++;
    }
    return count;
  }
}

/// 编号标记：层级 0 → `1.`，1 → `a.`，2 → `i.`，之后循环。
String _numberMarker(int number, int depth) {
  final marker = switch (depth % 3) {
    1 => _toAlpha(number),
    2 => _toRoman(number),
    _ => number.toString(),
  };
  return '$marker.';
}

String _toAlpha(int n) {
  final buffer = StringBuffer();
  var value = n;
  while (value > 0) {
    value--;
    buffer.write(String.fromCharCode(value % 26 + 97));
    value ~/= 26;
  }
  return buffer.toString().split('').reversed.join();
}

String _toRoman(int n) {
  if (n <= 0) return '';
  const arabian = <int>[
    1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1,
  ];
  const roman = <String>[
    'm', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i',
  ];
  final buffer = StringBuffer();
  var value = n;
  for (var i = 0; i < arabian.length; i++) {
    final times = value ~/ arabian[i];
    buffer.write(roman[i] * times);
    value -= times * arabian[i];
  }
  return buffer.toString();
}

/// Quill 默认的编号列宽：两位数以内为两个字宽。
double _numberPointWidth(double fontSize, int count) {
  final length = '$count'.length;
  if (length <= 2) return fontSize * 2;
  return fontSize * (length - (length - 2) / 2);
}

/// 待办复选框：外观照搬 Quill 的 `QuillCheckboxPoint`（主色填充/对勾、
/// 2dp 圆角、半个字宽的右侧间距）。
class _TodoCheckbox extends StatefulWidget {
  const _TodoCheckbox({
    required this.node,
    required this.ctx,
    required this.size,
  });

  final Node node;
  final _BlockBuildContext ctx;
  final double size;

  @override
  State<_TodoCheckbox> createState() => _TodoCheckboxState();
}

class _TodoCheckboxState extends State<_TodoCheckbox> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onToggleTodo = widget.ctx.onToggleTodo;
    final enabled = onToggleTodo != null;
    final value = widget.node.attributes[kDiaryBlockCheckedKey] == true;
    final size = widget.size;
    final fillColor = value
        ? (enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.5))
        : theme.colorScheme.surface;
    final borderColor = value
        ? (enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0))
        : (enabled
              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
              : theme.colorScheme.onSurface.withValues(alpha: 0.3));
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: fillColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor),
          borderRadius: BorderRadius.circular(2),
        ),
        child: InkWell(
          onTap: enabled
              ? () {
                  onToggleTodo(widget.node, !value);
                  // 事务写回后本地刷新勾选态；落库由页面的自动保存负责。
                  setState(() {});
                }
              : null,
          child: value
              ? Icon(
                  Icons.check,
                  size: size,
                  color: theme.colorScheme.onPrimary,
                )
              : null,
        ),
      ),
    );
  }
}

/// 引用：左侧 4dp 灰线、文字 60% 透明度（与 Quill 默认一致）。
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({
    required this.node,
    required this.ctx,
    required this.depth,
  });

  final Node node;
  final _BlockBuildContext ctx;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final styles = ctx.styles;
    final span = _buildDeltaSpan(context, node.delta, styles.quote, ctx);
    return Padding(
      padding: EdgeInsets.only(
        left: depth * styles.fontSize,
        top: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(width: 4, color: Colors.grey.shade300),
              ),
            ),
            padding: EdgeInsets.only(left: styles.fontSize),
            child: Text.rich(span, textAlign: _blockTextAlign(node)),
          ),
          _ChildBlocks(node: node, ctx: ctx, depth: depth),
        ],
      ),
    );
  }
}

/// 代码块：外观（配色、字体、圆角、边框）来自 [DiaryCodeBlockLook]，与
/// Quill 时代一致；标题栏（语言名 + 复制）直接画在代码块上方，与 Quill
/// 时代 `DiaryCodeBlockChrome` 的视觉一致（同一套
/// [DiaryCodeBlockHeaderPainter]）。
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({
    required this.node,
    required this.ctx,
    required this.depth,
  });

  final Node node;
  final _BlockBuildContext ctx;
  final int depth;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  /// 复制后对勾停留 1.5 秒（与 Quill 时代的 DiaryCodeBlockChrome 一致；
  /// diary_preview 目录源码规则禁止毫秒字面量，这里用微秒表达）。
  static const copiedDuration = Duration(microseconds: 1500000);

  bool _copied = false;
  Timer? _resetCopied;
  DiaryCodeBlockHeaderPainter? _headerPainter;

  @override
  void dispose() {
    _resetCopied?.cancel();
    _headerPainter?.dispose();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      // 剪贴板不可用：不提示成功、不换对勾。
      return;
    }
    if (!mounted) return;
    // 复制生效的一刻轻震（DESIGN.md §4.3）。
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(context.l10n.codeBlockCopied)),
      ),
    );
    _resetCopied?.cancel();
    setState(() => _copied = true);
    // 对勾停留时长与 Quill 时代一致（非动画计时，不走 ExpressiveMotion）。
    _resetCopied = Timer(copiedDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// 高亮用的语言 id：明确指定的语言；'plain' 不高亮；未指定时按
  /// [DiaryCodeBlockLook.autoDetect] 取自动识别结果（关闭时不高亮）。
  String? _highlightLanguage(String text) {
    final choice = DiaryCodeLanguageChoice.fromAttributeValue(
      widget.node.attributes[kDiaryBlockLanguageKey],
    );
    if (choice.isPlain) return null;
    final explicit = choice.languageId;
    if (explicit != null) return explicit;
    if (!widget.ctx.code.autoDetect) return null;
    return DiaryCodeHighlighter.instance.detect(text);
  }

  /// 标题栏的语言名：纯文本 / 明确语言 / 自动识别结果 / “代码”。
  String _headerLabel(AppLocalizations l10n, String text) {
    final choice = DiaryCodeLanguageChoice.fromAttributeValue(
      widget.node.attributes[kDiaryBlockLanguageKey],
    );
    if (choice.isPlain) return l10n.codeBlockLanguagePlain;
    final id = choice.languageId ??
        (widget.ctx.code.autoDetect
            ? DiaryCodeHighlighter.instance.detect(text)
            : null);
    final name = id == null ? null : diaryCodeLanguageById(id)?.name;
    return name ?? l10n.codeBlockLabelGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final look = ctx.code;
    final styles = ctx.styles;
    final text = widget.node.delta?.toPlainText() ?? '';
    final language = _highlightLanguage(text);
    final tokens = language == null
        ? DiaryCodeTokens.empty
        : DiaryCodeHighlighter.instance.tokens(text, language);
    final tokenStyles = <DiaryCodeTokenRole, TextStyle>{
      for (final role in DiaryCodeTokenRole.values)
        role: look.palette.tokenStyle(role),
    };

    final l10n = context.l10n;
    // 标题栏高度固定，限制系统字号的放大倍数，语言名不至于撑出标题栏
    //（与 Quill 时代的 DiaryCodeBlockChrome 一致）。
    final textScaler = MediaQuery.textScalerOf(context).clamp(
      maxScaleFactor: 2,
    );
    final labelStyle = (Theme.of(context).textTheme.labelMedium ??
            const TextStyle())
        .copyWith(fontSize: 12, fontWeight: FontWeight.w600);
    DiaryCodeBlockHeaderPainter? headerPainter;
    if (look.header) {
      headerPainter = _headerPainter ??= DiaryCodeBlockHeaderPainter(
        palette: look.palette,
        radius: look.style.radius,
        border: look.style.border,
        labelStyle: labelStyle,
        textScaler: textScaler,
      );
      // 主题/设置变化时更新绘制参数（缓存的文字排版一并失效）。
      headerPainter.update(
        palette: look.palette,
        radius: look.style.radius,
        border: look.style.border,
        labelStyle: labelStyle,
        textScaler: textScaler,
      );
    }

    final lines = text.split('\n');
    final lineCount = lines.length;
    final codeStyle = look.codeTextStyle;
    final numberStyle = codeStyle.copyWith(color: look.palette.lineNumber);
    final numberWidth = look.lineNumbers
        ? _numberPointWidth(styles.fontSize, lineCount)
        : 0.0;

    final header = look.header
        ? _CodeBlockHeader(
            painter: headerPainter!,
            label: _headerLabel(l10n, text),
            copied: _copied,
            semanticsLabel: l10n.codeBlockCopy,
            onCopy: () => _copy(text),
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: widget.depth * styles.fontSize,
        // Quill 时代块样式的外边距：上方留出标题栏的位置。
        top: DiaryCodeBlockLook.blockGap + look.headerExtent,
        bottom: DiaryCodeBlockLook.blockGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null) header,
          Container(
            decoration: BoxDecoration(
              color: look.palette.background,
              borderRadius: look.style.header
                  ? BorderRadius.vertical(
                      bottom: Radius.circular(look.style.radius),
                    )
                  : BorderRadius.circular(look.style.radius),
              border: !look.style.border
                  ? null
                  : look.style.header
                  ? Border(
                      left: BorderSide(
                        color: look.palette.border,
                        width: 0.8,
                      ),
                      right: BorderSide(
                        color: look.palette.border,
                        width: 0.8,
                      ),
                      bottom: BorderSide(
                        color: look.palette.border,
                        width: 0.8,
                      ),
                    )
                  : Border.all(
                      color: look.palette.border,
                      width: 0.8,
                    ),
            ),
            // 主体内容区上方 16dp 内边距（标题栏绘制层假定的值）。
            padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < lineCount; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (look.lineNumbers)
                        SizedBox(
                          width: numberWidth,
                          child: Text(
                            '${i + 1}',
                            style: numberStyle,
                          ),
                        )
                      else
                        const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          _highlightedLineSpan(
                            lines[i],
                            _lineOffset(lines, i),
                            tokens,
                            tokenStyles,
                            codeStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _ChildBlocks(node: widget.node, ctx: ctx, depth: widget.depth),
        ],
      ),
    );
  }
}

/// 代码块标题栏：复用 [DiaryCodeBlockHeaderPainter] 的绘制，复制按钮在
/// 右侧 [DiaryCodeBlockHeaderPainter.copyHitWidth] 区域。
class _CodeBlockHeader extends StatelessWidget {
  const _CodeBlockHeader({
    required this.painter,
    required this.label,
    required this.copied,
    required this.semanticsLabel,
    required this.onCopy,
  });

  final DiaryCodeBlockHeaderPainter painter;
  final String label;
  final bool copied;
  final String semanticsLabel;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DiaryCodeBlockLook.headerHeight,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _HeaderCustomPainter(
                painter: painter,
                label: label,
                copied: copied,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: DiaryCodeBlockHeaderPainter.copyHitWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCopy,
              child: Semantics(
                button: true,
                label: semanticsLabel,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCustomPainter extends CustomPainter {
  _HeaderCustomPainter({
    required this.painter,
    required this.label,
    required this.copied,
  });

  final DiaryCodeBlockHeaderPainter painter;
  final String label;
  final bool copied;

  @override
  void paint(Canvas canvas, Size size) {
    painter.paint(
      canvas,
      Offset.zero & size,
      label: label,
      copied: copied,
    );
  }

  @override
  bool shouldRepaint(_HeaderCustomPainter oldDelegate) {
    return oldDelegate.label != label || oldDelegate.copied != copied;
  }
}

/// 第 [lineIndex] 行在整块文本中的起始偏移（高亮区间定位用）。
int _lineOffset(List<String> lines, int lineIndex) {
  var offset = 0;
  for (var i = 0; i < lineIndex; i++) {
    offset += lines[i].length + 1; // +1 为换行符
  }
  return offset;
}

/// 一行代码的高亮 span：与 Quill 时代 `buildDiaryCodeSpanBuilder` 同样的
/// 区间拆分（空隙继承外层样式）。
TextSpan _highlightedLineSpan(
  String line,
  int lineStart,
  DiaryCodeTokens tokens,
  Map<DiaryCodeTokenRole, TextStyle> tokenStyles,
  TextStyle codeStyle,
) {
  if (line.isEmpty) {
    // 空行也要占一行高度，否则行号与代码行错位。
    return TextSpan(text: ' ', style: codeStyle);
  }
  final lineEnd = lineStart + line.length;
  final children = <InlineSpan>[];
  var position = lineStart;
  for (final token in tokens.overlapping(lineStart, lineEnd)) {
    final from = token.start.clamp(lineStart, lineEnd);
    final to = token.end.clamp(lineStart, lineEnd);
    if (from > position) {
      children.add(
        TextSpan(text: line.substring(position - lineStart, from - lineStart)),
      );
    }
    children.add(
      TextSpan(
        text: line.substring(from - lineStart, to - lineStart),
        style: tokenStyles[token.role],
      ),
    );
    position = to;
  }
  if (position < lineEnd) {
    children.add(
      TextSpan(text: line.substring(position - lineStart)),
    );
  }
  if (children.isEmpty) {
    return TextSpan(text: line, style: codeStyle);
  }
  return TextSpan(style: codeStyle, children: children);
}

/// 正文图片：复用 [DiaryEmbeddedImage]（与迁移后的 AppFlowy 图片块组件
/// 同一套 UI）；点按进看图页并抓取共享元素。
class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.node, required this.ctx});

  final Node node;
  final _BlockBuildContext ctx;

  @override
  Widget build(BuildContext context) {
    final source = node.attributes[kDiaryBlockUrlKey]?.toString() ?? '';
    if (source.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox.shrink(),
      );
    }
    final open = ctx.onOpenImage;
    final heroTag = open == null ? null : ImageViewerHeroTag('diary_body', node.id);
    final image = Builder(
      builder: (imageContext) => GestureDetector(
        onTap: open == null
            ? null
            : () => open(
                  source,
                  _captureHero(imageContext, heroTag!),
                ),
        child: DiaryEmbeddedImage(
          source: source,
          bounds: diaryImageEmbedBounds(node),
          heroTag: heroTag,
          foldLongImages: ctx.foldLongImages,
        ),
      ),
    );
    // 比列宽窄的图片靠行首（与正文文字左缘对齐）；heightFactor 防止有界
    // 高度下 Align 撑满整行（与 Quill 时代一致）。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: diaryImageEmbedAlignment(node),
        heightFactor: 1,
        child: image,
      ),
    );
  }

  /// 抓取看图页的飞入画面；图片没有建立来源 Hero 时（完整展开的长图）
  /// 返回 null。
  static ImageViewerHero? _captureHero(BuildContext context, Object tag) {
    var hasHero = false;
    void visit(Element element) {
      if (hasHero) return;
      final widget = element.widget;
      if (widget is Hero && widget.tag == tag) {
        hasHero = true;
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return hasHero ? ImageViewerHero.capture(context, tag: tag) : null;
  }
}

/// 正文视频：复用 [DiaryVideoPlayer]。
class _VideoBlock extends StatelessWidget {
  const _VideoBlock({required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    final video = DiaryFileAttachment.tryDecode(node.attributes);
    if (video == null) {
      return Text(
        context.l10n.videoPlaybackFailed,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryVideoPlayer(key: ValueKey(video.path), video: video);
  }
}

/// 正文录音：复用 [DiaryAudioPlayer]；只读预览不提供重命名。
class _AudioBlock extends StatelessWidget {
  const _AudioBlock({required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    final audio = DiaryAudioAttachment.tryDecode(node.attributes);
    if (audio == null) {
      return Text(
        context.l10n.recordingPlaybackFailed,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryAudioPlayer(key: ValueKey(audio.path), recording: audio);
  }
}

/// 正文附件：复用 [DiaryAttachmentTile]。
class _AttachmentBlock extends StatelessWidget {
  const _AttachmentBlock({required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    final file = DiaryFileAttachment.tryDecode(node.attributes);
    if (file == null) {
      return Text(
        context.l10n.attachmentFileMissing,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryAttachmentTile(key: ValueKey(file.path), attachment: file);
  }
}

/// 由 AppFlowy [Delta] 构建 [TextSpan]：行内格式与 Quill 时代一致。
///
/// 属性优先级照搬 Quill 的 `_getInlineTextStyle`：加粗/斜体/下划线/删除线/
///
/// 链接 → 行内代码 → 字号 → 文字色 → 背景色。
///
/// - `bold`/`italic`/`underline`/`strikethrough`：对应文本样式；
/// - `code`：行内代码样式（等宽字体、行内配色、背景色；标题里的行内代码
///   用对应字阶的字号。Quill 时代背景是绘制层画的圆角，这里用文字背景色
///   近似）；
/// - `href`：副色 + 下划线，点按经 url_launcher 打开；
/// - `font_color`/`bg_color`：`#AARRGGBB` 颜色；
/// - `size`：small/large/huge 三档按正文字号缩放（0.85/1.25/1.5），数字
///   按绝对字号（与 Quill 的 `getFontSize` 一致）。
///
/// [firstLineIndent]：首行缩进的占位 span（只用于普通段落）。
TextSpan _buildDeltaSpan(
  BuildContext context,
  Delta? delta,
  TextStyle base,
  _BlockBuildContext ctx, {
  InlineSpan? firstLineIndent,
  int headingLevel = 0,
}) {
  final children = <InlineSpan>[
    if (firstLineIndent != null) firstLineIndent,
  ];
  if (delta != null) {
    for (final op in delta) {
      if (op is! TextInsert) continue;
      children.add(_spanForInsert(op, base, ctx, headingLevel));
    }
  }
  if (children.isEmpty) {
    // 空段落也要占一行高度，否则空行会被压掉。
    return TextSpan(text: ' ', style: base);
  }
  return TextSpan(style: base, children: children);
}

TextSpan _spanForInsert(
  TextInsert op,
  TextStyle base,
  _BlockBuildContext ctx,
  int headingLevel,
) {
  final styles = ctx.styles;
  final code = ctx.code;
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
  final href = attributes[kDiaryInlineHref];
  GestureRecognizer? recognizer;
  if (href is String && href.isNotEmpty) {
    // 链接样式：Quill 默认取主题副色 + 下划线。
    style = style.copyWith(
      color: styles.linkColor,
      decoration: TextDecoration.underline,
    );
    recognizer = TapGestureRecognizer()
      ..onTap = () => _launchHref(href);
  }
  if (attributes[kDiaryInlineCode] == true) {
    style = style.merge(_inlineCodeStyleFor(code, headingLevel));
  }
  final size = attributes[kDiaryInlineSize];
  if (size != null) {
    final fontSize = _inlineFontSize(size, styles.fontSize);
    if (fontSize != null) {
      style = style.copyWith(fontSize: fontSize);
    }
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
  return TextSpan(text: op.text, style: style, recognizer: recognizer);
}

/// 行内代码样式；标题里的行内代码用对应字阶的字号（与 Quill 的
/// `InlineCodeStyle.styleFor` 一致，只取 h1–h3，日记只有三档）。
TextStyle _inlineCodeStyleFor(DiaryCodeBlockLook code, int headingLevel) {
  final inline = code.inlineStyle;
  final style = switch (headingLevel) {
    1 => inline.header1,
    2 => inline.header2,
    3 => inline.header3,
    _ => inline.style,
  };
  return (style ?? inline.style ?? const TextStyle()).copyWith(
    backgroundColor: inline.backgroundColor,
  );
}

/// 行内字号：三档按正文字号缩放，数字按绝对字号。
double? _inlineFontSize(Object? value, double bodyFontSize) {
  return switch (value) {
    'small' => bodyFontSize * 0.85,
    'large' => bodyFontSize * 1.25,
    'huge' => bodyFontSize * 1.5,
    num _ => value.toDouble(),
    _ => null,
  };
}

/// `#AARRGGBB` → Color；非法值返回 null（忽略）。
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

Future<void> _launchHref(String href) async {
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  // Quill 时代只读正文点链接的默认行为：直接用 url_launcher 打开。
  await launchUrl(uri);
}
