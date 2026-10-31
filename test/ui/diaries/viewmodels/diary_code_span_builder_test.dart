import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/core/services/diary_typography.dart';
import 'package:node_diary/ui/diaries/controllers/diary_code_language_tracker.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_block_style.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_theme.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_code_block_look.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_code_span_builder.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_text_appearance.dart';

import '../../../support/expressive_test_theme.dart';

const _code = 'def greet(name):\n    return name';

/// 一个代码块节点：`data.delta` 为整块代码（行间 `\n`），`data.language`
/// 为 [language]（true / 'plain' / 语言 id；null 表示不写该属性）。
Node _codeNode(Object? language, {String text = _code}) {
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
  return Node(
    type: kDiaryBlockCode,
    attributes: <String, dynamic>{
      kDiaryBlockDeltaKey: delta.toJson(),
      if (language != null) kDiaryBlockLanguageKey: language,
    },
  );
}

EditorState _editorState(Node codeNode) {
  return EditorState(
    document: Document(
      root: Node(type: kDiaryBlockPage, children: [codeNode]),
    ),
  );
}

/// 经 [DiaryCodeBlockLook.resolve] 解析代码块外观（与编辑器组件同一入口）。
Future<DiaryCodeBlockLook> _pumpLook(
  WidgetTester tester, {
  DiaryCodeBlockStyle style = DiaryCodeBlockStyle.defaults,
  Brightness brightness = Brightness.light,
}) async {
  late DiaryCodeBlockLook captured;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: expressiveTestTheme(brightness),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              captured = DiaryCodeBlockLook.resolve(
                context,
                style: style,
                appearance: const DiaryTextAppearance(
                  typography: DiaryTypography(),
                ),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  return captured;
}

/// 编辑器按节点 delta 建出的文本 span（根样式为代码文字样式）。
TextSpan _editorSpan(DiaryCodeBlockLook look, String text) {
  return TextSpan(text: text, style: look.codeTextStyle);
}

/// 结果 span 里纯文本为 [text] 的叶子。
Iterable<TextSpan> _leaves(TextSpan span, String text) {
  final found = <TextSpan>[];
  void visit(InlineSpan node) {
    if (node is TextSpan) {
      if (node.text == text) {
        found.add(node);
      }
      for (final child in node.children ?? const <InlineSpan>[]) {
        visit(child);
      }
    }
  }

  visit(span);
  return found;
}

Color? _keyword(DiaryCodeBlockLook look) =>
    look.palette.tokens[DiaryCodeTokenRole.keyword];

/// 把代码块节点的文本换成 [text]（走事务，与编辑器输入同一条链路）。
Future<void> _replaceCodeText(
  EditorState editorState,
  Node node,
  String text,
) async {
  final transaction = editorState.transaction;
  final oldLength = node.delta?.length ?? 0;
  transaction.replaceText(node, 0, oldLength, text);
  await editorState.apply(transaction);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('typing short code refreshes automatic highlighting in '
        '${brightness.name} mode', (tester) async {
      final look = await _pumpLook(tester, brightness: brightness);
      final node = _codeNode(true, text: 'd');
      final editorState = _editorState(node);
      final tracker = DiaryCodeLanguageTracker.of(editorState);

      expect(tracker.languageFor(node, 'd'), isNull);
      expect(tracker.lastDetected(node), isNull);

      const python = 'def greet(name):';
      await _replaceCodeText(editorState, node, python);
      // 输入中沿用上次结果（不闪），停手后才重识别。
      expect(tracker.languageFor(node, python), isNull);
      expect(tracker.lastDetected(node), isNull);
      await tester.pump(DiaryCodeLanguageTracker.debounce);
      expect(tracker.lastDetected(node), 'python');
      expect(
        _leaves(
          buildDiaryCodeSpan(
            _editorSpan(look, python),
            node: node,
            look: look,
            tracker: tracker,
          ),
          'def',
        ).single.style?.color,
        _keyword(look),
      );

      const typescript = 'const count: number = 42;';
      await _replaceCodeText(editorState, node, typescript);
      expect(tracker.languageFor(node, typescript), 'python');
      await tester.pump(DiaryCodeLanguageTracker.debounce);
      expect(tracker.lastDetected(node), 'typescript');
      expect(
        _leaves(
          buildDiaryCodeSpan(
            _editorSpan(look, typescript),
            node: node,
            look: look,
            tracker: tracker,
          ),
          'const',
        ).single.style?.color,
        _keyword(look),
      );
      editorState.dispose();
    });
  }

  testWidgets('a python block colors its keywords with the palette', (
    tester,
  ) async {
    final look = await _pumpLook(tester);
    final node = _codeNode('python');
    final tracker = DiaryCodeLanguageTracker.of(_editorState(node));

    final result = buildDiaryCodeSpan(
      _editorSpan(look, _code),
      node: node,
      look: look,
      tracker: tracker,
    );
    final def = _leaves(result, 'def');
    expect(def, isNotEmpty);
    expect(def.first.style?.color, _keyword(look));
    // 根样式换成代码文字样式（等宽字体）。
    expect(result.style?.fontFamily, 'monospace');
  });

  testWidgets('an unspecified block is plain when auto-detect is off', (
    tester,
  ) async {
    final look = await _pumpLook(
      tester,
      style: DiaryCodeBlockStyle.defaults.copyWith(autoDetect: false),
    );
    final node = _codeNode(true);
    final tracker = DiaryCodeLanguageTracker.of(_editorState(node));

    final result = buildDiaryCodeSpan(
      _editorSpan(look, _code),
      node: node,
      look: look,
      tracker: tracker,
    );
    // 不高亮时整块保持一个叶子（不断行），不会拆出 'def'。
    expect(_leaves(result, _code), isNotEmpty);
    expect(_leaves(result, 'def'), isEmpty);
    expect(result.style?.fontFamily, 'monospace');
  });

  testWidgets('an unspecified block is highlighted by the detected language', (
    tester,
  ) async {
    const python =
        'import os\n'
        '\n'
        'def greet(name, times=3):\n'
        '    """Say hello."""\n'
        '    for _ in range(times):\n'
        '        print(f"Hello, {name}!")\n'
        '    return None\n'
        '\n'
        'class Greeter(object):\n'
        '    def __init__(self):\n'
        '        self.count = 0';
    final look = await _pumpLook(tester);
    final node = _codeNode(true, text: python);
    final tracker = DiaryCodeLanguageTracker.of(_editorState(node));

    expect(tracker.languageFor(node, python), 'python');

    final result = buildDiaryCodeSpan(
      _editorSpan(look, python),
      node: node,
      look: look,
      tracker: tracker,
    );
    final def = _leaves(result, 'def');
    expect(def, isNotEmpty);
    expect(def.first.style?.color, _keyword(look));
  });

  testWidgets('a plain block is never highlighted', (tester) async {
    final look = await _pumpLook(tester);
    final node = _codeNode('plain');
    final tracker = DiaryCodeLanguageTracker.of(_editorState(node));

    final result = buildDiaryCodeSpan(
      _editorSpan(look, _code),
      node: node,
      look: look,
      tracker: tracker,
    );
    // 纯文本块不高亮：整块保持一个叶子，不会拆出 'def'。
    expect(_leaves(result, _code), isNotEmpty);
    expect(_leaves(result, 'def'), isEmpty);
  });

  group('span decorator called directly', () {
    testWidgets('a leaf with its own color keeps it', (tester) async {
      final look = await _pumpLook(tester);
      // 用户手动上色的区域（delta 里带 font_color）：不高亮上色，
      // 只叠 token 的字形；没上色的区域正常高亮。
      // 注意：编辑器给每个叶子都带默认文字色，keepColor 只看 delta 属性。
      final node = Node(
        type: kDiaryBlockCode,
        attributes: <String, dynamic>{
          kDiaryBlockDeltaKey:
              (Delta()
                    ..insert('def f():\n    ')
                    ..insert(
                      'return',
                      attributes: <String, dynamic>{
                        kDiaryInlineTextColor: '#FFFF0000',
                      },
                    )
                    ..insert(' 1'))
                  .toJson(),
          kDiaryBlockLanguageKey: 'python',
        },
      );
      final tracker = DiaryCodeLanguageTracker.of(_editorState(node));

      const leafStyle = TextStyle(color: Color(0xFF123456));
      final result = buildDiaryCodeSpan(
        const TextSpan(
          style: leafStyle,
          children: [
            // 模拟编辑器建出的叶子：都带默认文字色。
            TextSpan(text: 'def f():\n    ', style: leafStyle),
            TextSpan(text: 'return', style: leafStyle),
            TextSpan(text: ' 1', style: leafStyle),
          ],
        ),
        node: node,
        look: look,
        tracker: tracker,
      );
      // 没上色的关键字正常着色。
      expect(_leaves(result, 'def').single.style?.color, _keyword(look));
      // 上色的关键字不上高亮色（piece 无样式，继承叶子的用户色）。
      final ret = _leaves(result, 'return').single;
      expect(ret.style?.color, isNot(_keyword(look)));
    });

    testWidgets('a non-code node returns the span unchanged', (tester) async {
      final look = await _pumpLook(tester);
      final node = Node(type: kDiaryBlockParagraph);
      final tracker = DiaryCodeLanguageTracker.of(_editorState(node));
      const span = TextSpan(text: 'hello');

      expect(
        buildDiaryCodeSpan(span, node: node, look: look, tracker: tracker),
        same(span),
      );
    });

    testWidgets('a span whose text mismatches the delta is not highlighted', (
      tester,
    ) async {
      final look = await _pumpLook(tester);
      final node = _codeNode('python');
      final tracker = DiaryCodeLanguageTracker.of(_editorState(node));

      // 纯文本与 delta 对不上（光标偏移会错位）：只换根样式，不着色。
      final result = buildDiaryCodeSpan(
        const TextSpan(text: 'stale text'),
        node: node,
        look: look,
        tracker: tracker,
      );
      expect(result.style, look.codeTextStyle);
      expect(result.children, isNull);
    });
  });
}
