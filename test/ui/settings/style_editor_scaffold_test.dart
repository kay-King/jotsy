import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_scaffold.dart';

import '../../support/expressive_test_theme.dart';

/// 样式编辑器重构验证：底部按钮条已去掉，右上角「样式设置」按钮
/// 打开选项整页，所有分类按区块上下排列。
Widget _buildScaffold() {
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
    previewBuilder:
        ({required bool showToolbar, required double bottomPadding}) =>
            const ColoredBox(color: Colors.grey, child: SizedBox.expand()),
  );
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _buildScaffold(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'no bottom tab bar; settings button opens full page with all sections',
    (WidgetTester tester) async {
      await _pump(tester);

      // 底部不再有分类按钮。
      expect(find.text('Cat A'), findsNothing);
      expect(find.text('Cat B'), findsNothing);
      expect(find.text('Cat C'), findsNothing);

      // 右上角有 tune 图标的样式设置按钮。
      final settingsButton = find.byIcon(Icons.tune_outlined);
      expect(settingsButton, findsOneWidget);

      // 点开整页。
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // 整页标题 + 三个分类区块 + 各自的选项都在。
      expect(find.text('Test Style'), findsWidgets);
      expect(find.text('Cat A'), findsOneWidget);
      expect(find.text('Cat B'), findsOneWidget);
      expect(find.text('Cat C'), findsOneWidget);
      expect(find.text('options A'), findsOneWidget);
      expect(find.text('options B'), findsOneWidget);
      expect(find.text('options C'), findsOneWidget);

      // 返回键回到预览页。
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.tune_outlined), findsOneWidget);
    },
  );
}
