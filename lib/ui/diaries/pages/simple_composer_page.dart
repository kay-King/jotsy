import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/debounced_auto_save_controller.dart';
import 'package:node_diary/ui/diaries/controllers/simple_composer_controller.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/widgets/simple_composer_image_grid.dart';

/// 简洁编辑器（fakeWechat 写日记样式）：纯文本 + 图片九宫格。
///
/// 从桌面“写点什么”进入；日历/日记页仍走原来的富文本编辑器。
/// 正文最多 2000 字，图片最多 9 张（九宫格，满 9 张后“+”消失）。
/// 写出来的日记进同一张 diaries 表，所以日记页、时间线都能同步看到，
/// 并在 metadata 里打 `simpleComposer: true` 标记。
///
/// 自动保存：写着写着手滑退出了也不丢——输入与选图都会防抖写进草稿箱
/// （与富文本草稿同表，`simpleComposer: true` 标记，只有简洁编辑器会
/// 续写它）；下次点“写点什么”直接回到没写完的那篇。发表后草稿删除。
/// 图片在选图时就拷进日记私有目录（草稿要引用稳定路径），发表时不再
/// 重复导入；内容清空后草稿自动删掉（等于放弃这篇）。
///
/// 编辑已有文章：简洁模式写过的、内容还是纯文本的，重新编辑时给选择
/// （简洁 / 完整）；选简洁就进这里的编辑模式（[editDiaryId] 不为空），
/// 此时不走草稿自动保存，点“保存”直接改那篇（标题、正文、封面），
/// 标签、日记本、发表时间都不动，标记保留，下次还给选择。
class SimpleComposerPage extends ConsumerStatefulWidget {
  const SimpleComposerPage({
    super.key,
    this.draftId,
    this.initialDraft,
    this.editDiaryId,
    this.editTagIds = const <int>[],
    this.initialText,
    this.initialImages,
  });

  /// 续写用的草稿 id（没有时为 null，即全新一篇）。
  final String? draftId;

  /// 续写用的草稿内容（没有时为 null，即全新一篇）。
  final NewDiaryDraft? initialDraft;

  /// 编辑已有文章时那篇的日记 id（不为空即编辑模式，不走草稿自动保存）。
  final String? editDiaryId;

  /// 编辑模式时保留的标签 id（更新时原样传回，不动标签）。
  final List<int> editTagIds;

  /// 编辑模式时还原的正文（纯文本）。
  final String? initialText;

  /// 编辑模式时还原的图片路径（已在私有目录里）。
  final List<String>? initialImages;

  @override
  ConsumerState<SimpleComposerPage> createState() => _SimpleComposerPageState();
}

class _SimpleComposerPageState extends ConsumerState<SimpleComposerPage>
    with WidgetsBindingObserver {
  static const int _maxTextLength = 2000;
  static const int _maxImages = 9;

  final TextEditingController _textController = TextEditingController();
  List<String> _imagePaths = <String>[];
  String? _draftId;
  bool _publishing = false;
  DebouncedAutoSaveController<NewDiaryDraftSnapshot>? _autoSave;

  /// 编辑已有文章（简洁模式写过的）；否则是写新的一篇。
  bool get _isEditMode => widget.editDiaryId != null;

  bool get _canPublish =>
      !_publishing &&
      (_textController.text.trim().isNotEmpty || _imagePaths.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    final initialDraft = widget.initialDraft;
    if (initialDraft != null) {
      _textController.text = initialDraft.contentText;
      _imagePaths = SimpleComposerController.imagePathsFromContentDocJson(
        initialDraft.contentDocJson,
      );
    }
    if (_isEditMode) {
      // 编辑模式：还原那篇的正文与图片，不走草稿自动保存（那篇已在库里，
      // 退出不发表即等于放弃这次修改，原篇不动）。
      _textController.text = widget.initialText ?? '';
      _imagePaths = List<String>.of(widget.initialImages ?? const <String>[]);
      return;
    }
    _initAutoSave();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切到后台时把最后一版内容落盘（返回/页面销毁时 dispose 里也会 flush）。
    if (state == AppLifecycleState.paused) {
      unawaited(_autoSave?.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 页面销毁前把最后一版内容落盘（快照在 flush 当帧同步读出，
    // 之后控制器释放也不影响已开始的写入）。
    unawaited(_autoSave?.flush());
    _autoSave?.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _initAutoSave() {
    _autoSave = DebouncedAutoSaveController<NewDiaryDraftSnapshot>(
      debounce: const Duration(milliseconds: 500),
      readSnapshot: _readSnapshot,
      writeSnapshot: _writeSnapshot,
      onError: (_) {},
    );
    _autoSave!.initialize(_readSnapshot());
  }

  NewDiaryDraftSnapshot _readSnapshot() {
    return SimpleComposerController.buildDraftSnapshot(
      text: _textController.text,
      imagePaths: _imagePaths,
    );
  }

  Future<void> _writeSnapshot(NewDiaryDraftSnapshot snapshot) async {
    final database = ref.read(appDatabaseProvider);
    if (!snapshot.hasContent) {
      // 内容被清空了，草稿没意义，删掉（用户清掉文字和图片即等于放弃这篇）。
      if (_draftId != null) {
        await database.deleteDiaryDrafts([_draftId!]);
        _draftId = null;
      }
      return;
    }
    _draftId = await database.saveDiaryDraft(
      draftId: _draftId,
      title: snapshot.title,
      contentText: snapshot.contentText,
      payload: snapshot.payload,
    );
  }

  Future<void> _pickImages() async {
    if (_imagePaths.length >= _maxImages) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
      withReadStream: true,
    );
    final files = result?.files ?? const <PlatformFile>[];
    if (!mounted || files.isEmpty) return;
    final room = _maxImages - _imagePaths.length;
    final picked = files.take(room).toList();
    // 选图即拷进日记私有目录：草稿要引用稳定路径（相册原路径可能被
    // 清理），发表时直接用这些路径，不再重复导入。
    final importedPaths = <String>[];
    for (final file in picked) {
      try {
        final imported = await DiaryMediaStorageService.importFile(
          kind: DiaryMediaKind.image,
          fileName: file.name,
          sourcePath: file.path,
          readStream: file.readStream,
          bytes: file.bytes,
        );
        importedPaths.add(imported.path);
      } catch (_) {
        // 单张导入失败就跳过这张，不影响其他图。
        continue;
      }
    }
    if (!mounted || importedPaths.isEmpty) return;
    setState(() {
      _imagePaths.addAll(importedPaths);
    });
    _autoSave?.schedule();
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _publishing = true);
    try {
      if (_isEditMode) {
        // 编辑模式：直接改那篇，不走草稿（没有草稿可删，退出即放弃修改）。
        final database = ref.read(appDatabaseProvider);
        await SimpleComposerController(database).update(
          diaryId: widget.editDiaryId!,
          text: _textController.text,
          imagePaths: _imagePaths,
          tagIds: widget.editTagIds,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      // 先停掉自动保存并等进行中的写入结束，再删草稿，否则防抖窗口里
      // 已开始的写入可能在删除之后落盘，把已发布的草稿重新写回去。
      await _autoSave?.close();
      _autoSave = null;
      final database = ref.read(appDatabaseProvider);
      await SimpleComposerController(
        database,
      ).publish(text: _textController.text, imagePaths: _imagePaths);
      if (_draftId != null) {
        await database.deleteDiaryDrafts([_draftId!]);
        _draftId = null;
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishing = false);
      if (_isEditMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.simpleComposerSaveFailed)),
        );
        return;
      }
      // 发表失败，草稿还在（发表失败不删草稿），重新接上自动保存，
      // 用户改完能继续自动存。
      _initAutoSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.simpleComposerSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textLength = _textController.text.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _isEditMode ? l10n.simpleComposerEditTitle : l10n.simpleComposerTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: _canPublish ? _publish : null,
            child: Text(
              _isEditMode
                  ? l10n.simpleComposerSave
                  : l10n.simpleComposerPublish,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _textController,
                        maxLines: null,
                        minLines: 8,
                        maxLength: _maxTextLength,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        onChanged: (_) {
                          setState(() {});
                          _autoSave?.schedule();
                        },
                        decoration: InputDecoration(
                          hintText: l10n.simpleComposerHint,
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      SimpleComposerImageGrid(
                        imagePaths: _imagePaths,
                        maxImages: _maxImages,
                        onAdd: _pickImages,
                        onRemove: (index) {
                          setState(() => _imagePaths.removeAt(index));
                          _autoSave?.schedule();
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.simpleComposerMaxImages,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$textLength/$_maxTextLength',
                  style: TextStyle(
                    fontSize: 13,
                    color: textLength > 1900
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  children: <TextSpan>[
                    TextSpan(text: l10n.simpleComposerTipPrefix),
                    TextSpan(
                      text: l10n.simpleComposerTipBold,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: l10n.simpleComposerTipSuffix),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
