import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';
import 'package:node_diary/core/services/journal_import_html.dart';
import 'package:node_diary/core/services/journal_import_markdown.dart';

void main() {
  group('JournalHtmlConverter 富格式导入', () {
    test('识别 sup/sub 上下标', () {
      final writer = JournalDeltaWriter();
      JournalHtmlConverter(writer)
          .appendHtml('<p>H<sub>2</sub>O 和 E=mc<sup>2</sup></p>');
      final result = writer.build();
      expect(result.contentJson, contains('"script":"sub"'));
      expect(result.contentJson, contains('"script":"super"'));
      expect(result.contentText, contains('H2O'));
      expect(result.contentText, contains('E=mc2'));
    });

    test('识别 CSS vertical-align 上下标', () {
      final writer = JournalDeltaWriter();
      JournalHtmlConverter(writer).appendHtml(
        '<p><span style="vertical-align: super;">上标</span>文本</p>',
      );
      final result = writer.build();
      expect(result.contentJson, contains('"script":"super"'));
    });

    test('CSS vertical-align: baseline 取消继承的上标', () {
      final writer = JournalDeltaWriter();
      JournalHtmlConverter(writer).appendHtml(
        '<p><span style="vertical-align: super;">上<span style="vertical-align: baseline;">正</span></span></p>',
      );
      final result = writer.build();
      // "上"带 script，"正"不带
      expect(result.contentJson, contains('"script":"super"'));
    });

    test('h4-h6 标题保留级别不再压到3级', () {
      final writer = JournalDeltaWriter();
      JournalHtmlConverter(writer)
          .appendHtml('<h4>四级标题</h4><h6>六级标题</h6>');
      final result = writer.build();
      expect(result.contentJson, contains('"header":4'));
      expect(result.contentJson, contains('"header":6'));
    });

    test('details/summary 折叠块展开不丢数据', () {
      final writer = JournalDeltaWriter();
      JournalHtmlConverter(writer).appendHtml(
        '<details><summary>点击展开</summary><p>隐藏的内容</p></details>',
      );
      final result = writer.build();
      expect(result.contentText, contains('点击展开'));
      expect(result.contentText, contains('隐藏的内容'));
      // summary 标题加粗
      expect(result.contentJson, contains('"bold":true'));
    });

    test('table 表格展开为文字不丢数据', () {
      final writer = JournalDeltaWriter();
      JournalHtmlConverter(writer).appendHtml(
        '<table><tr><th>姓名</th><th>年龄</th></tr>'
        '<tr><td>张三</td><td>20</td></tr></table>',
      );
      final result = writer.build();
      expect(result.contentText, contains('姓名'));
      expect(result.contentText, contains('年龄'));
      expect(result.contentText, contains('张三'));
      expect(result.contentText, contains('20'));
    });
  });

  group('JournalMarkdownConverter 富格式导入', () {
    test('h4-h6 标题保留级别', () {
      final writer = JournalDeltaWriter();
      JournalMarkdownConverter(writer).append('#### 四级\n###### 六级');
      final result = writer.build();
      expect(result.contentJson, contains('"header":4'));
      expect(result.contentJson, contains('"header":6'));
    });

    test('行内 HTML 上下标（inlineHtml 开启时）', () {
      final writer = JournalDeltaWriter();
      JournalMarkdownConverter(
        writer,
        inlineHtml: true,
      ).append('H<sub>2</sub>O');
      final result = writer.build();
      expect(result.contentJson, contains('"script":"sub"'));
      expect(result.contentText, contains('H2O'));
    });

    test('GFM 表格以文本行保留不丢数据', () {
      final writer = JournalDeltaWriter();
      JournalMarkdownConverter(writer).append(
        '| 姓名 | 年龄 |\n|------|------|\n| 张三 | 20 |',
      );
      final result = writer.build();
      expect(result.contentText, contains('姓名'));
      expect(result.contentText, contains('张三'));
      expect(result.contentText, contains('20'));
    });
  });
}
