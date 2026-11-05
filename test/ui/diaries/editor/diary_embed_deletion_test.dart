import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_embed_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_embed_keys.dart';
import 'package:node_diary/ui/diaries/widgets/diary_armed_embed_frame.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_trailing_line_tap.dart';

import '../../../support/expressive_test_theme.dart';

/// 嵌入块（图片、视频、分隔线、卡片……）旁边的退格 / Delete，以及文末是
/// 嵌入块时点正文下方空白处补一行可写的段落。上游的退格会越过嵌入块把
/// 下一行并进它上面那段，嵌入块因此跑到后面（文末时成了最后一块、再也
/// 删不掉）。
///
/// 本地编辑器没有 DiaryEditorController：纯逻辑直接用 EditorState，widget
/// 部分用裸 AppFlowyEditor pump（编辑页的接线与这里的接线相同：快捷键插在
/// 上游退格 / Delete 之前、块组件包 DiaryArmedEmbedBuilder、软键盘拦截器
/// 登记在键盘服务上、正文下方包 DiaryTrailingLineTap）。

Map<String, Object?> _text(
  String type,
  String text, {
  Map<String, Object?> data = const {},
  List<Map<String, Object?>> children = const [],
}) => {
  'type': type,
  'data': {
    'delta': [
      if (text.isNotEmpty) {'insert': text},
    ],
    ...data,
  },
  if (children.isNotEmpty) 'children': children,
};

Map<String, Object?> _p(String text) => _text('paragraph', text);

Map<String, Object?> _embed(String type) => {
  'type': type,
  'data': switch (type) {
    'image' => {'url': '/missing/photo.jpg'},
    'video' => {'path': '/missing/clip.mp4', 'name': 'clip.mp4'},
    'diaryLinkCard' => {'diaryId': 'd1'},
    _ => <String, Object?>{},
  },
};

af.EditorState _document(List<Map<String, Object?>> blocks) {
  final state = af.EditorState(
    document: af.Document.fromJson({
      'document': {'type': 'page', 'children': blocks},
    }),
  );
  addTearDown(state.dispose);
  return state;
}

String _contentJson(af.EditorState state) =>
    jsonEncode(state.document.toJson());

/// 每块一行：`类型:文字`，子块缩进两格。
String _outline(af.EditorState state) {
  final lines = <String>[];
  void visit(af.Node node, int depth) {
    final text = node.delta?.toPlainText();
    lines.add('${'  ' * depth}${node.type}${text == null ? '' : ':$text'}');
    for (final child in node.children) {
      visit(child, depth + 1);
    }
  }

  for (final node in state.document.root.children) {
    visit(node, 0);
  }
  return lines.join('\n');
}

af.Selection _caret(af.Path path, [int offset = 0]) =>
    af.Selection.collapsed(af.Position(path: path, offset: offset));

af.Node? _armed(af.EditorState state) => DiaryArmedEmbed.of(state).node.value;

void main() {
  group('backspace at the start of a line after an embed', () {
    // 所有嵌入块类型（图片、视频、音频、附件、分隔线、卡片、未识别的旧
    // 嵌入）同一条规则；以后新增的类型登记进集合即自动覆盖。
    for (final type in kDiaryEmbedDeletableBlockTypes) {
      test('selects the $type first, then deletes it in place', () {
        final state = _document([_p('before'), _embed(type), _p('after')]);
        final before = _contentJson(state);
        final embed = state.document.root.children[1];
        state.selection = _caret([2]);

        // 第一次：只选中，正文与插入点都不动。
        expect(backspaceDiaryEmbed(state), isTrue);
        expect(_contentJson(state), before);
        expect(state.selection, _caret([2]));
        expect(_armed(state), same(embed));

        // 第二次：删掉它，本行原地上移，选中随之取消。
        expect(backspaceDiaryEmbed(state), isTrue);
        expect(_outline(state), 'paragraph:before\nparagraph:after');
        expect(state.selection, _caret([1]));
        expect(_armed(state), isNull);
        state.undoManager.undo();
        expect(_contentJson(state), before);
      });
    }

    for (final type in kDiaryEmbedDeletableBlockTypes) {
      test('on an empty line removes that line and selects the $type', () {
        // 嵌入块下面连着几个空行：第一次退格删掉紧挨着的空行并选中嵌入块，
        // 第二次删掉嵌入块，下面的空行原样留着。
        final state = _document([
          _p('a'),
          _embed(type),
          _p(''),
          _p(''),
          _p(''),
          _p('b'),
        ]);
        final embed = state.document.root.children[1];
        state.selection = _caret([2]);

        expect(backspaceDiaryEmbed(state), isTrue);
        expect(
          _outline(state),
          'paragraph:a\n$type\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(state.selection, _caret([2]));
        expect(_armed(state), same(embed));

        expect(backspaceDiaryEmbed(state), isTrue);
        expect(
          _outline(state),
          'paragraph:a\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(state.selection, _caret([1]));
        expect(_armed(state), isNull);
      });
    }

    test('keeps the empty line when nothing writable follows it', () {
      for (final tail in [
        <Map<String, Object?>>[],
        [_embed('video')],
      ]) {
        final state = _document([
          _p('before'),
          _embed('image'),
          _p(''),
          ...tail,
        ]);
        state.selection = _caret([2]);

        // 空行是插入点唯一能放的地方：不删，只选中上面的图片。
        expect(backspaceDiaryEmbed(state), isTrue);
        expect(state.document.root.children, hasLength(3 + tail.length));
        expect(_armed(state)?.type, 'image');

        expect(backspaceDiaryEmbed(state), isTrue);
        expect(
          _outline(state),
          [
            'paragraph:before',
            'paragraph:',
            ...tail.map((_) => 'video'),
          ].join('\n'),
        );
        expect(state.selection, _caret([1]));
      }
    });

    test('anything else in between cancels the selection', () async {
      final state = _document([_p('a'), _embed('image'), _p('after')]);
      state.selection = _caret([2]);

      // 插入点挪开再回来：重新选中，不删除。
      expect(backspaceDiaryEmbed(state), isTrue);
      state.selection = _caret([2], 3);
      expect(_armed(state), isNull);
      state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(state), isTrue);
      expect(state.document.root.children, hasLength(3));

      // 上游重设同一选区不算挪开。
      state.selection = _caret([2]);
      expect(_armed(state)?.type, 'image');

      // 正文有改动（打字）即取消。
      final transaction = state.transaction
        ..insertText(state.document.root.children[0], 1, 'x');
      await state.apply(transaction);
      expect(_armed(state), isNull);
      // 打字把插入点带到了被改的那行（insertText 自带 afterSelection）：
      // 先把它放回嵌入块下面那行的行首，再按退格。
      state.selection = _caret([2]);
      expect(backspaceDiaryEmbed(state), isTrue);
      expect(state.document.root.children, hasLength(3));
      expect(_armed(state)?.type, 'image');
    });

    test('reaches an embed nested as the last child of the block above', () {
      final state = _document([
        _text('bulleted_list', 'item', children: [_embed('image')]),
        _p('after'),
      ]);
      state.selection = _caret([1]);

      expect(backspaceDiaryEmbed(state), isTrue);
      expect(backspaceDiaryEmbed(state), isTrue);
      expect(_outline(state), 'bulleted_list:item\nparagraph:after');
      expect(state.selection, _caret([1]));
    });

    test('leaves everything else to the upstream rules', () {
      final state = _document([
        _p('text'),
        _embed('divider'),
        _p('after'),
        _text(
          'diaryToggleBlock',
          'closed',
          data: {'collapsed': true},
          children: [_embed('image')],
        ),
        _p('below toggle'),
      ]);
      final before = _contentJson(state);
      // 不在行首。
      state.selection = _caret([2], 2);
      expect(backspaceDiaryEmbed(state), isFalse);
      // 上一块是文字，或在文档开头。
      state.selection = _caret([3]);
      expect(backspaceDiaryEmbed(state), isFalse);
      state.selection = _caret([0]);
      expect(backspaceDiaryEmbed(state), isFalse);
      // 收起的折叠块里的图片看不见，不算紧挨着。
      state.selection = _caret([4]);
      expect(backspaceDiaryEmbed(state), isFalse);
      // 插入点盖在嵌入块上（上游删掉它）与非折叠选区。
      state.selection = _caret([1]);
      expect(backspaceDiaryEmbed(state), isFalse);
      state.selection = af.Selection(
        start: af.Position(path: [2]),
        end: af.Position(path: [2], offset: 3),
      );
      expect(backspaceDiaryEmbed(state), isFalse);
      expect(_contentJson(state), before);
      expect(_armed(state), isNull);
    });
  });

  test('Delete at the end of a line selects, then removes the embed below', () {
    final state = _document([_p('a'), _embed('image'), _p('b')]);
    state.selection = _caret([0], 1);

    expect(deleteForwardDiaryEmbed(state), isTrue);
    expect(state.document.root.children, hasLength(3));
    expect(_armed(state)?.type, 'image');
    expect(deleteForwardDiaryEmbed(state), isTrue);
    expect(_outline(state), 'paragraph:a\nparagraph:b');
    expect(state.selection, _caret([0], 1));

    // 不在行末、下一块是文字：交给上游。
    state.selection = _caret([0]);
    expect(deleteForwardDiaryEmbed(state), isFalse);
    state.selection = _caret([0], 1);
    expect(deleteForwardDiaryEmbed(state), isFalse);
  });

  group('soft keyboard deletion', () {
    TextEditingDeltaDeletion deletion(String text) => TextEditingDeltaDeletion(
      oldText: text,
      deletedRange: const TextRange.collapsed(0),
      selection: const TextSelection.collapsed(offset: 0),
      composing: TextRange.empty,
    );

    test('selects, then deletes the embed above a line', () async {
      final state = _document([_embed('divider'), _p('after')]);
      state.selection = _caret([1]);
      final interceptor = DiaryEmbedKeyboardInterceptor();

      expect(
        await interceptor.interceptDelete(deletion('after'), state),
        isTrue,
      );
      expect(_armed(state)?.type, 'divider');
      expect(
        await interceptor.interceptDelete(deletion('after'), state),
        isTrue,
      );
      expect(_outline(state), 'paragraph:after');
    });

    test('lets upstream turn a heading into a paragraph first', () async {
      final state = _document([
        _embed('divider'),
        _text('heading', 'title', data: {'level': 2}),
      ]);
      state.selection = _caret([1]);

      final handled = await DiaryEmbedKeyboardInterceptor().interceptDelete(
        deletion('title'),
        state,
      );

      expect(handled, isFalse);
      expect(_outline(state), 'divider\nheading:title');
      expect(_armed(state), isNull);
    });
  });

  group('appendDiaryTrailingLine', () {
    test('adds a writable line after a trailing embed or table', () {
      for (final last in [
        _embed('image'),
        _embed('divider'),
        _text('bulleted_list', 'item', children: [_embed('video')]),
        {
          'type': 'table',
          'data': {'colsLen': 1, 'rowsLen': 1},
          'children': [
            {
              'type': 'table/cell',
              'data': {'rowPosition': 0, 'colPosition': 0},
              'children': [_p('cell')],
            },
          ],
        },
      ]) {
        final state = _document([_p('a'), last]);
        final selection = appendDiaryTrailingLine(state);
        expect(selection, _caret([2]));
        expect(state.document.root.children.last.type, 'paragraph');
        expect(state.selection, selection);
        expect(state.selectionUpdateReason, af.SelectionUpdateReason.uiEvent);
        state.undoManager.undo();
        expect(state.document.root.children, hasLength(2));
      }
    });

    test('does nothing when the text already ends with a text block', () {
      for (final last in [
        _p('end'),
        _text(
          'diaryToggleBlock',
          'closed',
          data: {'collapsed': true},
          children: [_embed('image')],
        ),
      ]) {
        final state = _document([_embed('image'), last]);
        final before = _contentJson(state);
        expect(appendDiaryTrailingLine(state), isNull);
        expect(_contentJson(state), before);
      }
    });
  });

  group('in the editor', () {
    Map<String, af.BlockComponentBuilder> builders(af.EditorState state) {
      final map = <String, af.BlockComponentBuilder>{
        ...af.standardBlockComponentBuilderMap,
        ...buildDiaryBlockComponentBuilders(),
      };
      // 与编辑页的接线相同：嵌入块的渲染器包一层选中框。
      for (final type in kDiaryEmbedDeletableBlockTypes) {
        final builder = map[type];
        if (builder != null) {
          map[type] = DiaryArmedEmbedBuilder(builder, state);
        }
      }
      return map;
    }

    Future<af.EditorState> pump(
      WidgetTester tester,
      List<Map<String, Object?>> blocks,
      af.Selection selection,
    ) async {
      final state = _document(blocks);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: expressiveTestTheme(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            af.AppFlowyEditorLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiaryTrailingLineTap(
              editorState: state,
              child: af.AppFlowyEditor(
                editorState: state,
                focusNode: focus,
                editorStyle: af.EditorStyle.mobile(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                blockComponentBuilders: builders(state),
                // 与编辑页的接线相同：嵌入块命令插在上游退格 / Delete 之前。
                commandShortcutEvents: [
                  for (final event in af.standardCommandShortcutEvents) ...[
                    if (identical(event, af.backspaceCommand))
                      diaryEmbedBackspaceCommand,
                    if (identical(event, af.deleteCommand))
                      diaryEmbedDeleteCommand,
                    event,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 软键盘拦截器随编辑器挂载登记（编辑页在下一帧做同一件事）。
      state.service.keyboardService?.registerInterceptor(
        DiaryEmbedKeyboardInterceptor(),
      );
      // 选区在挂载后设置：挂载前设置会被编辑器初始化重置，且只有选区变化
      // 才会让键盘服务连接输入法。
      state.selection = selection;
      focus.requestFocus();
      await tester.pumpAndSettle();
      return state;
    }

    // 光标闪烁让 pumpAndSettle 停不下来，卸载后再收尾；先走完上游撤销
    // 记录的合并计时（上游命令不跳过它）。
    Future<void> unmount(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    /// 嵌入块上选中样式的不透明度（0 为没有选中）。
    double selectedLook(WidgetTester tester, af.Node node) => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey('diary-armed-embed-${node.id}')),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }

    testWidgets('Backspace and Delete keys select, then delete the embed', (
      tester,
    ) async {
      final state = await pump(tester, [
        _p('before'),
        _embed('divider'),
        _p('after'),
        _embed('divider'),
        _p('end'),
      ], _caret([2]));
      final first = state.document.root.children[1];
      expect(selectedLook(tester, first), 0);

      await press(tester, LogicalKeyboardKey.backspace);
      expect(state.document.root.children, hasLength(5));
      expect(state.selection, _caret([2]));
      expect(selectedLook(tester, first), 1);

      await press(tester, LogicalKeyboardKey.backspace);
      expect(
        _outline(state),
        'paragraph:before\nparagraph:after\ndivider\nparagraph:end',
      );
      expect(state.selection, _caret([1]));

      state.selection = _caret([1], 5);
      await tester.pump();
      await press(tester, LogicalKeyboardKey.delete);
      expect(state.document.root.children, hasLength(4));
      await press(tester, LogicalKeyboardKey.delete);
      expect(
        _outline(state),
        'paragraph:before\nparagraph:after\nparagraph:end',
      );
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    // 手机上的软键盘：上游在输入法的编辑值前垫了一个空格占位，段首退格删的
    // 是这个占位，经输入法删除（拦截器）而不是退格键。这里照输入法的做法
    // 改编辑值。
    Map<String, dynamic> ime(WidgetTester tester) =>
        tester.testTextInput.editingState!;

    Future<void> imeEdit(
      WidgetTester tester,
      String Function(String text, int caret) edit,
      int Function(int caret) caretAfter,
    ) async {
      final text = ime(tester)['text'] as String;
      final caret = ime(tester)['selectionBase'] as int;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: edit(text, caret),
          selection: TextSelection.collapsed(offset: caretAfter(caret)),
        ),
      );
      // 拦截后的输入法同步是零时长计时器：pump 要带时长才会推进假时钟。
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
    }

    Future<void> imeBackspace(WidgetTester tester) => imeEdit(
      tester,
      (text, caret) => text.replaceRange(caret - 1, caret, ''),
      (caret) => caret - 1,
    );

    Future<void> imeType(WidgetTester tester, String typed) => imeEdit(
      tester,
      (text, caret) => text.replaceRange(caret, caret, typed),
      (caret) => caret + typed.length,
    );

    testWidgets(
      'soft keyboard: below an image followed by empty lines the first '
      'backspace removes the line and selects the image',
      (tester) async {
        final state = await pump(tester, [
          _p('a'),
          _embed('image'),
          _p(''),
          _p(''),
          _p(''),
          _p('b'),
        ], _caret([2]));
        final image = state.document.root.children[1];
        expect(ime(tester)['text'], ' ');

        await imeBackspace(tester);
        expect(
          _outline(state),
          'paragraph:a\nimage\nparagraph:\nparagraph:\nparagraph:b',
        );
        expect(state.selection, _caret([2]));
        await tester.pump(const Duration(milliseconds: 200));
        expect(selectedLook(tester, image), 1);

        // 插入点一直在文字行里，输入法连着它：打字照常写进这一行并取消
        // 选中。
        await imeType(tester, 'n');
        expect(
          _outline(state),
          'paragraph:a\nimage\nparagraph:n\nparagraph:\nparagraph:b',
        );
        expect(state.selection, _caret([2], 1));
        await tester.pump(const Duration(milliseconds: 200));
        expect(selectedLook(tester, image), 0);

        // 删掉刚打的字、回到行首：这一行又是空行，再退格同样删掉它并选中
        // 图片；再按一次删掉图片，剩下的空行原样留着。
        await imeBackspace(tester);
        expect(state.selection, _caret([2]));
        expect(DiaryArmedEmbed.of(state).node.value, isNull);
        await imeBackspace(tester);
        expect(DiaryArmedEmbed.of(state).node.value, same(image));
        expect(_outline(state), 'paragraph:a\nimage\nparagraph:\nparagraph:b');
        await imeBackspace(tester);
        expect(_outline(state), 'paragraph:a\nparagraph:\nparagraph:b');
        expect(state.selection, _caret([1]));
        expect(ime(tester)['text'], ' ');
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'soft keyboard: after the empty line goes the input follows the next '
      'line',
      (tester) async {
        final state = await pump(tester, [
          _p('a'),
          _embed('divider'),
          _p(''),
          _p('world'),
        ], _caret([2]));

        await imeBackspace(tester);
        expect(_outline(state), 'paragraph:a\ndivider\nparagraph:world');
        expect(state.selection, _caret([2]));
        // 拦截后上游把输入法退回了空行的编辑值，随后按新的一行重新同步。
        expect(ime(tester)['text'], ' world');
        expect(ime(tester)['selectionBase'], 1);

        await imeType(tester, 'n');
        expect(_outline(state), 'paragraph:a\ndivider\nparagraph:nworld');
        expect(state.selection, _caret([2], 1));
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('a heading after an embed becomes a paragraph first', (
      tester,
    ) async {
      final state = await pump(tester, [
        _embed('divider'),
        _text('heading', 'title', data: {'level': 2}),
      ], _caret([1]));

      await press(tester, LogicalKeyboardKey.backspace);
      expect(_outline(state), 'divider\nparagraph:title');
      await press(tester, LogicalKeyboardKey.backspace);
      expect(_outline(state), 'divider\nparagraph:title');
      await press(tester, LogicalKeyboardKey.backspace);
      expect(_outline(state), 'paragraph:title');
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    double lastBlockBottom(af.EditorState state) {
      final box = state.document.root.children.last.renderBox!;
      return box.localToGlobal(Offset(0, box.size.height)).dy;
    }

    testWidgets(
      'tapping below a trailing embed adds a line and shows the keyboard',
      (tester) async {
        final state = await pump(tester, [
          _p('text'),
          _embed('divider'),
        ], _caret([0], 4));
        // 用户收起了键盘。
        tester.testTextInput.hide();
        expect(tester.testTextInput.isVisible, isFalse);
        final left = tester.getTopLeft(find.byType(af.AppFlowyEditor)).dx;

        // 点在分隔线上不补行。
        final divider = state.document.root.children.last.renderBox!;
        await tester.tapAt(
          divider.localToGlobal(divider.size.center(Offset.zero)),
        );
        await tester.pump();
        expect(state.document.root.children, hasLength(2));

        await tester.tapAt(Offset(left + 40, lastBlockBottom(state) + 60));
        await tester.pump();

        expect(_outline(state), 'paragraph:text\ndivider\nparagraph:');
        expect(state.selection, _caret([2]));
        expect(tester.testTextInput.isVisible, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        // 最后一块已是文字：再点下方只是把插入点放到末尾，不再补行。
        await tester.tapAt(Offset(left + 40, lastBlockBottom(state) + 60));
        await tester.pump();
        expect(state.document.root.children, hasLength(3));
        await unmount(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('a desktop click below adds the line, a right click does not', (
      tester,
    ) async {
      final state = await pump(tester, [
        _p('text'),
        _embed('image'),
      ], _caret([0], 4));
      final below = Offset(
        tester.getTopLeft(find.byType(af.AppFlowyEditor)).dx + 40,
        lastBlockBottom(state) + 60,
      );

      await tester.tapAt(below);
      await tester.pump();
      expect(_outline(state), 'paragraph:text\nimage\nparagraph:');
      expect(state.selection, _caret([2]));

      // 右键是打开正文菜单，不补行（菜单的遮罩会吃掉之后的点按，放在最后）。
      state.undoManager.undo();
      await tester.pump();
      expect(state.document.root.children, hasLength(2));
      await tester.tapAt(below, buttons: kSecondaryMouseButton);
      await tester.pump();
      expect(state.document.root.children, hasLength(2));
      await unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}
