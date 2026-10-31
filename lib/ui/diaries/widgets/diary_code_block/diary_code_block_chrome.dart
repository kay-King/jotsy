import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../controllers/diary_code_block_editing.dart';
import '../../controllers/diary_code_language_tracker.dart';
import '../../providers/diary_code_block_style_provider.dart';
import '../../providers/diary_typography_provider.dart';
import '../../viewmodels/diary_code_block_look.dart';
import '../../viewmodels/diary_code_span_builder.dart';
import 'diary_code_block_header_geometry.dart';
import 'diary_code_block_header_painter.dart';

// 代码块的 AppFlowy 块组件：标题栏（语言名 + 复制）+ 代码正文。
//
// 输入：块上下文的节点（type 为 `code`，整块代码记在 `data.delta` 里，
// 语言记在 `data.language` 上）；外观在正文位置解析（代码块样式设置 +
// 正文排版 + 导入字体），语言识别经该 EditorState 的
// [DiaryCodeLanguageTracker]（与高亮、工具栏面板共用同一份结果）。
// 输出：标题栏 + 装饰容器 + 行号 + 可编辑的高亮代码。
// 副作用：复制写系统剪贴板并提示；识别结果变化、文档改写时重建。
//
// AppFlowy 迁移说明：原来标题栏是包在 QuillEditor 外的渲染层
// （RenderDiaryCodeBlockChrome），从 Quill 渲染树读几何；AppFlowy 时代
// 标题栏是块组件里的 widget，直接画在代码块上方。增量高亮、语言识别与
// 标题栏文案逻辑不变，只换了承载机制。

/// 代码块的块组件构建器；注册到 `code` 类型节点的渲染器。
class DiaryCodeBlockComponentBuilder extends BlockComponentBuilder {
  DiaryCodeBlockComponentBuilder();

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryCodeBlockComponent(key: node.key, node: node);
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class _DiaryCodeBlockComponent extends ConsumerStatefulWidget
    with BlockComponentWidget {
  const _DiaryCodeBlockComponent({
    super.key,
    required this.node,
    // ignore: unused_element_parameter
    this.configuration = const BlockComponentConfiguration(),
    // ignore: unused_element_parameter
    this.showActions = false,
    // ignore: unused_element_parameter
    this.actionBuilder,
    // ignore: unused_element_parameter
    this.actionTrailingBuilder,
  });

  @override
  final Node node;

  @override
  final BlockComponentConfiguration configuration;

  @override
  final bool showActions;

  @override
  final BlockComponentActionBuilder? actionBuilder;

  @override
  final BlockComponentActionTrailingBuilder? actionTrailingBuilder;

  @override
  ConsumerState<_DiaryCodeBlockComponent> createState() =>
      _DiaryCodeBlockComponentState();
}

class _DiaryCodeBlockComponentState
    extends ConsumerState<_DiaryCodeBlockComponent>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin {
  // 注：不用 NestedBlockComponentStatefulWidgetMixin——它的类型参数要求
  // widget 继承 BlockComponentStatefulWidget，而这里是 ConsumerStatefulWidget
  //（需要 ref 读代码块样式）。代码块没有嵌套子块，mixin 提供的缩进/子块
  // 能力用不上；块边距仍经 configuration.margin 处理。
  @override
  final forwardKey = GlobalKey(debugLabel: 'diary_code_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: 'diary_code_block',
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  /// 复制后对勾停留的时长（与只读渲染一致；非动画计时，不走
  /// ExpressiveMotion）。
  static const Duration _copiedDuration = Duration(milliseconds: 1500);

  late final DiaryCodeLanguageTracker _tracker;
  StreamSubscription<EditorTransactionValue>? _transactions;
  DiaryCodeBlockHeaderPainter? _headerPainter;
  bool _copied = false;
  Timer? _resetCopied;

  @override
  void initState() {
    super.initState();
    _tracker = DiaryCodeLanguageTracker.of(editorState)
      ..addListener(_onTrackerChanged);
    // transactionStream 是同步广播流：重建行号与高亮。apply 可能发生在
    // 构建阶段（编辑器纠正选区），那时推到帧末再 setState。
    _transactions = editorState.transactionStream.listen((_) {
      if (!mounted) {
        return;
      }
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
        return;
      }
      setState(() {});
    });
  }

  /// 自动识别的语言变了：标题栏文案与高亮都要换新的结果，重建。
  void _onTrackerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _transactions?.cancel();
    _tracker.removeListener(_onTrackerChanged);
    _resetCopied?.cancel();
    _headerPainter?.dispose();
    super.dispose();
  }

  /// 所在编辑器的状态：上游块组件经 provider 包的 `Provider.of` 取，这里不
  /// 直接依赖 provider 包（pubspec 未声明），改为从祖先的 [AppFlowyEditor]
  /// widget 上读——[AppFlowyEditor] 持有同一个 [EditorState]。
  EditorState get editorState {
    final editor = context.findAncestorWidgetOfExactType<AppFlowyEditor>();
    assert(
      editor != null,
      'DiaryCodeBlockComponent must be built inside an AppFlowyEditor.',
    );
    return editor!.editorState;
  }

  Future<void> _copy() async {
    try {
      await copyDiaryCodeBlock(node);
    } on PlatformException {
      // 剪贴板不可用：不提示成功、不换对勾。
      return;
    }
    if (!mounted) {
      return;
    }
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
    _resetCopied = Timer(_copiedDuration, () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 块边距：与其它块组件一致，外层留出 configuration.margin。
    return Padding(
      padding: configuration.margin(node),
      child: _buildComponent(context),
    );
  }

  Widget _buildComponent(BuildContext context) {
    final look = DiaryCodeBlockLook.resolve(
      context,
      style: ref.watch(diaryCodeBlockStyleProvider),
      appearance: ref.watch(diaryTextAppearanceProvider),
      importedFontFamily: ref.watch(diaryCodeBlockFontFamilyProvider),
    );
    return Padding(
      // 上外边距里留出标题栏的位置（与只读渲染一致）。
      padding: EdgeInsets.only(
        top: look.blockStyle.topMargin,
        bottom: look.blockStyle.bottomMargin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (look.header) _buildHeader(context, look),
          _buildBody(context, look),
        ],
      ),
    );
  }

  /// 标题栏：语言名 + 右侧复制按钮（复用只读渲染同一套绘制）。
  Widget _buildHeader(BuildContext context, DiaryCodeBlockLook look) {
    final l10n = context.l10n;
    final text = describeDiaryCodeBlockHeader(
      node,
      autoDetect: look.autoDetect,
      tracker: _tracker,
      l10n: l10n,
    );
    final theme = Theme.of(context);
    // 标题栏高度固定，限制系统字号的放大倍数，语言名不至于撑出标题栏。
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 2);
    final labelStyle = (theme.textTheme.labelMedium ?? const TextStyle())
        .copyWith(fontSize: 12, fontWeight: FontWeight.w600);
    final painter = _headerPainter ??= DiaryCodeBlockHeaderPainter(
      palette: look.palette,
      radius: look.style.radius,
      border: look.style.border,
      labelStyle: labelStyle,
      textScaler: textScaler,
    );
    // 主题/设置变化时更新绘制参数（缓存的文字排版一并失效）。
    painter.update(
      palette: look.palette,
      radius: look.style.radius,
      border: look.style.border,
      labelStyle: labelStyle,
      textScaler: textScaler,
    );
    return SizedBox(
      height: DiaryCodeBlockLook.headerHeight,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _HeaderPainter(
                painter: painter,
                label: text.label,
                copied: _copied,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: DiaryCodeBlockHeaderPainter.copyHitWidth,
            // 复制按钮并入输入框的点按组：点它不算点到输入框外面，桌面与
            // 鼠标/手写笔点按时不会收起焦点（Quill 时代同理）。
            child: TextFieldTapRegion(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_copy()),
                child: Semantics(
                  button: true,
                  label: text.semanticsLabel,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 代码正文：装饰容器 + 行号 + 可编辑的高亮文本。
  Widget _buildBody(BuildContext context, DiaryCodeBlockLook look) {
    final codeTextStyle = look.codeTextStyle;
    final text = node.delta?.toPlainText() ?? '';
    final lineCount = text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;
    return Container(
      decoration: look.blockStyle.decoration,
      // 主体内容区上下 16dp 内边距（与只读渲染一致）。
      padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (look.lineNumbers)
            SizedBox(
              width: _numberGutterWidth(
                codeTextStyle.fontSize ?? 16,
                lineCount,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < lineCount; i++)
                    Text(
                      '${i + 1}',
                      style: codeTextStyle.copyWith(
                        color: look.palette.lineNumber,
                      ),
                    ),
                ],
              ),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: node,
              editorState: editorState,
              placeholderText: ' ',
              placeholderTextSpanDecorator: (span) =>
                  span.updateTextStyle(codeTextStyle),
              textSpanDecorator: (span) => buildDiaryCodeSpan(
                span,
                node: node,
                look: look,
                tracker: _tracker,
              ),
              // 代码始终从左到右（标题栏同理）。
              textDirection: TextDirection.ltr,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ],
      ),
    );
  }
}

/// 行号列宽：两位数以内两个字宽（与只读渲染一致）。
double _numberGutterWidth(double fontSize, int count) {
  final length = '$count'.length;
  if (length <= 2) return fontSize * 2;
  return fontSize * (length - (length - 2) / 2);
}

class _HeaderPainter extends CustomPainter {
  _HeaderPainter({
    required this.painter,
    required this.label,
    required this.copied,
  });

  final DiaryCodeBlockHeaderPainter painter;
  final String label;
  final bool copied;

  @override
  void paint(Canvas canvas, Size size) {
    painter.paint(canvas, Offset.zero & size, label: label, copied: copied);
  }

  @override
  bool shouldRepaint(_HeaderPainter oldDelegate) {
    return oldDelegate.label != label || oldDelegate.copied != copied;
  }
}
