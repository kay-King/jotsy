import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_code_block_look.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/diary_code_block_chrome.dart';

import '../../../../support/expressive_test_theme.dart';

/// 代码块的 AppFlowy 块组件（[DiaryCodeBlockComponentBuilder]）：标题栏
/// （语言名 + 复制按钮）、行号、语法高亮。
///
/// 经真实的 [AppFlowyEditor] 挂载（`code` 类型注册本组件），只读断言渲染；
/// 编辑态的选区/输入行为由编辑器与 [diary_code_block_editing] 的测试覆盖。

Delta _deltaOf(String text) {
  final delta = Delta();
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) {
      delta.insert('\n');
    }
    if (lines[i].isNotEmpty) {
      delta.insert(lines[i]);
    }
  }
  return delta;
}

Node _paragraph(String text) => Node(
  type: kDiaryBlockParagraph,
  attributes: <String, dynamic>{kDiaryBlockDeltaKey: _deltaOf(text).toJson()},
);

Node _codeBlock(String text, Object? language) => Node(
  type: kDiaryBlockCode,
  attributes: <String, dynamic>{
    kDiaryBlockDeltaKey: _deltaOf(text).toJson(),
    if (language != null) kDiaryBlockLanguageKey: language,
  },
);

/// 正文一段、Python 代码块、正文一段、纯文本代码块。
EditorState _twoBlocksEditor() {
  final editorState = EditorState(
    document: Document(
      root: Node(
        type: kDiaryBlockPage,
        children: <Node>[
          _paragraph('Intro paragraph'),
          _codeBlock('def greet(name):\n    return name', 'python'),
          _paragraph('Between'),
          _codeBlock('plain one\nplain two', 'plain'),
          _paragraph('Outro'),
        ],
      ),
    ),
  );
  addTearDown(editorState.dispose);
  return editorState;
}

class _FixedCodeBlockStyle extends DiaryCodeBlockStyleNotifier {
  _FixedCodeBlockStyle(this.style);

  final DiaryCodeBlockStyle style;

  @override
  DiaryCodeBlockStyle build() => style;
}

class _Harness {
  _Harness(this.editorState);

  final EditorState editorState;
  late DiaryCodeBlockLook look;
}

Future<_Harness> _pump(
  WidgetTester tester,
  EditorState editorState, {
  DiaryCodeBlockStyle style = DiaryCodeBlockStyle.defaults,
}) async {
  final harness = _Harness(editorState);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        diaryCodeBlockStyleProvider.overrideWith(
          () => _FixedCodeBlockStyle(style),
        ),
      ],
      child: MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              // 与组件同一套解析入口，行号色等断言用。
              harness.look = DiaryCodeBlockLook.resolve(
                context,
                style: ref.watch(diaryCodeBlockStyleProvider),
                appearance: ref.watch(diaryTextAppearanceProvider),
              );
              return AppFlowyEditor(
                editorState: editorState,
                editorStyle: EditorStyle.mobile(),
                blockComponentBuilders: <String, BlockComponentBuilder>{
                  ...standardBlockComponentBuilderMap,
                  kDiaryBlockCode: DiaryCodeBlockComponentBuilder(),
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 记录剪贴板写入与触觉反馈。
({List<String> clipboard, List<String> haptics}) _mockPlatform(
  WidgetTester tester,
) {
  final clipboard = <String>[];
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
      } else if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return (clipboard: clipboard, haptics: haptics);
}

/// 标题栏：固定 32dp 高的 SizedBox（语言名由绘制层画出，复制按钮带语义）。
Finder _headers() => find.byWidgetPredicate(
  (widget) =>
      widget is SizedBox && widget.height == DiaryCodeBlockLook.headerHeight,
);

/// 复制按钮的语义（语言名经它验证；标题栏文字由绘制层画出）。
Finder _copyButton(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      widget.properties.label == label,
);

void main() {
  testWidgets('each code block gets a 32dp header with its language', (
    tester,
  ) async {
    await _pump(tester, _twoBlocksEditor());

    expect(_headers(), findsNWidgets(2));
    // 语言名经复制按钮的语义标签验证（标题栏文字由绘制层画出）。
    expect(_copyButton('复制 Python 代码'), findsOne);
    expect(_copyButton('复制 纯文本 代码'), findsOne);
  });

  testWidgets('an unspecified block shows the detected language or 代码', (
    tester,
  ) async {
    final json = EditorState(
      document: Document(
        root: Node(
          type: kDiaryBlockPage,
          children: <Node>[
            _codeBlock('{\n  "name": "jotsy",\n  "count": 3\n}', true),
          ],
        ),
      ),
    );
    addTearDown(json.dispose);
    await _pump(tester, json);
    expect(_copyButton('复制 JSON 代码'), findsOne);
  });

  testWidgets('an unspecified block shows 代码 when auto-detect is off', (
    tester,
  ) async {
    final noDetect = EditorState(
      document: Document(
        root: Node(
          type: kDiaryBlockPage,
          children: <Node>[_codeBlock('{\n  "name": "jotsy"\n}', true)],
        ),
      ),
    );
    addTearDown(noDetect.dispose);
    await _pump(
      tester,
      noDetect,
      style: DiaryCodeBlockStyle.defaults.copyWith(autoDetect: false),
    );
    // 未指定语言且关闭自动识别：标题栏显示通用“代码”，读屏直接念按钮名。
    expect(_copyButton('复制代码'), findsOne);
  });

  testWidgets('tapping copy copies that block without moving the caret', (
    tester,
  ) async {
    final platform = _mockPlatform(tester);
    final editorState = _twoBlocksEditor();
    editorState.selection = Selection.collapsed(Position(path: [1], offset: 4));
    await _pump(tester, editorState);
    final selection = editorState.selection;

    await tester.tap(_copyButton('复制 纯文本 代码'));
    await tester.pump();

    expect(platform.clipboard, <String>['plain one\nplain two']);
    expect(platform.haptics, <String>['HapticFeedbackType.lightImpact']);
    expect(editorState.selection, selection);
    expect(find.text('已复制代码'), findsOneWidget);

    // 1.5 秒后对勾收回（绘制层按 copied 重画；语义标签不变）。
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_copyButton('复制 纯文本 代码'), findsOne);

    // 让 SnackBar 走完自己的计时。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('with the header off no header is rendered', (tester) async {
    await _pump(
      tester,
      _twoBlocksEditor(),
      style: DiaryCodeBlockStyle.defaults.copyWith(header: false),
    );

    expect(_headers(), findsNothing);
    expect(_copyButton('复制 Python 代码'), findsNothing);
    // 代码正文仍在。
    expect(find.textContaining('def', findRichText: true), findsWidgets);
  });

  testWidgets('line numbers use the palette color', (tester) async {
    final harness = await _pump(tester, _twoBlocksEditor());

    final numbers = <Text>[
      for (final text in ['1', '2'])
        tester.widget<Text>(
          find
              .descendant(
                of: find.byType(AppFlowyEditor),
                matching: find.text(text),
              )
              .first,
        ),
    ];
    expect(numbers, hasLength(2));
    for (final number in numbers) {
      expect(number.style?.color, harness.look.palette.lineNumber);
    }
  });

  testWidgets('line numbers can be turned off', (tester) async {
    await _pump(
      tester,
      _twoBlocksEditor(),
      style: DiaryCodeBlockStyle.defaults.copyWith(lineNumbers: false),
    );
    expect(
      find.descendant(
        of: find.byType(AppFlowyEditor),
        matching: find.text('1', findRichText: true),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppFlowyEditor),
        matching: find.text('2', findRichText: true),
      ),
      findsNothing,
    );
  });
}
