// 筛选小图标预览：日记页顶栏的筛选图标按钮（无筛选灰色 / 有筛选主题色+小圆点）。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/filter_icon_preview_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  final robotoFile = File(
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  );
  if (await robotoFile.exists()) {
    final roboto = FontLoader('Roboto');
    roboto.addFont(
      robotoFile.readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
    await roboto.load();
  }
  await load('MaterialIcons', <String>['fonts/MaterialIcons-Regular.otf']);
}

Widget _host({required bool hasActiveFilter}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DiaryHeadSection(
      isSelectionMode: false,
      selectedCount: 0,
      onCancelSelection: () {},
      isPinActionUnpin: false,
      onPinSelected: () {},
      onArchiveSelected: () {},
      onExportSelected: () {},
      onDeleteSelected: () {},
      onAddToNotebookSelected: () {},
      onRemoveFromNotebookSelected: null,
      onMoveToNotebookSelected: null,
      onOpenArchived: () {},
      onOpenDrafts: () {},
      draftCount: 0,
      onOpenViewOptions: () {},
      onOpenSearchPage: () {},
      hasActiveFilter: hasActiveFilter,
      onOpenFilter: () {},
    ),
  ),
);

void main() {
  testWidgets('filter icon preview', (tester) async {
    await _loadFonts();
    final binding = tester.binding;
    binding.window.physicalSizeTestValue = const Size(1080, 400);
    binding.window.devicePixelRatioTestValue = 2.0;
    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    // 无筛选：灰色图标
    await tester.pumpWidget(_host(hasActiveFilter: false));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DiaryHeadSection),
      matchesGoldenFile('goldens/filter_icon_off.png'),
    );

    // 有筛选：主题色 + 小圆点
    await tester.pumpWidget(_host(hasActiveFilter: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(DiaryHeadSection),
      matchesGoldenFile('goldens/filter_icon_on.png'),
    );
  });
}
