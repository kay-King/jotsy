import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/widgets/diary_selection_surface.dart';

import '../../../support/diary_drafts_harness.dart';
import '../../notebooks/notebook_test_support.dart';

/// 首页多选的批量标签：更多 → 设置标签 → 三态面板 → 写入 → 可撤销；
/// 去掉正在筛选的标签时卡片收起离开，撤销后回来。
void main() {
  Future<DiaryDraftsHarness> pumpHome(
    WidgetTester tester,
    Future<void> Function(DiaryDraftsHarness h) seed,
  ) async {
    final h = await DiaryDraftsHarness.create(tester);
    await seed(h);
    await h.pump(const DiariesPage());
    await h.settleAll();
    return h;
  }

  Future<int> tag(DiaryDraftsHarness h, String name) async => (await h.tester
      .runAsync(() => h.database.createTag(name: name, color: 0xff2196f3)))!;

  Future<String> diary(
    DiaryDraftsHarness h,
    String title, {
    List<int> tagIds = const <int>[],
  }) async => (await h.tester.runAsync(
    () => h.database.createDiary(
      title: title,
      contentDocJson: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadataJson: '{}',
      tagIds: tagIds,
    ),
  ))!;

  Future<Map<String, Set<int>>> tagsOf(
    DiaryDraftsHarness h,
    List<String> ids,
  ) async =>
      (await h.tester.runAsync(() => h.database.getTagIdsForDiaries(ids)))!;

  Finder card(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(DiarySelectionSurface),
  );

  final selectAllToggle = find.byKey(const ValueKey<String>('head_select_all'));

  /// 顶栏的已选数量。按读屏值断言：400dp 宽的夹具里顶栏只显示数字
  ///（见 `_SelectAllCount`），读屏值始终是完整文案。
  void expectSelected(WidgetTester tester, String count) {
    expect(tester.getSemantics(selectAllToggle).value, '已选择 $count 项');
  }

  Finder sheetRow(int id) => find.byKey(ValueKey<String>('tag_batch_$id'));

  Future<void> openTagSheet(DiaryDraftsHarness h) async {
    await h.tester.tap(find.byTooltip('更多操作').first);
    await h.tester.pumpAndSettle();
    await h.tester.tap(find.text('设置标签'));
    await h.settleAll();
  }

  testWidgets('sets tags on the selected diaries and undo restores them', (
    tester,
  ) async {
    late int travel;
    late int food;
    late String kyoto;
    late String osaka;
    final h = await pumpHome(tester, (h) async {
      travel = await tag(h, '旅行');
      food = await tag(h, '美食');
      kyoto = await diary(h, '在京都', tagIds: <int>[travel]);
      osaka = await diary(h, '在大阪');
    });

    await tester.longPress(card('在京都'));
    await tester.pumpAndSettle();
    await tester.tap(card('在大阪'));
    await tester.pumpAndSettle();
    expectSelected(tester, '2');
    await openTagSheet(h);

    expect(find.text('给 2 篇日记设置标签'), findsOneWidget);
    // 只有一篇带“旅行”：半选；都没有“美食”：未选。
    expect(
      find.descendant(
        of: sheetRow(travel),
        matching: find.byIcon(FontAwesomeIcons.circleMinus.data),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheetRow(food),
        matching: find.byIcon(FontAwesomeIcons.circle.data),
      ),
      findsOneWidget,
    );
    await tester.tap(sheetRow(food));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await h.settleAll();

    expect(await tagsOf(h, <String>[kyoto, osaka]), <String, Set<int>>{
      kyoto: <int>{travel, food},
      osaka: <int>{food},
    });
    expect(find.text('已更新 2 篇日记的标签'), findsOneWidget);
    // 退出了多选，两张卡片都还在。
    expect(selectAllToggle, findsNothing);
    expect(card('在京都'), findsOneWidget);
    expect(card('在大阪'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await h.settleAll();
    expect(await tagsOf(h, <String>[kyoto, osaka]), <String, Set<int>>{
      kyoto: <int>{travel},
      osaka: <int>{},
    });
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });

  testWidgets('closing the sheet without changes keeps the selection', (
    tester,
  ) async {
    late String kyoto;
    final h = await pumpHome(tester, (h) async {
      await tag(h, '旅行');
      kyoto = await diary(h, '在京都');
    });

    await tester.longPress(card('在京都'));
    await tester.pumpAndSettle();
    await openTagSheet(h);
    await tester.tap(find.text('完成'));
    await h.settleAll();

    expect((await tagsOf(h, <String>[kyoto]))[kyoto], isEmpty);
    expectSelected(tester, '1');
    await h.unmount();
  });

  testWidgets('removing the filtered tag hides the cards and undo brings them '
      'back', (tester) async {
    late int travel;
    late String kyoto;
    final h = await pumpHome(tester, (h) async {
      travel = await tag(h, '旅行');
      kyoto = await diary(h, '在京都', tagIds: <int>[travel]);
      await diary(h, '在大阪', tagIds: <int>[travel]);
      await diary(h, '上班路上');
    });

    // 按“旅行”筛选：只剩两篇带它的。筛选栏芯片在本 fork 里默认收起、
    // 测批量逻辑本身时直接经 provider 设筛选（与全选测试同一做法）。
    ProviderScope.containerOf(
      tester.element(find.byType(DiariesPage)),
    ).read(diaryFilterProvider.notifier).setTags(<int>[travel]);
    await h.settleAll();
    expect(card('上班路上'), findsNothing);
    expect(card('在京都'), findsOneWidget);

    await tester.longPress(card('在京都'));
    await tester.pumpAndSettle();
    await openTagSheet(h);
    await tester.tap(sheetRow(travel)); // 全部 → 都没有：去掉
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await h.settleAll();

    expect((await tagsOf(h, <String>[kyoto]))[kyoto], isEmpty);
    expect(find.text('已更新 1 篇日记的标签'), findsOneWidget);
    // 不再符合筛选：卡片收起离开，另一篇还在。
    expect(card('在京都'), findsNothing);
    expect(card('在大阪'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await h.settleAll();
    expect((await tagsOf(h, <String>[kyoto]))[kyoto], <int>{travel});
    expect(card('在京都'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await h.unmount();
  });
}
