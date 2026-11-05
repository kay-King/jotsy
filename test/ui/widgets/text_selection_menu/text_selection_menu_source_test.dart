import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 全应用输入框统一使用 `appTextContextMenuBuilder`：lib 下每一个
/// TextField / TextFormField / SelectableText / SearchBar 构造点都必须
/// 传 `contextMenuBuilder: appTextContextMenuBuilder`（手机玻璃胶囊 /
/// 桌面竖排菜单；密码框自动无复制分享），不得留用 Flutter 默认菜单。
///
/// 不算构造点：名字里带这些后缀的自定义组件（如 PublishTagSearchBar，
/// 它内部的 TextField 另行检查）；已有自定义 `contextMenuBuilder` 的
/// 非输入框（如 AppFlowyEditor 的正文右键菜单）也不在本检查内。
void main() {
  test('every text input uses appTextContextMenuBuilder', () {
    final construction = RegExp(
      r'(?<![A-Za-z0-9_])(TextField|TextFormField|SelectableText|SearchBar)\s*\(',
    );
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);

    final offenders = <String>[];
    final filesWithoutBuilder = <String>[];
    var constructions = 0;
    for (final file in files) {
      final source = file.readAsStringSync();
      final matches = construction.allMatches(source).toList();
      if (matches.isEmpty) continue;
      if (!source.contains('appTextContextMenuBuilder')) {
        filesWithoutBuilder.add(file.path);
      }
      for (final match in matches) {
        constructions++;
        // 注释里提到构造名不算。
        final lineStart = source.lastIndexOf('\n', match.start) + 1;
        if (source.substring(lineStart, match.start).contains('//')) {
          continue;
        }
        final open = source.indexOf('(', match.start);
        final close = _matchingParen(source, open);
        if (close == -1) {
          offenders.add('${file.path} has an unclosed ${match.group(1)}');
          continue;
        }
        if (!source
            .substring(open, close + 1)
            .contains('contextMenuBuilder: appTextContextMenuBuilder')) {
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add(
            '${file.path}:$line ${match.group(1)} lacks '
            'contextMenuBuilder: appTextContextMenuBuilder',
          );
        }
      }
    }
    expect(
      constructions,
      isNot(0),
      reason: 'no text input construction found; the scan is broken',
    );
    expect(filesWithoutBuilder, isEmpty);
    expect(offenders, isEmpty);
  });
}

bool _isWordChar(String char) => RegExp(r'[A-Za-z0-9_]').hasMatch(char);

/// 与 [open] 处的 `(` 配对的 `)` 下标；找不到返回 -1。
///
/// 括号计数跳过注释与字符串里的括号（如 hintText 里的括号），字符串含
/// 转义、`r` 前缀与三引号都按 Dart 语义处理。
int _matchingParen(String source, int open) {
  var depth = 0;
  String? quote;
  var triple = false;
  var raw = false;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (lineComment) {
      if (char == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char == '*' && next == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (!raw && escaped) {
        escaped = false;
        continue;
      }
      if (!raw && char == '\\') {
        escaped = true;
        continue;
      }
      if (triple) {
        if (char == quote &&
            next == quote &&
            i + 2 < source.length &&
            source[i + 2] == quote) {
          quote = null;
          triple = false;
          i += 2;
        }
        continue;
      }
      if (char == quote) quote = null;
      continue;
    }
    if (char == '/' && next == '/') {
      lineComment = true;
      i++;
      continue;
    }
    if (char == '/' && next == '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (char == "'" || char == '"') {
      triple = source.startsWith(char * 3, i);
      raw =
          i > 0 &&
          source[i - 1] == 'r' &&
          (i < 2 || !_isWordChar(source[i - 2]));
      quote = char;
      if (triple) i += 2;
      continue;
    }
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
