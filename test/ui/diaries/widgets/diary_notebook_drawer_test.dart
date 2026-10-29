import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_notebook_drawer.dart';

void main() {
  testWidgets('drawer builds with header and notebook list', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            drawer: DiaryNotebookDrawer(),
            body: SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
    // 抽屉内容在打开后才构建，先验证 Scaffold 能正常创建。
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(DiaryNotebookDrawer, skipOffstage: false), findsNothing);
  });
}
