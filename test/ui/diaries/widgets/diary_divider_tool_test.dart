import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_divider_block.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';

/// 工具栏「分隔线」（v0.11.0 #127）：在光标所在块后插入一条分隔线，后面
/// 跟一个空段落、光标落进去接着写；一步撤销。

Node _paragraph(String text) => Node(
  type: kDiaryBlockParagraph,
  attributes: <String, dynamic>{
    kDiaryBlockDeltaKey: (Delta()..insert(text)).toJson(),
  },
);

/// 光标落在 [text] 段落的行尾（blank 自带一个空段落）。
Future<EditorState> _editorState({String? text}) async {
  final editorState = EditorState.blank(withInitialText: true);
  addTearDown(editorState.dispose);
  editorState.selection = Selection.collapsed(
    Position(path: [0], offset: text == null ? 0 : text.length),
  );
  if (text != null) {
    final transaction = editorState.transaction;
    transaction.insertText(editorState.document.root.children.first, 0, text);
    await editorState.apply(transaction);
  }
  return editorState;
}

void main() {
  group('insertDiaryDividerBlock', () {
    test('插到光标段落后：分隔线 + 空段落，光标进空段落开头', () async {
      final editorState = await _editorState(text: 'hello');

      await insertDiaryDividerBlock(editorState);

      final children = editorState.document.root.children;
      expect(children, hasLength(3));
      expect(children[0].type, kDiaryBlockParagraph);
      expect(children[0].delta!.toPlainText(), 'hello');
      expect(children[1].type, kDiaryBlockDivider);
      expect(children[2].type, kDiaryBlockParagraph);
      expect(children[2].delta!.toPlainText(), isEmpty);
      expect(
        editorState.selection,
        Selection.collapsed(Position(path: [2])),
      );
    });

    test('无选区时插到文档末尾', () async {
      final editorState = await _editorState(text: 'hello');
      editorState.selection = null;

      await insertDiaryDividerBlock(editorState);

      final children = editorState.document.root.children;
      expect(children, hasLength(3));
      expect(children[1].type, kDiaryBlockDivider);
      expect(children[2].type, kDiaryBlockParagraph);
      expect(
        editorState.selection,
        Selection.collapsed(Position(path: [2])),
      );
    });

    test('一次事务：一步撤销回到插入前', () async {
      // 直接构造文档：避免 helper 里的 insertText 事务与插入事务在
      // undo 的防抖窗口内合并成一步。
      final editorState = EditorState(
        document: Document(
          root: Node(type: kDiaryBlockPage, children: [_paragraph('hello')]),
        ),
      );
      addTearDown(editorState.dispose);
      editorState.selection = Selection.collapsed(
        Position(path: [0], offset: 5),
      );

      await insertDiaryDividerBlock(editorState);
      expect(editorState.document.root.children.length, 3);
      editorState.undoManager.undo();
      expect(editorState.document.root.children.length, 1);
      expect(
        editorState.document.root.children.single.delta?.toPlainText(),
        'hello',
      );
    });
  });

  group('DiaryToolbarItem.divider', () {
    test('默认顺序里紧跟表格，存储键与图标、文案齐全', () {
      final order = kDefaultDiaryToolbarOrder;
      expect(
        order.indexOf(DiaryToolbarItem.divider),
        order.indexOf(DiaryToolbarItem.table) + 1,
      );
      expect(DiaryToolbarItem.divider.storageKey, 'divider');
      expect(DiaryToolbarItem.divider.iconData, FontAwesomeIcons.minus);

      final l10n = lookupAppLocalizations(const Locale('zh'));
      expect(DiaryToolbarItem.divider.label(l10n), '分隔线');
      final en = lookupAppLocalizations(const Locale('en'));
      expect(DiaryToolbarItem.divider.label(en), 'Divider');
    });

    test('已保存过的旧顺序解码时补到末尾', () {
      const legacySavedOrder =
          'undo,redo,recording,bold,italic,underline,bullet_list,check_list,'
          'ordered_list,image,video,attachment,current_time,quote,'
          'header_style,link,text_color,background_color,clear_format,'
          'strike_through,indent,inline_code,code_block,table,toggle_list,'
          'callout';

      final decoded = decodeDiaryToolbarOrder(legacySavedOrder);

      expect(decoded.last, DiaryToolbarItem.divider);
      expect(decoded, containsAll(kDefaultDiaryToolbarOrder));
    });
  });
}
