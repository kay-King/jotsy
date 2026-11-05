import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';
import 'package:node_diary/ui/diaries/widgets/diary_quote_bar.dart';

/// 引用竖条连线（v0.11.0 #134）：相邻的引用块竖条连成一条。

Node _quote(String text, {Map<String, dynamic>? attributes}) {
  return Node.fromJson(<String, Object>{
    'type': kDiaryBlockQuote,
    'data': <String, Object>{
      'delta': [
        {'insert': text},
      ],
      if (attributes != null) ...attributes,
    },
  });
}

Node _paragraph(String text) {
  return Node.fromJson(<String, Object>{
    'type': ParagraphBlockKeys.type,
    'data': <String, Object>{
      'delta': [
        {'insert': text},
      ],
    },
  });
}

/// 把 [nodes] 挂进同一父块，返回父块（兄弟关系由此建立）。
Node _siblings(List<Node> nodes) {
  return Node(type: 'page', children: nodes);
}

void main() {
  group('diaryQuoteBarsJoin', () {
    test('相邻的两行引用连成一条', () {
      final parent = _siblings([_quote('第一行'), _quote('第二行')]);
      final upper = parent.children[0];
      final lower = parent.children[1];
      expect(diaryQuoteBarsJoin(upper, lower), isTrue);
    });

    test('中间隔着正文段落时不连', () {
      final parent = _siblings([
        _quote('第一行'),
        _paragraph('正文'),
        _quote('第三行'),
      ]);
      expect(
        diaryQuoteBarsJoin(parent.children[0], parent.children[2]),
        isFalse,
      );
    });

    test('上一块不是引用时不连', () {
      final parent = _siblings([_paragraph('正文'), _quote('引用')]);
      expect(
        diaryQuoteBarsJoin(parent.children[0], parent.children[1]),
        isFalse,
      );
    });

    test('下一块不是引用时不连', () {
      final parent = _siblings([_quote('引用'), _paragraph('正文')]);
      expect(
        diaryQuoteBarsJoin(parent.children[0], parent.children[1]),
        isFalse,
      );
    });

    test('任一块居中/靠右/靠左对齐时不连', () {
      for (final align in ['center', 'right', 'left']) {
        final parent = _siblings([
          _quote('第一行', attributes: {'align': align}),
          _quote('第二行'),
        ]);
        expect(
          diaryQuoteBarsJoin(parent.children[0], parent.children[1]),
          isFalse,
          reason: align,
        );
        final parent2 = _siblings([
          _quote('第一行'),
          _quote('第二行', attributes: {'align': align}),
        ]);
        expect(
          diaryQuoteBarsJoin(parent2.children[0], parent2.children[1]),
          isFalse,
          reason: align,
        );
      }
    });

    test('两端对齐时照样连', () {
      final parent = _siblings([
        _quote('第一行', attributes: {'align': 'justify'}),
        _quote('第二行', attributes: {'align': 'justify'}),
      ]);
      expect(
        diaryQuoteBarsJoin(parent.children[0], parent.children[1]),
        isTrue,
      );
    });

    test('文字方向设置不同或为 auto 时不连', () {
      final parent = _siblings([
        _quote('第一行', attributes: {'textDirection': 'ltr'}),
        _quote('第二行', attributes: {'textDirection': 'rtl'}),
      ]);
      expect(
        diaryQuoteBarsJoin(parent.children[0], parent.children[1]),
        isFalse,
      );
      final parent2 = _siblings([
        _quote('第一行', attributes: {'textDirection': 'auto'}),
        _quote('第二行', attributes: {'textDirection': 'auto'}),
      ]);
      expect(
        diaryQuoteBarsJoin(parent2.children[0], parent2.children[1]),
        isFalse,
      );
    });

    test('文字方向设置相同时连', () {
      final parent = _siblings([
        _quote('第一行', attributes: {'textDirection': 'ltr'}),
        _quote('第二行', attributes: {'textDirection': 'ltr'}),
      ]);
      expect(
        diaryQuoteBarsJoin(parent.children[0], parent.children[1]),
        isTrue,
      );
    });

    test('null 邻块时不连', () {
      final parent = _siblings([_quote('只有一行')]);
      expect(diaryQuoteBarsJoin(null, parent.children[0]), isFalse);
      expect(diaryQuoteBarsJoin(parent.children[0], null), isFalse);
    });
  });

  group('DiaryQuoteBarPainter', () {
    test('两端都不相接时画圆头竖条，不相接时 shouldRepaint 为 false', () {
      const painter = DiaryQuoteBarPainter(color: Colors.blue);
      expect(painter.shouldRepaint(painter), isFalse);
      expect(
        painter.shouldRepaint(
          const DiaryQuoteBarPainter(color: Colors.blue, extendTop: 4),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(const DiaryQuoteBarPainter(color: Colors.red)),
        isTrue,
      );
    });
  });

  group('DiaryQuoteBar widget', () {
    testWidgets('单独的引用竖条正常渲染，不抛异常', (tester) async {
      final parent = _siblings([_quote('引用文字')]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiaryQuoteBar(
              node: parent.children[0],
              blockInsets: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('相邻引用的竖条正常渲染，不抛异常', (tester) async {
      final parent = _siblings([_quote('第一行'), _quote('第二行')]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DiaryQuoteBar(
                  node: parent.children[0],
                  blockInsets: const EdgeInsets.symmetric(vertical: 4),
                ),
                DiaryQuoteBar(
                  node: parent.children[1],
                  blockInsets: const EdgeInsets.symmetric(vertical: 4),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
