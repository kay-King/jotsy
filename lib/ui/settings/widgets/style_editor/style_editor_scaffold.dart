import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_top_bar.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import 'style_editor_common.dart';

/// 样式编辑页（卡片样式、预览页样式、代码块样式、导航栏样式）共用的页面外壳。
///
/// 阅读软件式交互：默认只看全屏预览，顶栏与底部导航都藏起来；点一下预览
/// 空白处才把它们叫出来，再点收回去。
/// - 顶部悬浮一排小按钮，统一 32 大小、12 间距：
///   - 左上角菜单按钮：返回、标题、重置收进菜单；
///   - 中间预览工具条：各页自定（如列表/瀑布流切换、页码点），占满剩余宽度；
///   - 右上角「样式设置」按钮：点开选项整页（备用入口，所有分类按区块上下排列）。
/// - 底部导航：一排分类按钮（图标在上、文字在下），点某个分类从底部弹出
///   该分类的设置面板；再点同一分类收起面板。
/// - 设置面板：矮面板，最高不超过屏幕 30%，为预览留地方；内容放不下时
///   面板内部滚动、不撑高；面板内字号缩到 0.85 倍、分组间距收紧。
///
/// 点按只认预览空白处：预览里自带点击的元素（如导航栏预览的底栏项）点按
/// 时只触发元素自己，不切控制条显隐（内层手势优先）。
///
/// 状态与写入由各页的编辑控制器负责（[listenable]），外壳只管布局。
class StyleEditorScaffold extends StatefulWidget {
  const StyleEditorScaffold({
    super.key,
    required this.title,
    required this.listenable,
    required this.isDefault,
    required this.onReset,
    required this.tabs,
    required this.tabViews,
    this.tabIcons,
    this.toolbarBuilder,
    this.actionsBuilder,
    required this.previewBuilder,
  });

  final String title;

  /// 编辑控制器：变化时重建工具条、预览、选项与“重置”按钮。
  final Listenable listenable;
  final bool Function() isDefault;
  final VoidCallback onReset;

  /// 底部导航的分类：标题行与对应面板内容。
  final List<String> tabs;

  /// 底部导航每个分类的图标（Material outlined，与 [tabs] 一一对应；
  /// 不传时退回纯文字 tab）。阅读软件式：图标在上、文字在下，选中态
  /// Salt 蓝、未选中深灰，只看图标就能认出分类。
  final List<IconData>? tabIcons;

  final List<Widget> Function() tabViews;

  /// 悬浮在预览顶部的工具条（与菜单按钮同行）；为 null 时这一段只留菜单按钮。
  /// 必须在监听回调内重新创建；复用同一个 Widget 会跳过重建，让选中态与捕获
  /// 旧明暗值的按钮回调滞留到页面因其他交互重建时才刷新。
  final WidgetBuilder? toolbarBuilder;

  /// 悬浮在预览顶部、排在工具条之后的操作按钮（如预览明暗）。随 [listenable]
  /// 重建，理由同 [toolbarBuilder]。
  final List<Widget> Function(BuildContext context)? actionsBuilder;

  /// 实时预览：[showToolbar] 恒为 false（工具条已悬浮在顶部）；[bottomPadding]
  /// 是控制条显示时底部占的高度（隐藏时为 0）：只开导航时是导航高度，面板
  /// 打开时再加上面板的实测高度，供预览把末尾内容顶到面板上方。
  final Widget Function({
    required bool showToolbar,
    required double bottomPadding,
  })
  previewBuilder;

  /// 顶栏悬浮小按钮的统一尺寸：32 白圆，图标 16；不显大也不显小。
  /// 描边不要加：白底圆 + 柔和阴影就够辨认边缘，描边会让按钮发灰、
  /// 显小气（用户 2026-11-06：描边版丑）；按钮之间靠 12 间距分隔。
  static const double _topButtonSize = 32;

  /// 顶栏那一行的实际高度：40。由最高的孩子——列表/瀑布流分段轨道
  /// （dense 模式 36 + 轨道上下各 2 内边距）决定，不是圆按钮的 32；
  /// 顶部留白必须按这个算，按圆按钮算会少留，第一张卡片顶得太高、
  /// 看着像按钮压着卡片。
  static const double _topBarHeight = 40;

  /// 顶栏按钮之间的统一间距：12，聊天软件压缩后近白缝隙容易被抹掉，
  /// 间距要靠空间本身撑出来，不能只靠颜色。
  static const double _topButtonGap = 12;

  /// 底部导航的高度（48 白色直角条，图标在上、文字在下才放得下）。
  static const double _bottomBarHeight = 48;

  /// 底部导航与屏幕底缘、设置面板与底部导航之间的间距：0——面板与
  /// 导航、导航与底缘都贴合不留缝（阅读软件底部弹出层式：整块贴底），
  /// 面板与导航的直角满宽就靠这个贴合撑出来。
  static const double _bottomBarGap = 0;

  /// 设置面板的最大高度占比：不超过屏幕 30%，预览区至少占三分之二。
  static const double _panelMaxHeightFraction = 0.3;

  /// 面板内字号缩放：比整页设置小两档，内容一眼看完、少滚动。
  static const double _panelTextScale = 0.85;

  @override
  State<StyleEditorScaffold> createState() => _StyleEditorScaffoldState();
}

class _StyleEditorScaffoldState extends State<StyleEditorScaffold> {
  /// 控制条（顶栏 + 底部导航）是否显示；默认隐藏，只看预览。
  bool _controlsVisible = false;

  /// 当前弹出的分类下标；null = 面板收起。
  int? _openTabIndex;

  /// 设置面板的实测高度（内容撑开、最高 30% 屏高，随分类与内容变化）。
  /// 面板打开时计入预览的底部内边距，最后一张卡片才能完整滑到面板上方；
  /// 面板收在树里也能量到（透明且滑出屏幕外，不影响布局），只在打开时用。
  final _panelKey = GlobalKey();
  double _panelHeight = 0;

  /// 底部导航内容行的实测宽度（tab 总宽，为居中判断用）。放得下时
  /// 导航内容居中排布，放不下才横向滚动；未量到为 0 时先按可滚渲染。
  final _navRowKey = GlobalKey();
  double _navContentWidth = 0;

  /// 每帧结束后量一次面板高度，变了才重建（避免循环重建）。
  void _measurePanelHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final height = _panelKey.currentContext?.size?.height;
      if (height != null && (height - _panelHeight).abs() > 0.5) {
        setState(() => _panelHeight = height);
      }
    });
  }

  /// 每帧结束后量一次导航内容宽度，变了才重建（与 [_measurePanelHeight]
  /// 同一模式；量不到时不重建，导航先按可滚渲染）。
  void _measureNavContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final width = _navRowKey.currentContext?.size?.width;
      if (width != null && (width - _navContentWidth).abs() > 0.5) {
        setState(() => _navContentWidth = width);
      }
    });
  }

  /// 点预览空白处：面板开着先收面板，否则切换控制条显隐。
  /// 预览里自带点击的元素（内层手势）优先，不会走到这里。
  void _onPreviewTap() {
    setState(() {
      if (_openTabIndex != null) {
        _openTabIndex = null;
      } else {
        _controlsVisible = !_controlsVisible;
        if (!_controlsVisible) {
          _openTabIndex = null;
        }
      }
    });
  }

  void _onTabTap(int index) {
    setState(() {
      _openTabIndex = _openTabIndex == index ? null : index;
    });
  }

  /// 白色圆形悬浮按钮外壳（Salt 风：白底圆、轻微阴影；不用
  /// Material.elevation，阴影重会显出深色描边）。不要加描边：
  /// 白底在近白 #FAFBFC 背景上靠柔和阴影辨认边缘就够了，描边
  /// （哪怕是 0x22 的淡线）会让按钮发灰、显小气。
  Widget _circleButton({required Widget child}) {
    return SizedBox(
      width: StyleEditorScaffold._topButtonSize,
      height: StyleEditorScaffold._topButtonSize,
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
              minimumSize: const Size(
                StyleEditorScaffold._topButtonSize,
                StyleEditorScaffold._topButtonSize,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        child: ExpressiveMenuButton(
          tooltip: widget.title,
          icon: const Icon(Icons.more_vert, size: 16),
          placement: ExpressiveMenuPlacement.start,
          items: <Widget>[
            // 标题不可点，只起标识作用。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                widget.title,
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
              onPressed: widget.isDefault() ? null : widget.onReset,
              leadingIcon: const FaIcon(FontAwesomeIcons.arrowRotateLeft),
              child: Text(l10n.commonReset),
            ),
          ],
        ),
      ),
    );
  }

  /// 右上角「样式设置」按钮：打开选项整页（备用入口）。
  Widget _settingsButton(BuildContext context) {
    return _circleButton(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _openSettingsPage(context),
        child: Tooltip(
          message: context.l10n.styleEditorSettingsTitle,
          child: const Center(child: Icon(Icons.tune_outlined, size: 16)),
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
          title: widget.title,
          tabs: widget.tabs,
          tabViews: widget.tabViews,
          listenable: widget.listenable,
        ),
      ),
    );
  }

  /// 顶部悬浮行：菜单按钮 + 预览工具条 + 操作按钮 + 样式设置按钮，
  /// 间距统一 12，视觉平衡、小屏也放得下。显隐带淡入淡出，隐藏时不挡点击。
  ///
  /// 居中：这一行左右对称（菜单 + 间距 44、间距 + 设置 44），工具条
  /// 的中心即屏幕正中；工具条内部再用 Stack 把主要内容（分段/页码点）
  /// 贴屏幕正中、明暗按钮贴右（见各页工具条），月亮不再把分段挤偏。
  Widget _topBar(BuildContext context) {
    final actions = widget.actionsBuilder?.call(context) ?? const <Widget>[];
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: <Widget>[
                _menuButton(context),
                const SizedBox(width: StyleEditorScaffold._topButtonGap),
                Expanded(
                  child:
                      widget.toolbarBuilder?.call(context) ??
                      const SizedBox.shrink(),
                ),
                for (final Widget action in actions) ...<Widget>[
                  const SizedBox(width: StyleEditorScaffold._topButtonGap),
                  action,
                ],
                const SizedBox(width: StyleEditorScaffold._topButtonGap),
                _settingsButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部导航：白色直角条，贴边满宽、贴着屏幕底缘与面板（阅读软件
  /// 底部弹出层式，无圆角、无左右边距）；分类按钮图标在上、文字在下，
  /// 选中项 Salt 蓝图标 + 蓝字、配淡蓝 pill，未选中深灰。tab 放得下时
  /// 居中排布，放不下才横向滚动。点已选中的分类收起面板。
  Widget _bottomNavBar(BuildContext context) {
    final tabsRow = Row(
      key: _navRowKey,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < widget.tabs.length; i++)
          Padding(
            // 横向间距：每侧 12px（之前 2px 时 4 个 tab 簇拥在中间、
            // 中心距只有 46.5px、两侧各空 60px+，看着挤）。加到 12px
            // 后中心距约 66.5px、自然宽约 266px，360 宽下铺开、320
            // 宽下仍放得下（居中阈值 308px），不触发横向滚动。
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Material(
              // 选中态不加底色，只靠 Salt 蓝图标 + 蓝字（阅读软件风）；
              // 未选中无底色、深灰。
              color: Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                onTap: () => _onTabTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  child: _NavTabContent(
                    label: widget.tabs[i],
                    icon: widget.tabIcons != null && i < widget.tabIcons!.length
                        ? widget.tabIcons![i]
                        : null,
                    selected: _openTabIndex == i,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Container(
          key: const ValueKey('style_editor_bottom_nav_bar'),
          height: StyleEditorScaffold._bottomBarHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                // 直角条贴在底缘：阴影朝上打在预览上，与预览分层。
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // 内容放得下时居中排布（4 个 tab 不再左对齐偏一边），
              // 放不下才横向滚动；还没量到宽度时先按可滚渲染。
              final fits =
                  _navContentWidth > 0 &&
                  _navContentWidth <= constraints.maxWidth - 12;
              if (fits) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(child: tabsRow),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: tabsRow,
              );
            },
          ),
        ),
      ),
    );
  }

  /// 设置面板：白色直角卡，贴边满宽、贴在底部导航上方（阅读软件底部
  /// 弹出层式，无圆角、无左右边距）；高度随内容撑开、最高不超
  /// 屏幕 30%，放不下时内部滚动。头部（分类名 + 关闭）随内容一起滚，
  /// 底部导航始终显示当前选中的分类，不会丢上下文。无拖动把手。
  Widget _settingsPanel(BuildContext context, List<Widget> views) {
    final open = _controlsVisible && _openTabIndex != null;
    final index = _openTabIndex ?? 0;
    final maxHeight =
        MediaQuery.sizeOf(context).height *
        StyleEditorScaffold._panelMaxHeightFraction;
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedSlide(
      offset: open ? Offset.zero : const Offset(0, 1.5),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      curve: ExpressiveMotion.effects,
      child: AnimatedOpacity(
        opacity: open ? 1 : 0,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        curve: ExpressiveMotion.effects,
        child: IgnorePointer(
          ignoring: !open,
          child: Container(
            key: _panelKey,
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            // 面板内字号比整页设置小一档。
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(
                  StyleEditorScaffold._panelTextScale,
                ),
              ),
              child: SingleChildScrollView(
                // 无拖动把手：标题行直接贴面板顶缘，顶部留白只剩 4px。
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      // 标题行收紧：上内边距 8→4、关闭钮从默认 48px
                      // 触摸区收成 32px，标题与第一分组之间不再空一大段
                      // （标题文字与分组标题之间只剩约 8px）。
                      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              widget.tabs[index],
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: 15,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.commonClose,
                            icon: const Icon(Icons.close, size: 14),
                            // 默认 IconButton 触摸区 48px 会把标题行撑高、
                            // 标题上下各空约 14px；收成 32px 仍可点。
                            // 只传 constraints 不够：外层 _IconButtonM3
                            // 的样式默认 minimumSize 40 + 主题 tapTargetSize
                            // padded 会把按钮撑回 48，必须用 style 把两处
                            // 一起收掉（shrinkWrap 去 48 底线）。
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(32, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () =>
                                setState(() => _openTabIndex = null),
                          ),
                        ],
                      ),
                    ),
                    // 分类内容：嵌进面板时自己不滚动、随面板一起滚，
                    // 分组间距收紧（compact）。
                    StyleEditorEmbeddedScope(
                      compact: true,
                      child: views[index],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 每帧结束后量一次面板实测高度（分类切换、内容变化都会变），供
    // bottomPadding 用；高度没变不重建。
    _measurePanelHeight();
    // 导航内容宽度同理：量到后才知道 tab 放不放得下、要不要居中。
    _measureNavContent();
    // 控制条显示时：预览顶部留出悬浮工具条的高度（状态栏 + 8 间距 +
    // 40 顶栏行高 + 4 呼吸空间），第一张卡片顶缘与顶栏底缘之间只留一
    // 条小缝：4px 是底线，再小就贴着卡片、看着像按钮压着卡片；
    // 之前留 12px，看着空太多。隐藏时只留状态栏，预览尽量大。
    // 底部：只开导航时留导航高度；面板打开时再加上面板实测高度。
    // 面板直接贴在导航上方、中间不留缝：以前留 8px 缝，预览里的文字
    // （如卡片标题中段）会从缝里漏出来、和面板底行的预设名糊成一团。
    final statusBar = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = _controlsVisible
        ? statusBar + 8 + StyleEditorScaffold._topBarHeight + 4
        : statusBar;
    final panelOpen = _controlsVisible && _openTabIndex != null;
    final bottomPadding = _controlsVisible
        ? StyleEditorScaffold._bottomBarHeight +
              StyleEditorScaffold._bottomBarGap +
              bottomInset +
              (panelOpen ? _panelHeight : 0)
        : 0.0;
    final panelBottom =
        bottomInset +
        StyleEditorScaffold._bottomBarGap +
        StyleEditorScaffold._bottomBarHeight;
    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.listenable,
        builder: (BuildContext context, Widget? child) {
          final views = widget.tabViews();
          return Stack(
            children: <Widget>[
              // 全屏预览：点空白处切换控制条显隐。
              Positioned.fill(
                child: AnimatedPadding(
                  padding: EdgeInsets.only(top: topInset),
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.medium,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onPreviewTap,
                    child: widget.previewBuilder(
                      showToolbar: false,
                      bottomPadding: bottomPadding,
                    ),
                  ),
                ),
              ),
              // 顶部悬浮：菜单按钮 + 预览工具条 + 操作按钮 + 样式设置按钮。
              Positioned(top: 0, left: 0, right: 0, child: _topBar(context)),
              // 设置面板：底部导航上方，贴边满宽（无左右边距、无圆角）。
              Positioned(
                left: 0,
                right: 0,
                bottom: panelBottom,
                child: _settingsPanel(context, views),
              ),
              // 底部导航：分类按钮，贴边满宽、贴着屏幕底缘。
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset + StyleEditorScaffold._bottomBarGap,
                child: _bottomNavBar(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 底部导航里的一个分类：图标在上、文字在下（没配图标时只显示文字，
/// 兼容不传 [StyleEditorScaffold.tabIcons] 的调用方）；选中态 Salt 蓝
/// 图标 + 蓝字，未选中深灰。
class _NavTabContent extends StatelessWidget {
  const _NavTabContent({
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    if (icon == null) {
      return Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: color,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
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
