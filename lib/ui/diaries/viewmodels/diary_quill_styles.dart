import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/diary_code_block/diary_code_block_style.dart';
import '../providers/diary_code_block_style_provider.dart';
import '../providers/diary_typography_provider.dart';
import 'diary_code_block_look.dart';
import 'diary_text_appearance.dart';

/// 正文位置解析出的 Quill 外观：样式表与代码块外观。各页面用 [configure]
/// 把它们装进自己的 `QuillEditorConfig`。
///
/// AppFlowy 迁移说明：代码块的高亮、代码字体、行号与标题栏已迁至 AppFlowy
/// 块组件（[DiaryCodeBlockComponentBuilder]，见
/// `diary_code_block_chrome.dart`），不再经 Quill 的 `textSpanBuilder` /
/// `customStyleBuilder` / `customLeadingBlockBuilder` 与标题栏渲染层接入；
/// 这里只剩正文排版样式，供尚未迁到 AppFlowy 编辑器的页面使用。`code` /
/// `inlineCode` 仍按代码块设置装配（PDF 导出走 flutter_quill 渲染，用到
/// 它们），数据来自 [DiaryCodeBlockLook] 的纯数据。
@immutable
class DiaryQuillLook {
  const DiaryQuillLook({required this.styles, required this.code});

  final quill.DefaultStyles styles;
  final DiaryCodeBlockLook code;

  /// 在页面自己的 [config] 上装入样式表。
  ///
  /// 经 `QuillEditorConfig.copyWith`：flutter_quill 11.6.0 的 copyWith 漏掉了
  /// `onSingleLongTap*` 与 `quillMagnifierBuilder`，页面若要用到这几个回调，
  /// 需要先在这里补上（断言兜底，防止被静默丢掉）。
  ///
  /// [firstLineIndentWidth] 已不再使用：首行缩进改为记在块属性上
  /// （[kFirstLineIndentAttribute]），由 AppFlowy 渲染层读取；Quill 页面
  /// 的渲染随编辑器迁移再接入。参数保留以免调用方改动。
  quill.QuillEditorConfig configure(
    quill.QuillEditorConfig config, {
    // ignore: avoid-unused-parameters
    double firstLineIndentWidth = 0,
  }) {
    assert(
      config.onSingleLongTapStart == null &&
          config.onSingleLongTapMoveUpdate == null &&
          config.onSingleLongTapEnd == null &&
          config.quillMagnifierBuilder == null,
      'QuillEditorConfig.copyWith drops these callbacks; pass them here.',
    );
    return config.copyWith(customStyles: styles);
  }
}

/// 在正文所在位置生成 Quill 样式，再交给 [builder] 构建编辑器。
///
/// Quill 的基础样式取自 `DefaultTextStyle`：正文必须在 Material（Scaffold）
/// 之下取 context，那里才是主题正文样式。页面 State 的 context 位于 Scaffold
/// 之上，只能拿到 MaterialApp 的兜底样式（红色、等宽、粗体），直接用它生成
/// 样式会让正文变红，因此各页面一律经本组件生成，不要在页面 build 里直接
/// 调用 [buildDiaryQuillStyles]。主题或正文样式变化时本组件随依赖重建。
///
/// 代码块外观同样在这里解析：本组件自己监听代码块样式设置与导入字体，
/// 变化时自行重建。编辑页缓存了整棵编辑器（按控制器、主题与正文外观判断
/// 是否复用），代码块设置不在它的缓存键里，也能即时生效。
///
/// [builder] 返回的编辑器即为页面正文；代码块的标题栏与高亮由 AppFlowy
/// 块组件负责，不再包渲染层。
class DiaryQuillStylesBuilder extends ConsumerWidget {
  const DiaryQuillStylesBuilder({
    super.key,
    required this.appearance,
    required this.builder,
    this.codeBlockStyle,
    @Deprecated(
      '代码块回车处理已迁至 AppFlowy（handleDiaryCodeBlockEnter），'
      '语言识别改走 EditorState，不再使用',
    )
    this.controller,
    @Deprecated('代码块标题栏已迁至 AppFlowy 块组件，不再使用') this.scrollController,
  });

  final DiaryTextAppearance appearance;
  final Widget Function(BuildContext context, DiaryQuillLook look) builder;

  /// 覆盖代码块样式（设置页的实时预览用草稿）；null 时读已保存的设置
  /// `diaryCodeBlockStyleProvider`。
  final DiaryCodeBlockStyle? codeBlockStyle;

  final quill.QuillController? controller;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = codeBlockStyle;
    final DiaryCodeBlockStyle style =
        override ?? ref.watch(diaryCodeBlockStyleProvider);
    final String? importedFamily;
    if (override == null) {
      importedFamily = ref.watch(diaryCodeBlockFontFamilyProvider);
    } else if (override.usesImportedFont) {
      importedFamily = ref
          .watch(diaryImportedFontFamilyProvider(override.fontId))
          .asData
          ?.value;
    } else {
      importedFamily = null;
    }
    final code = DiaryCodeBlockLook.resolve(
      context,
      style: style,
      appearance: appearance,
      importedFontFamily: importedFamily,
    );
    return builder(
      context,
      DiaryQuillLook(
        styles: buildDiaryQuillStyles(context, appearance, code: code),
        code: code,
      ),
    );
  }
}

/// 由正文外观生成 Quill 样式；编辑页、预览页、发布页与设置预览共用，保证
/// 同一篇日记在写、读、发布时排版一致。
///
/// Quill 的行样式以 `paragraph` 为底（居中、缩进的行也是），标题行只用
/// h1–h6，列表 / 引用 / 代码块再叠加各自样式，因此：
/// - 字体、字号、行距、字间距写入 paragraph 及叠加在它之上的块样式；
/// - 标题只换字体并叠加字间距，保留 Quill 的标题字号与字重；
/// - 代码块与行内代码取 [code]（代码块样式设置：配色、字体、字号倍数、
///   行距、圆角与边框），不沿用 Quill 默认的蓝字灰底与 Android 上并不存在的
///   `Roboto Mono`；
/// - 段间距加在“段落型”行之后：普通行（paragraph 的外边距）以及居中 /
///   缩进块（块内行距与块外边距）；列表项与引用不是段落，保持原有间距。
///
/// 段间距与字间距都在 Quill 默认值上叠加，取 0 时与旧版排版完全一致。
quill.DefaultStyles buildDiaryQuillStyles(
  BuildContext context,
  DiaryTextAppearance appearance, {
  required DiaryCodeBlockLook code,
}) {
  final defaults = quill.DefaultStyles.getInstance(context);
  final typography = appearance.typography;
  final family = appearance.fontFamily;

  TextStyle body(TextStyle style) => style.copyWith(
    fontFamily: family,
    fontSize: typography.fontSize,
    height: typography.lineHeight,
    letterSpacing: typography.letterSpacing,
  );

  TextStyle heading(TextStyle style) => style.copyWith(
    fontFamily: family,
    letterSpacing: (style.letterSpacing ?? 0) + typography.letterSpacing,
  );

  quill.VerticalSpacing afterParagraph(quill.VerticalSpacing spacing) =>
      quill.VerticalSpacing(
        spacing.top,
        spacing.bottom + typography.paragraphSpacing,
      );

  quill.DefaultTextBlockStyle? text(
    quill.DefaultTextBlockStyle? style,
    TextStyle Function(TextStyle) apply,
  ) => style?.copyWith(style: apply(style.style));

  quill.DefaultTextBlockStyle? paragraphBlock(
    quill.DefaultTextBlockStyle? style,
  ) => style?.copyWith(
    style: body(style.style),
    verticalSpacing: afterParagraph(style.verticalSpacing),
    lineSpacing: afterParagraph(style.lineSpacing),
  );

  final paragraph = defaults.paragraph;
  final lists = defaults.lists;
  return quill.DefaultStyles(
    h1: text(defaults.h1, heading),
    h2: text(defaults.h2, heading),
    h3: text(defaults.h3, heading),
    h4: text(defaults.h4, heading),
    h5: text(defaults.h5, heading),
    h6: text(defaults.h6, heading),
    // 独立的普通行只取 paragraph 的外边距（verticalSpacing），lineSpacing 仅
    // 作未知块的兜底，保持默认。
    paragraph: paragraph?.copyWith(
      style: body(paragraph.style),
      verticalSpacing: afterParagraph(paragraph.verticalSpacing),
    ),
    placeHolder: text(defaults.placeHolder, body),
    lists: lists?.copyWith(style: body(lists.style)),
    quote: text(defaults.quote, body),
    code: _quillCodeBlockStyle(code.blockStyle),
    inlineCode: _quillInlineCodeStyle(code.inlineStyle),
    indent: paragraphBlock(defaults.indent),
    align: paragraphBlock(defaults.align),
    leading: text(defaults.leading, body),
    // 行内字号三档（导入笔记带来的 small / large / huge）按正文字号缩放，跟随
    // 用户的排版设置；Quill 默认是与正文无关的固定 10 / 18 / 22。档位划分见
    // journalFontSizeForRatio。
    sizeSmall: TextStyle(fontSize: typography.fontSize * 0.85),
    sizeLarge: TextStyle(fontSize: typography.fontSize * 1.25),
    sizeHuge: TextStyle(fontSize: typography.fontSize * 1.5),
  );
}

/// [DiaryCodeBlockContainerStyle] → Quill 的块样式：供尚未迁移的 Quill
/// 页面与 PDF 导出（flutter_quill 渲染）使用。
quill.DefaultTextBlockStyle _quillCodeBlockStyle(
  DiaryCodeBlockContainerStyle style,
) {
  return quill.DefaultTextBlockStyle(
    style.textStyle,
    quill.HorizontalSpacing.zero,
    quill.VerticalSpacing(style.topMargin, style.bottomMargin),
    quill.VerticalSpacing.zero,
    style.decoration,
  );
}

/// [DiaryCodeInlineStyle] → Quill 的行内代码样式：同上。
quill.InlineCodeStyle _quillInlineCodeStyle(DiaryCodeInlineStyle style) {
  return quill.InlineCodeStyle(
    // 迁移后 style 可空（只读渲染按字阶回落）；Quill 侧仍要求非空，给空样式。
    style: style.style ?? const TextStyle(),
    header1: style.header1,
    header2: style.header2,
    header3: style.header3,
    backgroundColor: style.backgroundColor,
    radius: style.radius,
  );
}
