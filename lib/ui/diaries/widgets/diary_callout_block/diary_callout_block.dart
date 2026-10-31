import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';

/// v0.10.0 提示块（callout）：带 emoji 图标的彩色块，6 档底色。
///
/// 当前 appflowy_editor 版本（01eccc6）没有原生 callout block，这里自定义实现：
/// 块类型 `diaryCalloutBlock`，正文存标准 delta，属性 `backgroundColor`（颜色
/// key，见 [kDiaryCalloutColors]）、`icon`（emoji 字符串）。

/// 块类型标识。
const String kDiaryCalloutBlockType = 'diaryCalloutBlock';

/// 背景色属性 key（值为颜色 key，如 'yellow'）。
const String kDiaryCalloutBackgroundKey = 'backgroundColor';

/// 图标属性 key（emoji 字符串）。
const String kDiaryCalloutIconKey = 'icon';

/// 6 档底色（与上游 v0.10.0 对齐）。
const List<String> kDiaryCalloutColors = <String>[
  'yellow',
  'green',
  'blue',
  'purple',
  'pink',
  'gray',
];

/// 图标菜单里的 6 个常用 emoji（默认第一个）。
const List<String> _kCalloutEmojis = <String>['💡', '⭐', '⚠️', '✅', '📌', '❤️'];

/// 每档底色的鲜明色（上游 v0.10.0 同为彩色块）：块底色按亮/暗主题罩不同透明度，
/// 色板圆点直接用鲜明色。
const Map<String, Color> _kCalloutSwatches = <String, Color>{
  'yellow': Color(0xFFE8A800),
  'green': Color(0xFF43A047),
  'blue': Color(0xFF1E88E5),
  'purple': Color(0xFF8E24AA),
  'pink': Color(0xFFEC407A),
  'gray': Color(0xFF9AA0A6),
};

Color _calloutBackgroundColor(String key, Brightness brightness) =>
    (_kCalloutSwatches[key] ?? _kCalloutSwatches['yellow']!).withValues(
      alpha: brightness == Brightness.dark ? 0.28 : 0.16,
    );

/// 在光标处插入提示块（默认黄底 + 💡，正文为空 delta；空段落处替换，否则插下一行）。
Future<void> insertDiaryCalloutBlock(EditorState editorState) async {
  await insertNodeAfterSelection(
    editorState,
    Node(
      type: kDiaryCalloutBlockType,
      attributes: <String, dynamic>{
        blockComponentDelta: (Delta()..insert('')).toJson(),
        kDiaryCalloutBackgroundKey: kDiaryCalloutColors.first,
        kDiaryCalloutIconKey: _kCalloutEmojis.first,
      },
    ),
  );
}

/// 编辑器用的提示块组件。
class DiaryCalloutBlockComponentBuilder extends BlockComponentBuilder {
  DiaryCalloutBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryCalloutBlockWidget(
      key: node.key,
      node: node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class _DiaryCalloutBlockWidget extends BlockComponentStatefulWidget {
  const _DiaryCalloutBlockWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<_DiaryCalloutBlockWidget> createState() =>
      _DiaryCalloutBlockWidgetState();
}

class _DiaryCalloutBlockWidgetState extends State<_DiaryCalloutBlockWidget>
    with SelectableMixin, DefaultSelectableMixin, BlockComponentConfigurable {
  @override
  final forwardKey = GlobalKey(debugLabel: 'flowy_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: kDiaryCalloutBlockType,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  late final editorState = Provider.of<EditorState>(context, listen: false);

  /// 图标 / 底色都写进 node attributes：经 editorState 的 transaction
  /// updateNode 合并指定 key（不碰 delta），支持撤销。
  Future<void> _updateAttribute(String key, Object value) async {
    final transaction = editorState.transaction;
    transaction.updateNode(node, <String, dynamic>{key: value});
    await editorState.apply(transaction);
  }

  /// 左侧 emoji：点按弹出 6 个常用 emoji 切换。
  Widget _buildIconMenu(String icon) => ExpressiveMenuAnchor(
    placement: ExpressiveMenuPlacement.start,
    menuChildren: <Widget>[
      for (final emoji in _kCalloutEmojis)
        ExpressiveMenuItem(
          onPressed: () => _updateAttribute(kDiaryCalloutIconKey, emoji),
          selected: emoji == icon,
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
    ],
    builder: (context, menu, _) => GestureDetector(
      onTap: menu.toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(icon, style: const TextStyle(fontSize: 20)),
      ),
    ),
  );

  /// 块内小调色按钮：点按弹出 6 档底色切换。
  Widget _buildColorMenu(String colorKey) => ExpressiveMenuAnchor(
    placement: ExpressiveMenuPlacement.end,
    menuChildren: <Widget>[
      for (final key in kDiaryCalloutColors)
        ExpressiveMenuItem(
          onPressed: () => _updateAttribute(kDiaryCalloutBackgroundKey, key),
          selected: key == colorKey,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: _kCalloutSwatches[key],
          ),
        ),
    ],
    builder: (context, menu, _) => GestureDetector(
      onTap: menu.toggle,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FaIcon(
          FontAwesomeIcons.palette,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundKey =
        node.attributes[kDiaryCalloutBackgroundKey] as String? ??
        kDiaryCalloutColors.first;
    final icon =
        node.attributes[kDiaryCalloutIconKey] as String? ??
        _kCalloutEmojis.first;

    // 底色切换走 AnimatedContainer（时长/曲线取 ExpressiveMotion token）。
    Widget child = AnimatedContainer(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      decoration: BoxDecoration(
        color: _calloutBackgroundColor(backgroundKey, theme.brightness),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildIconMenu(icon),
          const SizedBox(width: 8),
          Expanded(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: node,
              editorState: editorState,
              textAlign: textAlign,
              placeholderText: placeholderText,
              textSpanDecorator: (span) =>
                  span.updateTextStyle(textStyleWithTextSpan(textSpan: span)),
              placeholderTextSpanDecorator: (span) => span.updateTextStyle(
                placeholderTextStyleWithTextSpan(textSpan: span),
              ),
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
          const SizedBox(width: 4),
          _buildColorMenu(backgroundKey),
        ],
      ),
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const <BlockSelectionType>[BlockSelectionType.block],
      child: child,
    );

    // 与 DiaryDividerEmbedBuilder 同口径：自定义小块不接桌面拖拽 handle。
    return Padding(padding: margin, child: child);
  }
}

/// 预览页用的提示块渲染（只读）：与编辑器同布局，无菜单、不可编辑。
class DiaryCalloutBlockPreview extends StatelessWidget {
  const DiaryCalloutBlockPreview({
    super.key,
    required this.node,
    required this.textStyle,
  });

  final Node node;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundKey =
        node.attributes[kDiaryCalloutBackgroundKey] as String? ??
        kDiaryCalloutColors.first;
    final icon =
        node.attributes[kDiaryCalloutIconKey] as String? ??
        _kCalloutEmojis.first;
    return Container(
      decoration: BoxDecoration(
        color: _calloutBackgroundColor(backgroundKey, theme.brightness),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(_calloutDeltaSpan(node.delta, textStyle))),
        ],
      ),
    );
  }
}

/// 预览把 delta 转成 TextSpan：只还原加粗/斜体（与 diary_appflowy_preview 的
/// _buildDeltaSpan 同口径的精简版，提示块正文极少用其他行内格式）。
TextSpan _calloutDeltaSpan(Delta? delta, TextStyle base) {
  TextStyle opStyle(TextInsert op) {
    final attributes = op.attributes;
    return TextStyle(
      fontWeight: attributes?['bold'] == true ? FontWeight.bold : null,
      fontStyle: attributes?['italic'] == true ? FontStyle.italic : null,
    );
  }

  final children = <InlineSpan>[
    for (final op in delta ?? Delta())
      if (op is TextInsert) TextSpan(text: op.text, style: opStyle(op)),
  ];
  // 空块也要占一行高度，避免被压掉。
  if (children.isEmpty) return TextSpan(text: ' ', style: base);
  return TextSpan(style: base, children: children);
}
