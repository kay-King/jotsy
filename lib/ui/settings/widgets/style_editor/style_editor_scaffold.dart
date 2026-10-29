import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';

/// 样式编辑页（卡片样式、预览页样式、代码块样式、导航栏样式）共用的页面外壳。
///
/// 全屏实时预览：预览占满整个屏幕，所有控制按钮都悬浮在预览上、不占固定位置。
/// - 左上角悬浮菜单按钮：点开展开菜单（页面标题、返回、重置）；
/// - 顶部悬浮预览工具条：各页自定（如列表/瀑布流切换、页码点、明暗切换），与
///   菜单按钮同行；
/// - 底部悬浮分类按钮：一排独立小按钮，点一个弹 BottomSheet（Salt 白卡）显示
///   该分类的选项，改动即时生效、关掉即可。
///
/// 标签页之间没有横滑：选项直接按分类进 BottomSheet。状态与写入由各页的编辑
/// 控制器负责（[listenable]），外壳只管布局。
class StyleEditorScaffold extends StatelessWidget {
  const StyleEditorScaffold({
    super.key,
    required this.title,
    required this.listenable,
    required this.isDefault,
    required this.onReset,
    required this.tabs,
    required this.tabViews,
    this.toolbarBuilder,
    this.actionsBuilder,
    required this.previewBuilder,
  });

  final String title;

  /// 编辑控制器：变化时重建工具条、预览、选项与“重置”按钮。
  final Listenable listenable;
  final bool Function() isDefault;
  final VoidCallback onReset;
  final List<String> tabs;
  final List<Widget> Function() tabViews;

  /// 悬浮在预览顶部的工具条（与菜单按钮同行）；为 null 时这一段只留菜单按钮。
  /// 必须在监听回调内重新创建；复用同一个 Widget 会跳过重建，让选中态与捕获
  /// 旧明暗值的按钮回调滞留到页面因其他交互重建时才刷新。
  final WidgetBuilder? toolbarBuilder;

  /// 悬浮在预览顶部、排在工具条之后的操作按钮（如预览明暗）。随 [listenable]
  /// 重建，理由同 [toolbarBuilder]。
  final List<Widget> Function(BuildContext context)? actionsBuilder;

  /// 实时预览：[showToolbar] 恒为 false（工具条已悬浮在顶部）；[bottomPadding]
  /// 为底部悬浮按钮条预留的高度，预览末尾多留这段、内容不被按钮条盖住。
  final Widget Function({
    required bool showToolbar,
    required double bottomPadding,
  })
  previewBuilder;

  /// 底部悬浮按钮条给预览预留的高度。
  static const double _bottomBarReserve = 76;

  /// 点分类按钮：弹 BottomSheet 显示该分类的选项（Salt 白卡）。
  ///
  /// 各 tab 页内部的选项逻辑一点不动，只是换了个入口。
  Future<void> _openTabSheet(BuildContext context, int index) {
    final label = tabs[index];
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final size = MediaQuery.sizeOf(sheetContext);
        final l10n = sheetContext.l10n;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width >= 720 ? 640 : double.infinity,
            ),
            // sheet 里包自己的 ScaffoldMessenger + Scaffold：各 tab 页经
            // showStyleEditorUndoSnackBar 弹的提示（套用、重置、导入等）走
            // 最近的 messenger，显示在 sheet 内部；否则会被底下的页面
            // Scaffold 接住、藏在 modal 遮罩后面看不见、点不到。
            child: ScaffoldMessenger(
              child: Scaffold(
                backgroundColor: Theme.of(
                  sheetContext,
                ).colorScheme.surface,
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: SizedBox(
                      height: size.height * 0.78,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  label,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.commonClose,
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // tab 页内部不自己监听控制器：包一层 ListenableBuilder，
                          // 控制器变化时重建该分类的选项（与原来 TabBarView 在
                          // ListenableBuilder 里重建 tabViews() 一致）。
                          Expanded(
                            child: ListenableBuilder(
                              listenable: listenable,
                              builder: (BuildContext _, Widget? __) =>
                                  tabViews()[index],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 左上角悬浮菜单按钮：返回、标题、重置都收进菜单，点开显示。
  Widget _menuButton(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      elevation: 2,
      child: ExpressiveMenuButton(
        tooltip: title,
        icon: const Icon(Icons.more_vert),
        placement: ExpressiveMenuPlacement.start,
        items: <Widget>[
          // 标题不可点，只起标识作用。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ExpressiveMenuItem(
            onPressed: () => Navigator.of(context).maybePop(),
            leadingIcon: const FaIcon(FontAwesomeIcons.angleLeft),
            child: Text(l10n.commonBack),
          ),
          ExpressiveMenuItem(
            onPressed: isDefault() ? null : onReset,
            leadingIcon: const FaIcon(FontAwesomeIcons.arrowRotateLeft),
            child: Text(l10n.commonReset),
          ),
        ],
      ),
    );
  }

  /// 底部悬浮分类按钮条：独立小按钮横排，超宽时可横滑。
  Widget _tabButtonBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < tabs.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openTabSheet(context, i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      tabs[i],
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: listenable,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              // 全屏预览。
              Positioned.fill(
                child: previewBuilder(
                  showToolbar: false,
                  bottomPadding: _bottomBarReserve,
                ),
              ),
              // 顶部悬浮：菜单按钮 + 预览工具条 + 操作按钮。
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: <Widget>[
                        _menuButton(context),
                        const SizedBox(width: 8),
                        Expanded(
                          child:
                              toolbarBuilder?.call(context) ??
                              const SizedBox.shrink(),
                        ),
                        ...?actionsBuilder?.call(context),
                      ],
                    ),
                  ),
                ),
              ),
              // 底部悬浮：分类按钮条。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: _tabButtonBar(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
