// 简洁编辑器预览：拍 fakeWechat 式写日记页——标题栏（返回 / 写日记 / 发表）、
// 纯文本输入框（“这一刻的想法...”）、图片九宫格（“+”格子 + “最多可附 9 张图片”
// 提示）、字数计数（N/2000）、底部隐私说明，给用户看简洁编辑的效果。
// 运行：JOTSY_PREVIEW=1 flutter test --update-goldens test/preview/simple_composer_preview_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/simple_composer_controller.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/pages/simple_composer_page.dart';

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
    final boldFile = File(
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    );
    if (await boldFile.exists()) {
      roboto.addFont(
        boldFile.readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await roboto.load();
  }
  await load('MaterialIcons', <String>['fonts/MaterialIcons-Regular.otf']);
  for (final entry in <(String, String)>[
    ('FontAwesomeSolid', 'Font-Awesome-7-Free-Solid-900.otf'),
    ('FontAwesomeRegular', 'Font-Awesome-7-Free-Regular-400.otf'),
    ('FontAwesomeBrands', 'Font-Awesome-7-Brands-Regular-400.otf'),
  ]) {
    await load(entry.$1, <String>[
      'packages/font_awesome_flutter/lib/fonts/${entry.$2}',
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('simple composer preview', (tester) async {
    tester.view.physicalSize = const Size(936, 2048);
    tester.view.devicePixelRatio = 2.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // 用真实 App 主题（页面底 #FAFBFC），不用默认 Material 主题——
          // 默认主题的底色带紫粉调，预览会发粉，与手机上看到的不一样。
          theme: const MaterialTheme(TextTheme()).light(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SimpleComposerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 输入一段示例文字，让计数与“发表”可用状态都看得到。
    await tester.enterText(
      find.byType(TextField),
      '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。',
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SimpleComposerPage),
      matchesGoldenFile('goldens/simple_composer.png'),
    );
    // 预览图只在本地拍（goldens/ 不进 git，CI 里没有对照图）：
    // 与其他预览测试一样，没设 JOTSY_PREVIEW=1 时跳过。
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');

  testWidgets('simple composer resumed draft preview', (tester) async {
    tester.view.physicalSize = const Size(936, 2048);
    tester.view.devicePixelRatio = 2.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 上次没写完的草稿：下次点“写点什么”直接回到这篇，不用从头写。
    final draft = NewDiaryDraft(
      title: '周末和朋友去山里露营',
      contentDocJson: SimpleComposerController.buildContentDocJson(
        '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。',
        const [],
      ),
      contentText: '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。',
      simpleComposer: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: const MaterialTheme(TextTheme()).light(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SimpleComposerPage(
            draftId: 'draft-resumed-preview',
            initialDraft: draft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SimpleComposerPage),
      matchesGoldenFile('goldens/simple_composer_resumed.png'),
    );
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');

  testWidgets('simple composer edit mode preview', (tester) async {
    tester.view.physicalSize = const Size(936, 2048);
    tester.view.devicePixelRatio = 2.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 简洁模式写过的那篇重新编辑、选了简洁：标题栏是“编辑日记 / 保存”，
    // 正文与图片直接还原出来，改完点保存即改那篇。
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: const MaterialTheme(TextTheme()).light(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SimpleComposerPage(
            editDiaryId: 'diary-edit-preview',
            initialText: '周末和朋友去山里露营，帐篷搭在溪边，晚上能听见水声。',
            initialImages: <String>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SimpleComposerPage),
      matchesGoldenFile('goldens/simple_composer_edit.png'),
    );
  }, skip: Platform.environment['JOTSY_PREVIEW'] != '1');
}
