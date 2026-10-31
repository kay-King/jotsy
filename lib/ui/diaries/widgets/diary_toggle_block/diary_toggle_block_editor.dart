part of 'diary_toggle_block.dart';

// 折叠块的编辑器组件：标题行（箭头 + 可编辑文本）与展开时的子块。

/// 编辑器用的折叠块组件构建器。
class DiaryToggleBlockComponentBuilder extends BlockComponentBuilder {
  DiaryToggleBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryToggleBlockComponent(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class _DiaryToggleBlockComponent extends BlockComponentStatefulWidget {
  const _DiaryToggleBlockComponent({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<_DiaryToggleBlockComponent> createState() =>
      _DiaryToggleBlockComponentState();
}

class _DiaryToggleBlockComponentState extends State<_DiaryToggleBlockComponent>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'diary_toggle_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: 'diary_toggle_block',
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  EditorState get editorState =>
      context.findAncestorWidgetOfExactType<AppFlowyEditor>()!.editorState;

  /// 是否收起：认不出的值按展开处理。
  bool get collapsed => node.attributes[kDiaryToggleCollapsedKey] == true;

  @override
  Widget build(BuildContext context) {
    final titleOnly = collapsed || node.children.isEmpty;
    return Padding(
      padding: configuration.margin(node),
      child: titleOnly
          ? _buildTitle(context)
          : NestedListWidget(
              indentPadding: configuration.indentPadding(
                node,
                Directionality.of(context),
              ),
              child: _buildTitle(context),
              children: editorState.renderer.buildList(context, node.children),
            ),
    );
  }

  /// 标题行：左侧展开/收起箭头 + 右侧可编辑文本。
  Widget _buildTitle(BuildContext context) {
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );
    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          _ToggleArrow(
            collapsed: collapsed,
            onTap: _toggleCollapsed,
            // 箭头盒子与首行行高等高、图标居中，即与首行文字对齐。
            height: _firstLineHeight(),
          ),
          Flexible(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: placeholderText,
              textDirection: textDirection,
              textSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(textStyleWithTextSpan()),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(
                    placeholderTextStyleWithTextSpan(textSpan: textSpan),
                  ),
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ],
      ),
    );

    child = Container(
      decoration: decoration,
      key: blockComponentKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }

  double _firstLineHeight() {
    final config = editorState.editorStyle.textStyleConfiguration;
    return (config.text.fontSize ?? 16.0) * config.lineHeight;
  }

  /// 点箭头翻转 `collapsed`：updateNode 合并属性（delta 不动）并支持撤销；
  /// 不更新选区，光标留在标题行里继续打字。
  void _toggleCollapsed() {
    final transaction = editorState.transaction
      ..updateNode(node, <String, dynamic>{
        kDiaryToggleCollapsedKey: !collapsed,
      });
    unawaited(editorState.apply(transaction, withUpdateSelection: false));
  }
}

/// 展开/收起小箭头：只响应自己的点按，不抢标题的文本选择。
/// 编辑器与只读预览共用。
class _ToggleArrow extends StatelessWidget {
  const _ToggleArrow({
    required this.collapsed,
    required this.onTap,
    required this.height,
  });

  final bool collapsed;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 26),
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 4),
            child: AnimatedSwitcher(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: FaIcon(
                collapsed
                    ? FontAwesomeIcons.caretRight
                    : FontAwesomeIcons.caretDown,
                key: ValueKey<bool>(collapsed),
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
