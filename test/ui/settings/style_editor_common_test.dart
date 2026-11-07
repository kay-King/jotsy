/// 样式编辑面板里第一个分组贴掉顶部留白（[StyleEditorFirstGroupScope]）：
/// 面板标题与第一分组之间不空一大段，其它分组间距不动。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/settings/widgets/settings_card_group.dart';
import 'package:node_diary/ui/settings/widgets/style_editor/style_editor_common.dart';

import '../../support/expressive_test_theme.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      home: Scaffold(
        body: StyleEditorEmbeddedScope(compact: true, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact tab list flushes first group top padding', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      StyleEditorTabList(
        children: <Widget>[
          SettingsCardGroup(title: 'Group A', children: [Text('a')]),
          SettingsCardGroup(title: 'Group B', children: [Text('b')]),
        ],
      ),
    );

    final listTop = tester.getTopLeft(find.byType(StyleEditorTabList)).dy;
    final titleATop = tester.getTopLeft(find.text('Group A')).dy;
    // 面板里第一个分组贴掉顶部留白：标题贴着列表顶缘。
    expect(titleATop - listTop, lessThan(6));

    // 第二分组不动：标题与上一项之间仍有分隔 6 + 卡上内边距 6 +
    // 标题上内边距 8。
    final contentABottom = tester.getBottomLeft(find.text('a')).dy;
    final titleBTop = tester.getTopLeft(find.text('Group B')).dy;
    expect(titleBTop - contentABottom, greaterThan(14));
  });

  testWidgets('merged tab only flushes first child tab first group', (
    WidgetTester tester,
  ) async {
    // 拼起来的分类：只有第一个子 tab 的首分组贴顶，第二个子 tab 的
    // 首分组仍是普通间距。
    await _pump(
      tester,
      StyleEditorMergedTab(
        children: <Widget>[
          StyleEditorTabList(
            children: <Widget>[
              SettingsCardGroup(title: 'Group A', children: [Text('a')]),
            ],
          ),
          StyleEditorTabList(
            children: <Widget>[
              SettingsCardGroup(title: 'Group C', children: [Text('c')]),
            ],
          ),
        ],
      ),
    );

    final mergedTop = tester.getTopLeft(find.byType(StyleEditorMergedTab)).dy;
    final titleATop = tester.getTopLeft(find.text('Group A')).dy;
    expect(titleATop - mergedTop, lessThan(6));

    final contentABottom = tester.getBottomLeft(find.text('a')).dy;
    final titleCTop = tester.getTopLeft(find.text('Group C')).dy;
    expect(titleCTop - contentABottom, greaterThan(14));
  });
}
