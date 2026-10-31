import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_code_block/diary_code_block_style.dart';
import '../../../diaries/providers/diary_code_block_style_provider.dart';
import '../../../diaries/providers/diary_preview_style_provider.dart';
import '../../../diaries/providers/diary_typography_provider.dart';
import '../../../diaries/widgets/diary_preview/diary_appflowy_preview.dart';
import '../../controllers/diary_code_block_style_editor_controller.dart';

/// 代码块样式页的实时预览：一段带行内代码的正文、一个明确指定 Python 的
/// 代码块与一个未指定语言（走自动识别）的 JSON 代码块。
///
/// 正文与代码块经 [DiaryAppFlowyPreview] 渲染——与预览页、发布页同一套
/// 只读渲染；代码块样式取编辑中的草稿（[DiaryCodeBlockStyleEditorController.style]，
/// 经 provider 覆盖注入），滑块拖动中即时重绘；正文外观仍取用户的正文排版。
/// 示例文档在首次取到界面语言时建好（引导文字随语言切换重建），只读、不可
/// 交互：预览里不需要光标、选区与复制，也不该抢滚动手势。明暗由标题栏的
/// 按钮单独切换（预览明暗为 null 时跟随应用）。
///
/// AppFlowy 迁移说明：原来经 `DiaryQuillStylesBuilder` + `QuillEditor`
/// 只读渲染；现在直接复用正式页面的 AppFlowy 只读渲染。
class DiaryCodeBlockStylePreview extends ConsumerStatefulWidget {
  const DiaryCodeBlockStylePreview({
    super.key,
    required this.controller,
    this.bottomPadding = 0,
  });

  final DiaryCodeBlockStyleEditorController controller;
  final double bottomPadding;

  @override
  ConsumerState<DiaryCodeBlockStylePreview> createState() =>
      _DiaryCodeBlockStylePreviewState();
}

class _DiaryCodeBlockStylePreviewState
    extends ConsumerState<DiaryCodeBlockStylePreview> {
  Document? _document;
  String? _intro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final intro = context.l10n.codeBlockPreviewIntro;
    if (intro == _intro) {
      return;
    }
    _intro = intro;
    _document = _buildPreviewDocument(intro);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final appTheme = Theme.of(context);
    final brightness = controller.previewBrightness ?? appTheme.brightness;
    final previewTheme = brightness == appTheme.brightness
        ? appTheme
        : SeededThemeCache.of(
            ref.watch(appThemeSeedColorProvider),
            brightness,
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          );
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final document = _document!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ClipRect(
            child: Theme(
              data: previewTheme,
              child: Builder(
                builder: (BuildContext context) {
                  final scheme = Theme.of(context).colorScheme;
                  // Material 提供预览明暗下的 DefaultTextStyle：正文基础样式
                  // 取自它，否则正文颜色会停在应用主题的明暗。
                  return Material(
                    color: ExpressiveSurfaces.pageBackground(scheme),
                    child: SingleChildScrollView(
                      primary: false,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        20 + widget.bottomPadding,
                      ),
                      // 只读、不可交互：不需要光标、选区与复制，也不抢滚动手势。
                      child: IgnorePointer(
                        child: ListenableBuilder(
                          listenable: controller,
                          builder: (BuildContext context, Widget? child) {
                            // 草稿样式覆盖已保存的设置：滑块拖动中即时重绘。
                            return ProviderScope(
                              overrides: [
                                diaryCodeBlockStyleProvider.overrideWith(
                                  () => _DraftCodeBlockStyle(controller.style),
                                ),
                              ],
                              child: DiaryAppFlowyPreview(
                                document: document,
                                appearance: appearance,
                                textSelection: false,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 预览用的草稿样式：把编辑中的草稿固定为 provider 的值。
class _DraftCodeBlockStyle extends DiaryCodeBlockStyleNotifier {
  _DraftCodeBlockStyle(this.style);

  final DiaryCodeBlockStyle style;

  @override
  DiaryCodeBlockStyle build() => style;
}

/// 预览示例文档：引导文字 + 行内代码，Python 代码块（明确语言），JSON 代码块
/// （未指定语言，演示自动识别）。代码本身是语言专有内容，不做本地化。
Document _buildPreviewDocument(String intro) {
  // 每行控制在约 30 个字符内：手机宽度、默认字号下不折行，行号与缩进看得
  // 清楚。
  const python = <String>[
    'def greet(name: str) -> str:',
    '    """Say hello politely."""',
    '    times = 3  # repeat count',
    '    words = ["Hi", name] * times',
    '    return " ".join(words)',
    '',
    'print(greet("Jotsy"))',
  ];
  const json = <String>[
    '{',
    '  "title": "Morning walk",',
    '  "steps": 8421,',
    '  "sunny": true',
    '}',
  ];
  Node codeBlock(List<String> lines, {String? language}) {
    final delta = Delta();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) {
        delta.insert('\n');
      }
      if (lines[i].isNotEmpty) {
        delta.insert(lines[i]);
      }
    }
    return Node(
      type: kDiaryBlockCode,
      attributes: <String, dynamic>{
        kDiaryBlockDeltaKey: delta.toJson(),
        if (language != null) kDiaryBlockLanguageKey: language,
      },
    );
  }

  return Document(
    root: Node(
      type: kDiaryBlockPage,
      children: <Node>[
        Node(
          type: kDiaryBlockParagraph,
          attributes: <String, dynamic>{
            kDiaryBlockDeltaKey:
                (Delta()
                      ..insert(intro)
                      ..insert(
                        'print("hello")',
                        attributes: <String, dynamic>{kDiaryInlineCode: true},
                      ))
                    .toJson(),
          },
        ),
        codeBlock(python, language: 'python'),
        // 块之间空一行（与之前 Quill 文档的段落分隔一致）。
        Node(type: kDiaryBlockParagraph),
        codeBlock(json),
      ],
    ),
  );
}
