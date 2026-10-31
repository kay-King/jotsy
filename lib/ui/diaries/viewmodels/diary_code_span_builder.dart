import 'dart:math' as math;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../core/database/diary_blocks/diary_blocks_schema.dart';
import '../controllers/diary_code_language_tracker.dart';
import '../models/diary_code_block/diary_code_block_newline.dart';
import '../models/diary_code_block/diary_code_highlighter.dart';
import '../models/diary_code_block/diary_code_language.dart';
import '../models/diary_code_block/diary_code_theme.dart';
import 'diary_code_block_look.dart';

// 把代码块的语法高亮接进 AppFlowy 的文本渲染。
//
// 输入：编辑器按 delta 建出的文本 span、代码块节点、解析好的
// [DiaryCodeBlockLook] 与该编辑器的 [DiaryCodeLanguageTracker]。
// 输出：[buildDiaryCodeSpan] 把整块 span 按高亮区间重新拆成带颜色的子
// span，供代码块组件的 `textSpanDecorator` 使用。
// 副作用：无（识别结果的防抖由 tracker 负责）。
//
// 与 Quill 时代的差异：原来是 `textSpanBuilder` 钩子按叶子（一段同样式
// 的文字）调用；AppFlowy 时代是 `textSpanDecorator`，拿到整块建好的
// span 再整体变换。语义不变：
// - 高亮必须看整块（多行字符串、块注释跨行），区间按“帧”缓存在节点上，
//   同一帧里只算一次，避免长代码块每帧 O(行数²) 地拼接文本；
// - 叶子自带文字色（用户手动上色）时尊重用户的颜色，只保留注释的斜体；
// - 空隙不设样式，继承代码文字样式；
// - 超限的块不拼接、不识别、不着色；
// - 变换前后纯文本必须与 delta 一致（光标偏移按它定位），对不上时原样
//   返回，只是不着色。

/// 代码块用于高亮的语言：明确指定的语言 id；'plain' 不高亮；未指定时按
/// [autoDetect] 取自动识别结果（关闭时不高亮）。
String? resolveDiaryCodeHighlightLanguage(
  Node block,
  String blockText, {
  required bool autoDetect,
  required DiaryCodeLanguageTracker tracker,
}) {
  final choice = DiaryCodeLanguageChoice.fromAttributeValue(
    block.attributes[kDiaryBlockLanguageKey],
  );
  if (choice.isPlain) {
    tracker.cancelPendingFor(block);
    return null;
  }
  final explicit = choice.languageId;
  if (explicit != null) {
    tracker.cancelPendingFor(block);
    return explicit;
  }
  if (!autoDetect) {
    tracker.cancelPendingFor(block);
    return null;
  }
  return tracker.languageFor(block, blockText);
}

/// 代码块文字的高亮变换：把 [span] 按语法高亮区间拆成带颜色的子 span。
///
/// [span] 是编辑器按节点 delta 建出的文本；根样式换成代码文字样式
/// （[DiaryCodeBlockLook.codeTextStyle]），空隙继承它。delta 里带
/// `font_color` 的叶子只叠 token 的字形（如注释斜体），颜色保留用户的。
///
/// 非代码块节点原样返回；纯文本对不上 delta、超限块或无高亮时根样式仍
/// 换成代码文字样式（保证等宽字体），只是不着色。
TextSpan buildDiaryCodeSpan(
  TextSpan span, {
  required Node node,
  required DiaryCodeBlockLook look,
  required DiaryCodeLanguageTracker tracker,
}) {
  TextSpan styled(TextSpan source) => source.style == look.codeTextStyle
      ? source
      : TextSpan(
          text: source.text,
          style: look.codeTextStyle,
          children: source.children,
          recognizer: source.recognizer,
          mouseCursor: source.mouseCursor,
          semanticsLabel: source.semanticsLabel,
        );

  if (!isDiaryCodeBlock(node)) {
    return span;
  }
  final delta = node.delta;
  final text = span.toPlainText();
  // 变换前后纯文本必须与 delta 一致，否则光标偏移对不上：按默认方式渲染
  //（只是不着色）。
  if (delta == null || text != delta.toPlainText()) {
    return styled(span);
  }
  if (text.isEmpty) {
    return styled(span);
  }
  // 先看结构尺寸，超限块不识别。delta 长度是 cheap 检查；行数要扫文本，
  // 只在长度通过后才算。否则即使高亮器稍后拒绝，巨大粘贴仍会在每次按键 /
  // 重建时复制整块文本。
  if (delta.length > DiaryCodeHighlighter.maxLength + 1 ||
      _lineCount(text) > DiaryCodeHighlighter.maxLines) {
    tracker.cancelPendingFor(node);
    return styled(span);
  }
  final language = resolveDiaryCodeHighlightLanguage(
    node,
    text,
    autoDetect: look.autoDetect,
    tracker: tracker,
  );
  final tokens = language == null
      ? DiaryCodeTokens.empty
      : _tokensFor(node, text, language);
  if (tokens.isEmpty) {
    return styled(span);
  }

  final palette = look.palette;
  final tokenStyles = <DiaryCodeTokenRole, TextStyle>{
    for (final role in DiaryCodeTokenRole.values)
      role: palette.tokenStyle(role),
  };
  // 叶子自带文字色（用户手动上色）时尊重用户的颜色，只保留注释的斜体。
  final keepColorStyles = <DiaryCodeTokenRole, TextStyle?>{
    for (final MapEntry(key: role, value: tokenStyle) in tokenStyles.entries)
      role: tokenStyle.fontStyle == null
          ? null
          : TextStyle(fontStyle: tokenStyle.fontStyle),
  };

  final leaves = _leavesOf(span);
  // 叶子拼起来必须等于整块文本，否则偏移对不上，原样返回。
  if (leaves.map((leaf) => leaf.text ?? '').join('') != text) {
    return styled(span);
  }

  // 用户手动上色的区间：delta 里带 font_color 属性的 TextInsert 范围。
  // 注意不能看叶子样式的颜色——AppFlowyRichText 给每个叶子都带了默认文字
  // 色（textStyleConfiguration.text），看样式会恒为真、高亮色永远上不去。
  final coloredRanges = <_IntRange>[];
  var insertOffset = 0;
  for (final op in delta) {
    if (op is TextInsert) {
      final end = insertOffset + op.text.length;
      if (op.attributes?[kDiaryInlineTextColor] != null) {
        coloredRanges.add(_IntRange(insertOffset, end));
      }
      insertOffset = end;
    }
  }
  bool hasUserColor(int start, int end) =>
      coloredRanges.any((range) => range.start < end && start < range.end);

  final children = <InlineSpan>[];
  var blockOffset = 0;
  for (final leaf in leaves) {
    final leafText = leaf.text ?? '';
    final start = blockOffset;
    final end = start + leafText.length;
    blockOffset = end;
    final keepColor = hasUserColor(start, end);
    final recognizer = leaf.recognizer;
    final cursor = recognizer == null ? null : SystemMouseCursors.click;
    final pieces = <InlineSpan>[];
    var position = start;
    // 空隙不设样式，继承外层 span（代码文字样式）。
    TextSpan piece(int from, int to, TextStyle? pieceStyle) => TextSpan(
      text: leafText.substring(from - start, to - start),
      style: pieceStyle,
      recognizer: recognizer,
      mouseCursor: cursor,
    );
    for (final token in tokens.overlapping(start, end)) {
      final from = math.max(token.start, start);
      final to = math.min(token.end, end);
      if (from > position) {
        pieces.add(piece(position, from, null));
      }
      pieces.add(
        piece(
          from,
          to,
          keepColor ? keepColorStyles[token.role] : tokenStyles[token.role],
        ),
      );
      position = to;
    }
    if (position < end) {
      pieces.add(piece(position, end, null));
    }
    children.add(
      pieces.isEmpty
          ? leaf
          : TextSpan(
              style: leaf.style,
              recognizer: recognizer,
              mouseCursor: cursor,
              children: pieces,
            ),
    );
  }
  return TextSpan(style: look.codeTextStyle, children: children);
}

/// [span] 的纯文本叶子（按 delta 建出的 span 是按行内 op 排平的，
///
/// 递归以防万一）。WidgetSpan 等非文本叶子会被外层的纯文本 guard 拦掉。
List<TextSpan> _leavesOf(TextSpan span) {
  final children = span.children;
  if (children == null || children.isEmpty) {
    final text = span.text;
    return text == null || text.isEmpty ? const <TextSpan>[] : <TextSpan>[span];
  }
  final leaves = <TextSpan>[];
  for (final child in children) {
    if (child is TextSpan) {
      leaves.addAll(_leavesOf(child));
    }
  }
  return leaves;
}

int _lineCount(String text) => '\n'.allMatches(text).length + 1;

/// 半开区间 [start, end)：用户上色区间的定位用。
class _IntRange {
  const _IntRange(this.start, this.end);

  final int start;
  final int end;
}

/// 某个块在某一帧算出的高亮区间。
class _BlockFrame {
  const _BlockFrame(this.epoch, this.tokens);

  final int epoch;
  final DiaryCodeTokens tokens;
}

final Expando<_BlockFrame> _frames = Expando<_BlockFrame>(
  'diaryCodeBlockFrame',
);

int _frameEpoch = 0;
bool _frameEpochBumpScheduled = false;

/// 当前帧的编号；不在帧的构建阶段（如测试里直接调用）时返回 null，不缓存。
///
/// 只在构建阶段缓存：文档只会在帧与帧之间被改写，同一帧里所有行看到的
/// 是同一份文本。第一次使用时登记一个帧末回调把编号加一，下一帧自然失效。
int? _currentFrameEpoch() {
  final binding = SchedulerBinding.instance;
  if (binding.schedulerPhase != SchedulerPhase.persistentCallbacks) {
    return null;
  }
  if (!_frameEpochBumpScheduled) {
    _frameEpochBumpScheduled = true;
    binding.addPostFrameCallback((_) {
      _frameEpoch++;
      _frameEpochBumpScheduled = false;
    }, debugLabel: 'diaryCodeBlockFrameEpoch');
  }
  return _frameEpoch;
}

DiaryCodeTokens _tokensFor(Node node, String text, String language) {
  final epoch = _currentFrameEpoch();
  if (epoch != null) {
    final cached = _frames[node];
    if (cached != null && cached.epoch == epoch) {
      return cached.tokens;
    }
  }
  final tokens = DiaryCodeHighlighter.instance.tokens(text, language);
  if (epoch != null) {
    _frames[node] = _BlockFrame(epoch, tokens);
  }
  return tokens;
}
