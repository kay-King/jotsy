import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_scaffold.dart';

import '../../support/expressive_test_theme.dart';

/// 样式编辑器阅读软件式交互验证：
/// - 默认只看全屏预览，顶栏（tune 按钮）与底部分类导航都藏起来；
/// - 点预览空白处叫出控制条，再点收回去；
/// - 点底部分类按钮弹出矮面板，只显示该分类的选项；
/// - 右上角 tune 按钮仍能打开选项整页（备用入口）。
///
/// 注意：控制条显隐用 AnimatedOpacity + IgnorePointer 实现，隐藏时 widget
/// 仍在树里，所以可见性断言用 `.hitTestable()` 而不是 `findsNothing`。
Widget _buildScaffold({
  void Function(double)? onBottomPadding,
  WidgetBuilder? toolbarBuilder,
}) {
  final listenable = ValueNotifier<int>(0);
  addTearDown(listenable.dispose);
  return StyleEditorScaffold(
    title: 'Test Style',
    listenable: listenable,
    isDefault: () => true,
    onReset: () {},
    tabs: const <String>['Cat A', 'Cat B', 'Cat C'],
    tabViews: () => const <Widget>[
      Text('options A'),
      Text('options B'),
      Text('options C'),
    ],
    toolbarBuilder: toolbarBuilder,
    previewBuilder:
        ({required bool showToolbar, required double bottomPadding}) {
          onBottomPadding?.call(bottomPadding);
          return const ColoredBox(
            key: Key('preview'),
            color: Colors.grey,
            child: SizedBox.expand(),
          );
        },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  void Function(double)? onBottomPadding,
  WidgetBuilder? toolbarBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _buildScaffold(
        onBottomPadding: onBottomPadding,
        toolbarBuilder: toolbarBuilder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPreview(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('preview')));
  await tester.pumpAndSettle();
}

/// 设置面板容器：白色直角卡、阴影 blur 16（导航是 blur 10；圆角已去掉，
/// 不再靠 borderRadius 区分）。
Finder _panelFinder() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    final shadows = decoration.boxShadow;
    return decoration.color == Colors.white &&
        decoration.borderRadius == null &&
        shadows != null &&
        shadows.isNotEmpty &&
        shadows.first.blurRadius == 16;
  });
}

void main() {
  testWidgets(
    'controls hidden by default; tap preview shows them; bottom nav opens a short panel',
    (WidgetTester tester) async {
      await _pump(tester);

      // 默认只看预览：顶栏 tune 按钮与底部分类都不可点。
      expect(find.byIcon(Icons.tune_outlined).hitTestable(), findsNothing);
      expect(find.text('Cat A').hitTestable(), findsNothing);
      expect(find.text('Cat B').hitTestable(), findsNothing);
      expect(find.text('Cat C').hitTestable(), findsNothing);

      // 点预览空白处叫出控制条。
      await _tapPreview(tester);

      // 顶栏 tune 按钮与底部分类导航都出现了。
      expect(find.byIcon(Icons.tune_outlined).hitTestable(), findsOneWidget);
      expect(find.text('Cat A').hitTestable(), findsOneWidget);
      expect(find.text('Cat B').hitTestable(), findsOneWidget);
      expect(find.text('Cat C').hitTestable(), findsOneWidget);
      // 面板还没弹出来。
      expect(find.text('options A').hitTestable(), findsNothing);
      expect(find.text('options B').hitTestable(), findsNothing);

      // 点分类 B，弹出矮面板：只显示 B 的选项。
      await tester.tap(find.text('Cat B').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('options B').hitTestable(), findsOneWidget);
      expect(find.text('options A').hitTestable(), findsNothing);
      expect(find.text('options C').hitTestable(), findsNothing);

      // 点预览空白处先收面板，控制条还在。
      await _tapPreview(tester);
      expect(find.text('options B').hitTestable(), findsNothing);
      expect(find.byIcon(Icons.tune_outlined).hitTestable(), findsOneWidget);

      // 再点预览空白处收起控制条。
      await _tapPreview(tester);
      expect(find.byIcon(Icons.tune_outlined).hitTestable(), findsNothing);
      expect(find.text('Cat A').hitTestable(), findsNothing);
    },
  );

  testWidgets('preview bottom padding includes the open panel height', (
    WidgetTester tester,
  ) async {
    // 导航栏 48（面板与导航之间、导航与底缘之间都不留缝；测试里底部
    // 安全区为 0）。
    const navOnlyPadding = 48.0;
    var latestPadding = -1.0;
    await _pump(tester, onBottomPadding: (value) => latestPadding = value);

    // 默认隐藏控制条：预览不留底边。
    expect(latestPadding, 0.0);

    // 只开导航：只留导航高度。
    await _tapPreview(tester);
    expect(latestPadding, navOnlyPadding);

    // 打开分类面板：再加上面板实测高度（面板贴着导航上方，没有间距；
    // 回归：以前只算导航高度，面板盖住预览最下面一张卡片）。
    await tester.tap(find.text('Cat B').hitTestable());
    await tester.pumpAndSettle();
    expect(latestPadding, greaterThan(navOnlyPadding));

    // 收起面板：回到只留导航高度。
    await _tapPreview(tester);
    expect(latestPadding, navOnlyPadding);
  });

  testWidgets('settings panel sits flush on the bottom nav bar (no gap)', (
    WidgetTester tester,
  ) async {
    // 回归：面板底缘与导航顶缘之间留 8px 缝时，预览里的文字（如卡片标题
    // 中段）会从缝里漏出来、和面板底行的预设名糊成一团；面板必须直接
    // 贴在导航上方，中间没有缝。面板与导航都是直角满宽（阅读软件底部
    // 弹出层式），贴着左右屏缘。
    await _pump(tester);
    await _tapPreview(tester);
    await tester.tap(find.text('Cat B').hitTestable());
    await tester.pumpAndSettle();

    Rect rectOf(Finder finder) {
      final box = finder.evaluate().single.renderObject as RenderBox;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    final panel = _panelFinder();
    final navBar = find.byKey(const ValueKey('style_editor_bottom_nav_bar'));
    expect(panel, findsOneWidget);
    expect(navBar, findsOneWidget);
    expect(rectOf(panel).bottom, closeTo(rectOf(navBar).top, 0.5));
    // 直角满宽：左右贴着屏缘（测试视口 800 宽）。
    expect(rectOf(panel).left, 0);
    expect(rectOf(panel).right, 800);
    expect(rectOf(navBar).left, 0);
    expect(rectOf(navBar).right, 800);
  });

  testWidgets('top bar toolbar slot is centered on screen', (
    WidgetTester tester,
  ) async {
    // 回归：月亮按钮占右边 32px 时，分段控件的居中基准被挤偏约 16px。
    // 脚手架顶栏左右对称（菜单 + 间距 44、间距 + 设置 44），工具条
    // 槽位本身必须贴屏幕正中；各页工具条内部再把主要内容贴正中。
    await _pump(
      tester,
      toolbarBuilder: (BuildContext context) => const Center(
        child: SizedBox(key: Key('toolbar-box'), width: 120, height: 36),
      ),
    );
    await _tapPreview(tester);
    expect(
      tester.getCenter(find.byKey(const Key('toolbar-box'))).dx,
      closeTo(400, 0.5),
    );
  });

  testWidgets('bottom nav tabs are centered when they fit', (
    WidgetTester tester,
  ) async {
    // 回归：导航是横向滚动视图时，4 个 tab 总宽不够仍左对齐、看着偏左；
    // 放得下时必须居中排布，只有真溢出才横向滚动。
    await _pump(tester);
    await _tapPreview(tester);
    // 三个 tab 居中：中间那个的中心就是屏幕正中，首尾对称。
    expect(
      tester.getCenter(find.text('Cat B').hitTestable()).dx,
      closeTo(400, 0.5),
    );
    final first = tester.getCenter(find.text('Cat A').hitTestable()).dx;
    final last = tester.getCenter(find.text('Cat C').hitTestable()).dx;
    expect(first + last, closeTo(800, 1));
  });

  testWidgets('panel title sits close to first content (no big gap)', (
    WidgetTester tester,
  ) async {
    // 回归：面板标题行（默认 48px 关闭钮）与第一分组之间空约 39px，
    // 标题看着飘在内容上方。标题行收紧后（关闭钮 32px、上内边距 4），
    // 标题文字与内容之间只剩约 10px。
    await _pump(tester);
    await _tapPreview(tester);
    await tester.tap(find.text('Cat B').hitTestable());
    await tester.pumpAndSettle();

    final panel = _panelFinder();
    final titleBottom = tester
        .getBottomLeft(find.descendant(of: panel, matching: find.text('Cat B')))
        .dy;
    final contentTop = tester
        .getTopLeft(
          find.descendant(of: panel, matching: find.text('options B')),
        )
        .dy;
    expect(contentTop - titleBottom, lessThan(16));
  });

  testWidgets('bottom nav tabs are spread out horizontally', (
    WidgetTester tester,
  ) async {
    // 回归：4 个 tab 簇拥在中间（中心距 46.5px、自然宽 186px），
    // 两侧各空 60px+，看着挤。横向间距加大后中心距约 66.5px、
    // 自然宽约 266px，360 宽下铺开、320 宽下仍放得下不滚动。
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final listenable = ValueNotifier<int>(0);
    addTearDown(listenable.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StyleEditorScaffold(
          title: 'Test Style',
          listenable: listenable,
          isDefault: () => true,
          onReset: () {},
          tabs: const <String>['预设', '布局', '内容', '外观'],
          tabIcons: const <IconData>[
            Icons.palette_outlined,
            Icons.dashboard_outlined,
            Icons.text_fields_outlined,
            Icons.style_outlined,
          ],
          tabViews: () => const <Widget>[
            Text('options A'),
            Text('options B'),
            Text('options C'),
            Text('options D'),
          ],
          previewBuilder:
              ({required bool showToolbar, required double bottomPadding}) {
                return const ColoredBox(
                  key: Key('preview'),
                  color: Colors.grey,
                  child: SizedBox.expand(),
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview')));
    await tester.pumpAndSettle();
    final centers = <double>[
      for (final label in <String>['预设', '布局', '内容', '外观'])
        tester.getCenter(find.text(label).hitTestable()).dx,
    ];
    for (var i = 1; i < centers.length; i++) {
      expect(centers[i] - centers[i - 1], greaterThanOrEqualTo(60));
    }
    // 行铺开：首尾 tab 中心距占屏宽一半以上（之前只有约 140/360）。
    expect(centers.last - centers.first, greaterThan(180));
  });

  testWidgets('settings button still opens full page with all sections', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    // 先叫出控制条。
    await _tapPreview(tester);

    // 点开整页。
    await tester.tap(find.byIcon(Icons.tune_outlined).hitTestable());
    await tester.pumpAndSettle();

    // 整页标题 + 三个分类区块 + 各自的选项都在。
    expect(find.text('Test Style'), findsWidgets);
    expect(find.text('Cat A'), findsOneWidget);
    expect(find.text('Cat B'), findsOneWidget);
    expect(find.text('Cat C'), findsOneWidget);
    expect(find.text('options A'), findsOneWidget);
    expect(find.text('options B'), findsOneWidget);
    expect(find.text('options C'), findsOneWidget);

    // 返回键回到预览页，控制条保持打开状态（State 未变）。
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.tune_outlined).hitTestable(), findsOneWidget);
  });
}
