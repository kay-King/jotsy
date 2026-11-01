import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/providers/diary_saved_colors_provider.dart';
import '../../diaries/providers/diary_typography_provider.dart';
import '../../diaries/viewmodels/diary_text_appearance.dart';
import '../../diaries/widgets/diary_divider_embed_builder.dart';
import '../../diaries/widgets/diary_floating_toolbar_surface.dart';
import '../../diaries/widgets/diary_mobile_toolbar.dart';
import '../controllers/diary_template_editor_controller.dart';
import '../widgets/diary_template_variable_bar.dart';

/// 模板编辑页的“内容”标签：标题格式、插入变量条与正文。
///
/// 正文是独立的 AppFlowy 编辑器（自带滚动），不走日记编辑页的光标跟随机制；
/// 只允许文字与分隔线（模板规则），块组件用标准文本块 + 日记的分隔线渲染。
/// 键盘弹起且正文有焦点时（打开“始终显示工具栏”后一直），底部显示与日记
/// 编辑页同一套悬浮工具栏，但去掉图片、视频、附件、录音与插入时间——模板
/// 里不能有媒体，时间应当用变量。
///
/// 变量插到最后一个获得焦点的输入框（标题或正文）的光标处；变量面板会抢走
/// 焦点，插入后把焦点还回去。
class DiaryTemplateEditorContentTab extends ConsumerStatefulWidget {
  const DiaryTemplateEditorContentTab({
    super.key,
    required this.controller,
    required this.keyboardVisible,
  });

  final DiaryTemplateEditorController controller;

  /// 软键盘是否弹起。由页面在 Scaffold 之上读取：Scaffold 会把键盘高度从
  /// body 的 MediaQuery 里扣掉，这里读不到。
  final bool keyboardVisible;

  /// 模板正文工具栏里不出现的工具。
  static const Set<DiaryToolbarItem> excludedToolbarItems = <DiaryToolbarItem>{
    DiaryToolbarItem.image,
    DiaryToolbarItem.video,
    DiaryToolbarItem.attachment,
    DiaryToolbarItem.recording,
    DiaryToolbarItem.currentTime,
  };

  @override
  ConsumerState<DiaryTemplateEditorContentTab> createState() =>
      _DiaryTemplateEditorContentTabState();
}

class _DiaryTemplateEditorContentTabState
    extends ConsumerState<DiaryTemplateEditorContentTab> {
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _bodyFocus = FocusNode();
  // 包住悬浮工具栏，自身不可获得焦点：颜色面板的颜色代码输入框拿到焦点时
  // 正文失焦，工具栏仍须留着，否则输入框随之卸载。
  final FocusNode _toolbarFocus = FocusNode(
    debugLabel: 'template-floating-toolbar',
    canRequestFocus: false,
    skipTraversal: true,
  );
  bool _lastFocusedBody = true;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_trackFocus);
    _bodyFocus.addListener(_trackFocus);
    _toolbarFocus.addListener(_trackFocus);
  }

  void _trackFocus() {
    if (_titleFocus.hasFocus) _lastFocusedBody = false;
    if (_bodyFocus.hasFocus) _lastFocusedBody = true;
    // 工具栏只在正文（或工具栏里的输入框）有焦点时出现。
    setState(() {});
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _toolbarFocus.dispose();
    super.dispose();
  }

  Future<void> _insert(String token) async {
    if (_lastFocusedBody) {
      await _insertToken(widget.controller.body, token);
      _bodyFocus.requestFocus();
      return;
    }
    final title = widget.controller.titlePattern;
    final text = title.text;
    final selection = title.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    title.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _titleFocus.requestFocus();
  }

  List<DiaryToolbarItem> _toolbarOrder(SettingsService? settings) {
    final order = decodeDiaryToolbarOrder(settings?.diaryToolbarOrderRaw);
    final hidden = decodeDiaryToolbarHiddenItems(
      settings?.diaryToolbarHiddenItemsRaw,
    );
    return filterEnabledDiaryToolbarOrder(order, hidden)
        .where(
          (item) => !DiaryTemplateEditorContentTab.excludedToolbarItems
              .contains(item),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final titleStyle = appearance.titleStyle(theme.textTheme.headlineSmall);
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    final order = _toolbarOrder(settings);
    // 焦点在工具栏内（颜色代码输入框）时不看键盘：交接焦点时输入法可能先收起
    // 再弹出，键盘短暂消失也不能卸载工具栏（与日记编辑页同一口径）。打开
    // “始终显示工具栏”后不看键盘与焦点，接实体键盘时也能排版。
    final alwaysVisible = settings?.isDiaryToolbarAlwaysVisible ?? false;
    final showToolbar =
        (alwaysVisible ||
            (widget.keyboardVisible && _bodyFocus.hasFocus) ||
            _toolbarFocus.hasFocus) &&
        order.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: TextField(
            controller: widget.controller.titlePattern,
            focusNode: _titleFocus,
            style: titleStyle,
            maxLength: 200,
            buildCounter:
                (
                  BuildContext context, {
                  required int currentLength,
                  required bool isFocused,
                  int? maxLength,
                }) => null,
            decoration: InputDecoration(
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
              hintText: l10n.diaryTemplateEditorTitleHint,
              hintStyle: titleStyle?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        DiaryTemplateVariableBar(
          onInsert: (token) => unawaited(_insert(token)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: AppFlowyEditor(
              editorState: widget.controller.body,
              focusNode: _bodyFocus,
              autoFocus: false,
              editorStyle: _editorStyle(context, appearance),
              blockComponentBuilders: _blockBuilders(
                paragraphSpacing: appearance.typography.paragraphSpacing,
                hint: l10n.diaryTemplateEditorBodyHint,
              ),
              // 旧 Quill 编辑器没有 Markdown 快捷输入（如 `---` 变分隔线）：
              // 模板里只留工具栏显式排版，输入时不意外变形。
              characterShortcutEvents: const [],
            ),
          ),
        ),
        if (showToolbar)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kDiaryFloatingToolbarInset,
              0,
              kDiaryFloatingToolbarInset,
              AppSpacing.s,
            ),
            child: DiaryFloatingToolbarSurface(
              child: Focus(
                focusNode: _toolbarFocus,
                child: DiaryFloatingToolbar(
                  editorState: widget.controller.body,
                  order: order,
                  maxPanelExtent: MediaQuery.sizeOf(context).height / 3,
                  savedColors: ref.watch(diarySavedColorsProvider),
                  onEditSavedColors: ref
                      .read(diarySavedColorsProvider.notifier)
                      .edit,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 变量插到正文选区：有选中范围时先删掉再插入（与旧 Quill `replaceText`
/// 同效果）；选区落在分隔线等非文本块时退到最后一个文本块末尾。
Future<void> _insertToken(EditorState editorState, String token) async {
  final selection = editorState.selection?.normalized;
  Node? node = selection == null
      ? null
      : editorState.getNodeAtPath(selection.start.path);
  var index = selection?.start.offset ?? 0;
  if (node?.delta == null) {
    node = _lastTextNode(editorState);
    index = node?.delta?.length ?? 0;
  }
  final target = node;
  if (target == null) return;
  final length = target.delta?.length ?? 0;
  index = index.clamp(0, length);
  final transaction = editorState.transaction;
  if (selection != null &&
      !selection.isCollapsed &&
      selection.start.path.equals(selection.end.path)) {
    final start = selection.start.offset.clamp(0, length);
    final end = selection.end.offset.clamp(0, length);
    if (end > start) {
      transaction.deleteText(target, start, end - start);
      index = start;
    }
  }
  transaction.insertText(target, index, token);
  await editorState.apply(transaction);
}

/// 文档里最后一个带文字的块（变量插入的退路）。
Node? _lastTextNode(EditorState editorState) {
  Node? result;
  void visit(Node node) {
    if (node.delta != null) result = node;
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(editorState.document.root);
  return result;
}

/// 模板正文的编辑器样式：字体、字号、行距、字间距跟随正文排版设置
///（[DiaryTextAppearance]），与 Quill 时代的模板编辑器同口径。
EditorStyle _editorStyle(BuildContext context, DiaryTextAppearance appearance) {
  final theme = Theme.of(context);
  final typography = appearance.typography;
  return EditorStyle.mobile(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
    cursorColor: theme.colorScheme.primary,
    selectionColor: theme.colorScheme.primaryContainer,
    textStyleConfiguration: TextStyleConfiguration(
      text: TextStyle(
        color: theme.colorScheme.onSurface,
        fontFamily: appearance.fontFamily,
        fontSize: typography.fontSize,
        height: typography.lineHeight,
        letterSpacing: typography.letterSpacing,
      ),
      lineHeight: typography.lineHeight,
      href: TextStyle(
        color: theme.colorScheme.secondary,
        decoration: TextDecoration.underline,
      ),
    ),
    // 模板的字号档位（small / large / huge）是本应用自定义的行内属性，
    // 在这里换算；其余行内格式（加粗/颜色/链接等）走编辑器内置渲染。
    textSpanDecorator: _diaryTemplateTextSpanDecorator(typography.fontSize),
  );
}

/// 行内 `size` 属性 → 字号：三档按正文字号缩放，数字按绝对字号（与只读
/// 预览的 `_inlineFontSize` 同口径）。
TextSpanDecoratorForAttribute _diaryTemplateTextSpanDecorator(
  double baseFontSize,
) {
  return (
    BuildContext context,
    Node node,
    int index,
    TextInsert text,
    TextSpan before,
    TextSpan after,
  ) {
    final decorated = defaultTextSpanDecoratorForAttribute(
      context,
      node,
      index,
      text,
      before,
      after,
    );
    final fontSize = switch (text.attributes?[kDiaryInlineSize]) {
      'small' => baseFontSize * 0.85,
      'large' => baseFontSize * 1.25,
      'huge' => baseFontSize * 1.5,
      num _ => (text.attributes?[kDiaryInlineSize] as num).toDouble(),
      _ => null,
    };
    if (fontSize == null) return decorated;
    return decorated.copyWith(
      style: (decorated.style ?? const TextStyle()).copyWith(
        fontSize: fontSize,
      ),
    );
  };
}

/// 模板正文的块组件：标准文本块 + 日记的分隔线渲染。
///
/// 段落（标题、列表、引用、待办同理）底部追加段间距，与 Quill 时代
/// `verticalSpacing.bottom` 同效果；空段落显示正文输入提示。
Map<String, BlockComponentBuilder> _blockBuilders({
  required double paragraphSpacing,
  required String hint,
}) {
  final configuration = BlockComponentConfiguration(
    padding: (node) => EdgeInsets.only(top: 4, bottom: 4 + paragraphSpacing),
    placeholderText: (node) => hint,
  );
  return <String, BlockComponentBuilder>{
    ...standardBlockComponentBuilderMap,
    kDiaryBlockParagraph: ParagraphBlockComponentBuilder(
      configuration: configuration,
    ),
    kDiaryBlockHeading: HeadingBlockComponentBuilder(
      configuration: configuration,
    ),
    kDiaryBlockBulletedList: BulletedListBlockComponentBuilder(
      configuration: configuration,
    ),
    kDiaryBlockNumberedList: NumberedListBlockComponentBuilder(
      configuration: configuration,
    ),
    kDiaryBlockTodoList: TodoListBlockComponentBuilder(
      configuration: configuration,
    ),
    kDiaryBlockQuote: QuoteBlockComponentBuilder(configuration: configuration),
    kDiaryBlockDivider: DiaryDividerEmbedBuilder(),
  };
}
