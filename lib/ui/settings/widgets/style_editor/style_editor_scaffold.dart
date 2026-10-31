import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_top_bar.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import 'style_editor_common.dart';

/// 样式编辑页（卡片样式、预览页样式、代码块样式、导航栏样式）共用的页面外壳。
///
/// 全屏实时预览：预览占满整个屏幕，底部完全空出来；顶部悬浮一排小按钮，
/// 统一 40 大小、8 间距，小屏也放得下：
/// - 左上角菜单按钮：返回、标题、重置收进菜单；
/// - 中间预览工具条：各页自定（如列表/瀑布流切换、页码点），占满剩余宽度；
/// - 右上角「样式设置」按钮：点开选项整页，所有分类按区块上下排列，
///   原来 BottomSheet 里的选项直接搬过来，改动即时生效。
///
/// 状态与写入由各页的编辑控制器负责（[listenable]），外壳只管布局。
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

  /// 选项整页里的分类：标题行与对应区块。
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
  /// 保留给各预览组件复用，脚手架恒传 0（底部已无悬浮按钮条）。
  final Widget Function({
    required bool showToolbar,
    required double bottomPadding,
  })
  previewBuilder;

  /// 顶栏悬浮小按钮的统一尺寸：40 白圆，比原来小一圈，给预览让地方，
  /// 仍在可点范围内。
  static const double _topButtonSize = 40;

  /// 顶栏按钮之间的统一间距。
  static const double _topButtonGap = 8;

  /// 白色圆形悬浮按钮外壳（Salt 风：白底圆、无边框、轻微阴影；不用
  /// Material.elevation，阴影重会显出深色描边）。
  Widget _circleButton({required Widget child}) {
    return SizedBox(
      width: _topButtonSize,
      height: _topButtonSize,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: child,
        ),
      ),
    );
  }

  /// 左上角菜单按钮：返回、标题、重置都收进菜单，点开显示。
  Widget _menuButton(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return _circleButton(
      child: Theme(
        data: Theme.of(context).copyWith(
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              minimumSize: const Size(_topButtonSize, _topButtonSize),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        child: ExpressiveMenuButton(
          tooltip: title,
          icon: const Icon(Icons.more_vert, size: 20),
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
      ),
    );
  }

  /// 右上角「样式设置」按钮：打开选项整页。
  Widget _settingsButton(BuildContext context) {
    return _circleButton(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _openSettingsPage(context),
        child: Tooltip(
          message: context.l10n.styleEditorSettingsTitle,
          child: const Center(child: Icon(Icons.tune_outlined, size: 20)),
        ),
      ),
    );
  }

  /// 选项整页：所有分类按区块上下排列，各区块内就是原来 BottomSheet
  /// 里的选项（直接复用各 tab 页）。
  void _openSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StyleEditorSettingsPage(
          title: title,
          tabs: tabs,
          tabViews: tabViews,
          listenable: listenable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = actionsBuilder?.call(context) ?? const <Widget>[];
    return Scaffold(
      body: ListenableBuilder(
        listenable: listenable,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              // 全屏预览：底部完全空出来。
              Positioned.fill(
                child: previewBuilder(showToolbar: false, bottomPadding: 0),
              ),
              // 顶部悬浮：菜单按钮 + 预览工具条 + 操作按钮 + 样式设置按钮，
              // 间距统一 8，视觉平衡、小屏也放得下。
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
                        const SizedBox(width: _topButtonGap),
                        Expanded(
                          child:
                              toolbarBuilder?.call(context) ??
                              const SizedBox.shrink(),
                        ),
                        for (final Widget action in actions) ...<Widget>[
                          const SizedBox(width: _topButtonGap),
                          action,
                        ],
                        const SizedBox(width: _topButtonGap),
                        _settingsButton(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 点右上角「样式设置」打开的选项整页。
///
/// 所有分类按区块上下排列，每个区块的标题是分类名、内容是该 tab 页的
/// 全部选项（包 [StyleEditorEmbeddedScope]，tab 内部不再自己滚动）。
/// 改动即时生效，返回即回到全屏预览。
class _StyleEditorSettingsPage extends StatelessWidget {
  const _StyleEditorSettingsPage({
    required this.title,
    required this.tabs,
    required this.tabViews,
    required this.listenable,
  });

  final String title;
  final List<String> tabs;
  final List<Widget> Function() tabViews;
  final Listenable listenable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 仓库统一紧凑标题栏：64 高、返回键为 < 风格（angleLeft 18）。
      appBar: AppTopBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: listenable,
        builder: (BuildContext context, Widget? _) {
          final views = tabViews();
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          return StyleEditorEmbeddedScope(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 24 + bottomInset),
              itemCount: tabs.length,
              itemBuilder: (BuildContext context, int index) {
                return _SettingsSection(
                  label: tabs[index],
                  child: views[index],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 选项整页里的一个分类区块：蓝色小标题 + 该分类的全部选项。
///
/// 标题样式与 [SettingsCardGroup] 的卡内标题一致（Salt 蓝、w400），
/// tab 页内部的白卡分组原样保留，不套第二层卡。
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              label,
              style: textTheme.titleMedium?.copyWith(
                fontSize: 15,
                color: colorScheme.primary,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
