import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../core/services/diary_media_storage_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../notebooks/providers/notebook_providers.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../diary_link_card/diary_link_card.dart';
import '../diary_link_card/diary_link_card_picker.dart';
import 'diary_mention_candidates.dart';
import 'diary_mention_trigger.dart';

/// @ 提及与 / 块菜单的输入浮层。
///
/// 监听 [editorState] 的事务与选区：光标前出现 `@` 时弹出日记 / 日记本
/// 候选（[ExpressiveMenuAnchor]），选中后插入带 `diary://` / `notebook://`
/// 的行内链接；行首出现 `/` 时弹出块菜单（目前只有“日记卡片”）。
///
/// 放在编辑页 body 的 Stack 里（见 `EditDiaryPage`），锚点按光标的全局
/// 位置换算到本层坐标；编辑器滚动时由页面的 ScrollNotification 经
/// [refreshAnchor] 跟随。
class DiaryMentionPopup extends ConsumerStatefulWidget {
  const DiaryMentionPopup({
    super.key,
    required this.editorState,
    this.excludeDiaryId,
    this.editorFocusNode,
    this.onCameraPressed,
  });

  final EditorState editorState;

  /// 正在编辑的日记 id：不把自己列为候选（新建时为 null）。
  final String? excludeDiaryId;

  /// 选中后把焦点还给正文。
  final FocusNode? editorFocusNode;

  /// `/` 菜单里的“拍照 / 录像”（图片 / 视频）；null 时不出现（不支持拍摄
  /// 的平台、只读正文）。编辑页按平台门控给回调，走编辑页的拍摄插入链路，
  /// 这里不直接建控制器。
  final void Function(DiaryMediaKind)? onCameraPressed;

  @override
  ConsumerState<DiaryMentionPopup> createState() => DiaryMentionPopupState();
}

class DiaryMentionPopupState extends ConsumerState<DiaryMentionPopup> {
  StreamSubscription<EditorTransactionValue>? _transactions;
  final MenuController _menuController = MenuController();

  MentionTrigger? _trigger;
  List<DiaryMentionCandidate> _candidates = const [];
  List<Diary>? _diaryCache;
  int _searchSeq = 0;
  Offset? _anchorOffset;

  static bool get _isMobile {
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android ||
        p == TargetPlatform.iOS ||
        p == TargetPlatform.fuchsia;
  }

  @override
  void initState() {
    super.initState();
    _transactions = widget.editorState.transactionStream.listen(
      (_) => _refresh(),
    );
    widget.editorState.selectionNotifier.addListener(_refresh);
  }

  @override
  void dispose() {
    _transactions?.cancel();
    widget.editorState.selectionNotifier.removeListener(_refresh);
    super.dispose();
  }

  /// 编辑器滚动时重算锚点位置（由页面的 ScrollNotification 触发）。
  void refreshAnchor() {
    if (!mounted || _trigger == null) return;
    _updateAnchorOffset();
    setState(() {});
  }

  void _refresh() {
    if (!mounted) return;
    final editorState = widget.editorState;
    final selection = editorState.selection;
    MentionTrigger? trigger;
    if (selection != null && selection.isCollapsed) {
      final node = editorState.getNodeAtPath(selection.start.path);
      final delta = node?.delta;
      if (delta != null) {
        final text = delta.toPlainText();
        final caret = selection.start.offset.clamp(0, text.length);
        trigger = parseMentionTrigger(text.substring(0, caret));
        // `/` 内置斜杠菜单只在桌面端生效：移动端才用这里的浮层，避免同时弹两个。
        if (trigger?.kind == MentionTriggerKind.slash && !_isMobile) {
          trigger = null;
        }
      }
    }
    if (trigger == null) {
      _diaryCache = null;
      _closeMenu();
      return;
    }
    _trigger = trigger;
    if (trigger.kind == MentionTriggerKind.mention) {
      unawaited(_refreshMentionCandidates(trigger));
    } else {
      _candidates = const [];
      _updateAnchorOffset();
      setState(() {});
      _openMenuSoon();
    }
  }

  Future<void> _refreshMentionCandidates(MentionTrigger trigger) async {
    final seq = ++_searchSeq;
    var cache = _diaryCache;
    cache ??= await ref
        .read(appDatabaseProvider)
        .getActiveDiariesPage(limit: 120, offset: 0);
    if (!mounted || seq != _searchSeq || _trigger == null) return;
    _diaryCache = cache;
    final notebooks =
        ref.read(notebooksProvider).value ?? const <NotebookView>[];
    _candidates = filterMentionCandidates(
      diaries: cache,
      notebooks: notebooks,
      query: trigger.query,
      excludeDiaryId: widget.excludeDiaryId,
    );
    _updateAnchorOffset();
    setState(() {});
    _openMenuSoon();
  }

  void _updateAnchorOffset() {
    _anchorOffset = null;
    final rects = widget.editorState.service.selectionService.selectionRects;
    if (rects.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    // selectionRects 是全局坐标，换算到本浮层坐标。
    _anchorOffset = box.globalToLocal(
      rects.first.bottomLeft + const Offset(0, 6),
    );
  }

  void _openMenuSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _trigger == null) return;
      _updateAnchorOffset();
      if (_anchorOffset == null) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _trigger != null && !_menuController.isOpen) {
          _menuController.open();
        }
      });
    });
  }

  void _closeMenu() {
    final hadTrigger = _trigger != null;
    _trigger = null;
    _candidates = const [];
    _anchorOffset = null;
    if (_menuController.isOpen) _menuController.close();
    if (hadTrigger && mounted) setState(() {});
  }

  Future<void> _pickMention(DiaryMentionCandidate candidate) async {
    final trigger = _trigger;
    final editorState = widget.editorState;
    final selection = editorState.selection;
    _closeMenu();
    if (trigger == null || selection == null || !selection.isCollapsed) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;
    final l10n = context.l10n;
    final (displayText, href) = switch (candidate) {
      MentionDiaryCandidate(:final diaryId, :final title) => (
        title.trim().isEmpty ? l10n.autoT0033 : title,
        diaryLinkHrefForDiary(diaryId),
      ),
      MentionNotebookCandidate(:final notebookId, :final name) => (
        name,
        diaryLinkHrefForNotebook(notebookId),
      ),
    };
    await applyMentionPick(
      editorState: editorState,
      node: node,
      trigger: trigger,
      displayText: displayText,
      href: href,
    );
    widget.editorFocusNode?.requestFocus();
  }

  Future<void> _pickLinkCard() async {
    final trigger = _trigger;
    final editorState = widget.editorState;
    final selection = editorState.selection;
    _closeMenu();
    if (trigger == null || selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node?.delta == null) return;
    // 先删掉 `/query`，再弹日记挑选器。
    final deleteLength = trigger.query.length + 1;
    final length = node!.delta!.length;
    if (trigger.triggerOffset + deleteLength <= length) {
      final transaction = editorState.transaction;
      transaction.deleteText(node, trigger.triggerOffset, deleteLength);
      await editorState.apply(transaction);
    }
    if (!mounted) return;
    final diaryId = await showDiaryLinkCardPicker(
      context,
      excludeDiaryId: widget.excludeDiaryId,
    );
    if (diaryId == null || !mounted) return;
    await insertDiaryLinkCardBlock(editorState, diaryId: diaryId);
    widget.editorFocusNode?.requestFocus();
  }

  /// `/` 菜单里的“拍照 / 录像”：先删掉 `/query`（与 [_pickLinkCard] 同样
  /// 的做法，免得斜杠留在正文里），再走编辑页给的拍摄回调；焦点还给正文，
  /// 拍摄链路在光标处插入。
  Future<void> _pickCamera(DiaryMediaKind kind) async {
    final trigger = _trigger;
    final editorState = widget.editorState;
    final selection = editorState.selection;
    final onCameraPressed = widget.onCameraPressed;
    _closeMenu();
    if (trigger == null ||
        selection == null ||
        !selection.isCollapsed ||
        onCameraPressed == null) {
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node?.delta == null) return;
    final deleteLength = trigger.query.length + 1;
    final length = node!.delta!.length;
    if (trigger.triggerOffset + deleteLength <= length) {
      final transaction = editorState.transaction;
      transaction.deleteText(node, trigger.triggerOffset, deleteLength);
      await editorState.apply(transaction);
    }
    onCameraPressed(kind);
    widget.editorFocusNode?.requestFocus();
  }

  List<Widget> _menuChildren(AppLocalizations l10n) {
    final trigger = _trigger;
    if (trigger == null) return const [];
    if (trigger.kind == MentionTriggerKind.slash) {
      return <Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.addressCard),
          onPressed: () => unawaited(_pickLinkCard()),
          child: Text(l10n.linkCardSlashItem),
        ),
        if (widget.onCameraPressed != null) ...[
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.camera),
            onPressed: () => unawaited(_pickCamera(DiaryMediaKind.image)),
            child: Text(l10n.diaryMediaTakePhoto),
          ),
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.video),
            onPressed: () => unawaited(_pickCamera(DiaryMediaKind.video)),
            child: Text(l10n.diaryMediaRecordVideo),
          ),
        ],
      ];
    }
    if (_candidates.isEmpty) {
      return <Widget>[
        ExpressiveMenuItem(
          onPressed: null,
          child: Text(l10n.diaryMentionNoMatch),
        ),
      ];
    }
    return <Widget>[
      for (final candidate in _candidates)
        switch (candidate) {
          MentionDiaryCandidate(:final title) => ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.book),
            onPressed: () => unawaited(_pickMention(candidate)),
            child: Text(
              title.trim().isEmpty ? l10n.autoT0033 : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MentionNotebookCandidate(:final name) => ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.bookOpen),
            onPressed: () => unawaited(_pickMention(candidate)),
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 菜单浮层在 Overlay 里，这里只放 2x2 的锚点：不吃手势。
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          if (_anchorOffset != null)
            Positioned(
              left: _anchorOffset!.dx,
              top: _anchorOffset!.dy,
              child: ExpressiveMenuAnchor(
                controller: _menuController,
                menuChildren: _menuChildren(context.l10n),
                builder:
                    (
                      BuildContext context,
                      ExpressiveMenuAnchorState menu,
                      Widget? _,
                    ) => const SizedBox(width: 2, height: 2),
              ),
            ),
        ],
      ),
    );
  }
}
