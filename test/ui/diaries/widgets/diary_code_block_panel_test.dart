import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_code_language_tracker.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_newline.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_language.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/diary_code_block_panel.dart';

import '../../../support/expressive_test_theme.dart';

/// 悬浮工具栏卡片内的代码块面板（AppFlowy 版）：选语言、自动识别标签、
/// 复制 / 退出代码块 / 转为正文；全程不推路由、不抢正文焦点。
///
/// 面板直接挂载测试（不经工具栏）：输入是 EditorState + 块文档，选区用
/// path 定位到代码块内。

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

/// 正文：intro 段落 / 代码块 / after 段落；光标进代码块。
({EditorState editorState, Node code}) _editor({
  Object? language = true,
  String codeText = 'code1\ncode2',
}) {
  final code = _codeBlock(codeText, language);
  final editorState = EditorState(
    document: Document(
      root: Node(
        type: kDiaryBlockPage,
        children: <Node>[_paragraph('intro'), code, _paragraph('after')],
      ),
    ),
  );
  addTearDown(editorState.dispose);
  editorState.selection = Selection.collapsed(Position(path: [1], offset: 2));
  return (editorState: editorState, code: code);
}

class _FixedCodeBlockStyle extends DiaryCodeBlockStyleNotifier {
  _FixedCodeBlockStyle(this.style);

  final DiaryCodeBlockStyle style;

  @override
  DiaryCodeBlockStyle build() => style;
}

Future<void> _pumpPanel(
  WidgetTester tester,
  EditorState editorState, {
  VoidCallback? onClose,
  DiaryCodeBlockStyle style = DiaryCodeBlockStyle.defaults,
}) async {
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
          body: DiaryCodeBlockPanel(
            editorState: editorState,
            bodyHeight: kDiaryCodeBlockPanelHeight,
            onClose: onClose ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 选项是否为选中态（选项用 Semantics(selected:) 标出）。
bool _chipSelected(WidgetTester tester, String label) {
  final semantics = tester.widget<Semantics>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.button == true,
      ),
    ),
  );
  return semantics.properties.selected ?? false;
}

void main() {
  testWidgets('a language chip sets the block language and stays open', (
    tester,
  ) async {
    final env = _editor();
    await _pumpPanel(tester, env.editorState);

    await tester.tap(find.text('Python'));
    await tester.pumpAndSettle();

    expect(env.code.attributes[kDiaryBlockLanguageKey], 'python');
    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);
    expect(_chipSelected(tester, 'Python'), isTrue);
    // 选区指回改写前：光标仍在代码块里。
    expect(
      env.editorState.selection,
      Selection.collapsed(Position(path: [1], offset: 2)),
    );

    await tester.ensureVisible(find.text('纯文本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('纯文本'));
    await tester.pumpAndSettle();
    expect(env.code.attributes[kDiaryBlockLanguageKey], 'plain');
    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the auto chip names the detected language', (tester) async {
    final env = _editor(
      codeText: 'def greet(name):\n    print(f"hello {name}")',
    );
    final detected = DiaryCodeLanguageTracker.of(
      env.editorState,
    ).languageFor(env.code, env.code.delta!.toPlainText());
    expect(detected, isNotNull);

    await _pumpPanel(tester, env.editorState);

    final name = diaryCodeLanguageById(detected!)!.name;
    expect(find.text('自动 · $name'), findsOneWidget);
    expect(_chipSelected(tester, '自动 · $name'), isTrue);
  });

  testWidgets('without detection the auto chip reads 自动识别', (tester) async {
    await _pumpPanel(tester, _editor().editorState);
    expect(find.text('自动识别'), findsOneWidget);
  });

  testWidgets('with auto-detect off the first chip reads 不指定', (tester) async {
    await _pumpPanel(
      tester,
      _editor().editorState,
      style: DiaryCodeBlockStyle.defaults.copyWith(autoDetect: false),
    );

    expect(find.text('不指定'), findsOneWidget);
    expect(find.text('自动识别'), findsNothing);
    expect(_chipSelected(tester, '不指定'), isTrue);
  });

  testWidgets('copy writes the block to the clipboard and keeps the panel', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
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
    final env = _editor();
    var closed = 0;
    await _pumpPanel(tester, env.editorState, onClose: () => closed++);

    await tester.tap(find.text('复制代码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(copied, <String>['code1\ncode2']);
    expect(find.text('已复制代码'), findsOneWidget);
    // 复制不收起面板。
    expect(find.byType(DiaryCodeBlockPanel), findsOneWidget);
    expect(closed, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('exit moves the caret below the block and closes', (
    tester,
  ) async {
    final env = _editor();
    var closed = 0;
    await _pumpPanel(tester, env.editorState, onClose: () => closed++);

    await tester.tap(find.text('退出代码块'));
    await tester.pumpAndSettle();

    expect(closed, 1);
    // 块后已有 after 段落：光标直接移到它上面，代码块原样保留。
    expect(
      env.editorState.selection,
      Selection.collapsed(Position(path: [2], offset: 0)),
    );
    expect(env.code.type, kDiaryBlockCode);
    expect(diaryCodeBlockAt(env.editorState.document, const [2]), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('convert to text turns the block into a paragraph and closes', (
    tester,
  ) async {
    final env = _editor(language: 'dart');
    var closed = 0;
    await _pumpPanel(tester, env.editorState, onClose: () => closed++);

    await tester.tap(find.text('转为正文'));
    await tester.pumpAndSettle();

    expect(closed, 1);
    // updateNodeType 会换节点（id 不变）：重新按路径取。
    final node = env.editorState.document.nodeAtPath([1])!;
    expect(node.type, kDiaryBlockParagraph);
    expect(node.delta?.toPlainText(), 'code1\ncode2');
    expect(diaryCodeBlockAt(env.editorState.document, const [1]), isNull);
    expect(tester.takeException(), isNull);
  });
}
