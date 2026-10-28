import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';

/// 简洁编辑器的发布与草稿流程。
///
/// 发表：图片已在选图时拷进日记私有目录（草稿要引用稳定路径），这里只
/// 组装 Delta → 写库。发表后调用方删掉对应草稿。
///
/// 草稿：与富文本草稿同存 `diary_drafts` 表，每次新建独立一行；用
/// `simpleComposer: true` 标记，只有简洁编辑器会续写它（富文本入口
/// 不认它，避免简洁草稿被富文本打开后丢掉简单形态）。自动保存由页面
/// 经 `DebouncedAutoSaveController` 防抖驱动，本类只提供快照与读写。
class SimpleComposerController {
  SimpleComposerController(this.database);

  final AppDatabase database;

  /// 简洁模式写的日记在 metadata 里打的标记（JSON 对象里一个键）。
  ///
  /// 重新编辑时认这个标记：只有简洁模式写过的才给“简洁 / 完整”二选一，
  /// 标准模式写的直进标准编辑器（简洁模式打不开带格式的）。标记本身不
  /// 保证内容仍是纯文本——标准模式改过后可能带了格式，所以重新编辑时
  /// 还要过 [tryExtractSimpleContent] 那道兼容检查。
  static const String simpleComposerMetadataKey = 'simpleComposer';

  static String get simpleComposerMetadataJson =>
      jsonEncode(<String, Object?>{simpleComposerMetadataKey: true});

  /// 这篇是不是简洁模式写的（metadata 里带标记）。
  static bool isSimpleComposerEntry(String metadataJson) {
    try {
      final decoded = jsonDecode(metadataJson);
      return decoded is Map<String, dynamic> &&
          decoded[simpleComposerMetadataKey] == true;
    } catch (_) {
      return false;
    }
  }

  /// 发表一篇纯文本 + 图片的日记，返回新日记 id。
  ///
  /// [text] 为用户输入的纯文本（可能为空，即只有图片）；
  /// [imagePaths] 为已导入私有目录的图片路径（最多 9 张，由页面保证数量）。
  /// 失败时抛异常，由页面提示并留在本页。
  Future<String> publish({
    required String text,
    required List<String> imagePaths,
  }) async {
    final trimmedText = text.trimRight();
    final contentDocJson = buildContentDocJson(trimmedText, imagePaths);
    final title = titleFromText(trimmedText);
    return database.createDiary(
      title: title,
      contentDocJson: contentDocJson,
      contentText: trimmedText,
      metadataJson: simpleComposerMetadataJson,
      cover: imagePaths.isEmpty ? null : imagePaths.first,
    );
  }

  /// 用简洁编辑器改一篇已有的日记（只改标题、正文、封面与更新时间）。
  ///
  /// 标签与日记本不动（[tagIds] 传这篇现有的标签 id，[notebookIds] 不传
  /// 即不动）；发表时间不动；metadata 里保留简洁模式标记，下次重新
  /// 编辑还给选择。失败时抛异常，由页面提示并留在本页。
  Future<void> update({
    required String diaryId,
    required String text,
    required List<String> imagePaths,
    required List<int> tagIds,
  }) async {
    final trimmedText = text.trimRight();
    await database.updateDiary(
      diaryId: diaryId,
      title: titleFromText(trimmedText),
      contentDocJson: buildContentDocJson(trimmedText, imagePaths),
      contentText: trimmedText,
      metadataJson: simpleComposerMetadataJson,
      cover: imagePaths.isEmpty ? null : imagePaths.first,
      tagIds: tagIds,
    );
  }

  /// 当前内容拼成草稿快照（自动保存用，`payload` 即 NewDiaryDraft JSON）。
  ///
  /// 标题取正文第一行（与发表时一致）；`simpleComposer: true` 标记
  /// 这份草稿只由简洁编辑器续写。
  static NewDiaryDraftSnapshot buildDraftSnapshot({
    required String text,
    required List<String> imagePaths,
  }) {
    final trimmedText = text.trimRight();
    final draft = NewDiaryDraft(
      title: titleFromText(trimmedText),
      contentDocJson: buildContentDocJson(trimmedText, imagePaths),
      contentText: trimmedText,
      cover: imagePaths.isEmpty ? null : imagePaths.first,
      simpleComposer: true,
    );
    return draft.toSnapshot();
  }

  /// 正文 Delta：纯文本 + 每张图一个图片块（各占一行），与富文本编辑器
  /// 插图的格式一致，日记页/时间线/预览都能正常渲染。
  static String buildContentDocJson(String text, List<String> imagePaths) {
    final delta = Delta();
    if (text.isNotEmpty) {
      delta.insert('$text\n');
    }
    for (final path in imagePaths) {
      delta.insert(quill.BlockEmbed.image(path));
      delta.insert('\n');
    }
    return jsonEncode(delta.toJson());
  }

  /// 从一份 Delta JSON 里取出图片块的路径（续写草稿时还原九宫格）。
  /// 解析失败或没有图片块时返回空列表。
  static List<String> imagePathsFromContentDocJson(String contentDocJson) {
    try {
      final decoded = jsonDecode(contentDocJson);
      if (decoded is! List) return const <String>[];
      final paths = <String>[];
      for (final op in decoded) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is! Map) continue;
        final image = insert['image'];
        if (image is String && image.isNotEmpty) paths.add(image);
      }
      return paths;
    } catch (_) {
      return const <String>[];
    }
  }

  /// 判断一份 Delta 能不能用简洁编辑器打开，能就返回纯文本与图片。
  ///
  /// 简洁编辑器只认纯文本 + 图片：任何文字带了属性（加粗、颜色、标题、
  /// 列表等）、任何非图片的嵌入（视频、音频、附件等）或图片超 9 张，
  /// 都返回 null（重新编辑时直进标准编辑器，不给选择）。正文不限字数，
  /// 写多长都能用简洁编辑器重新打开。文本按操作顺序拼接，末尾的换行
  /// 去掉；图片只取 image 块的路径。
  static ({String text, List<String> images})? tryExtractSimpleContent(
    String contentDocJson,
  ) {
    try {
      final decoded = jsonDecode(contentDocJson);
      if (decoded is! List) return null;
      final textBuffer = StringBuffer();
      final images = <String>[];
      for (final op in decoded) {
        if (op is! Map<String, dynamic>) return null;
        if (op.containsKey('retain') || op.containsKey('delete')) {
          return null;
        }
        final insert = op['insert'];
        final attributes = op['attributes'];
        if (insert is String) {
          // 带属性的文字（包括带块属性的换行，如标题、列表）都不认。
          if (attributes != null) return null;
          textBuffer.write(insert);
        } else if (insert is Map<String, dynamic>) {
          if (attributes != null) return null;
          final image = insert['image'];
          if (image is String && image.isNotEmpty) {
            images.add(image);
          } else {
            // 视频、音频、附件等其他嵌入都不认。
            return null;
          }
        } else {
          return null;
        }
      }
      var text = textBuffer.toString();
      // 简洁编辑器发表时正文末尾带一个换行，这里还原成用户输入的样子。
      while (text.endsWith('\n')) {
        text = text.substring(0, text.length - 1);
      }
      if (images.length > 9) return null;
      return (text: text, images: images);
    } catch (_) {
      return null;
    }
  }

  /// 找出最近一份简洁编辑器的草稿（按更新时间倒序，第一份带
  /// `simpleComposer: true` 标记的）。没有时返回 null。
  ///
  /// 草稿通常只有几份到几十份，全表按更新倒序读再逐条解析 payload
  /// 即可，不建索引（与草稿表“按更新时间倒序全表读取”的设计一致）。
  Future<({String draftId, NewDiaryDraft draft})?>
  findLatestSimpleDraft() async {
    final rows = await database.getRecentDiaryDrafts(50);
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.payload);
        if (decoded is! Map<String, dynamic>) continue;
        final draft = NewDiaryDraft.fromJson(decoded.cast<String, Object?>());
        if (draft.simpleComposer && draft.hasContent) {
          return (draftId: row.draftId, draft: draft);
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// 标题取正文第一行（与草稿列表“标题空时取第一行”的规则一致）；
  /// 只有图片时标题为空，卡片显示“无标题”。
  static String titleFromText(String text) {
    final firstLine = text
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return '';
    const maxTitleLength = 100;
    return firstLine.length <= maxTitleLength
        ? firstLine
        : firstLine.substring(0, maxTitleLength);
  }
}
