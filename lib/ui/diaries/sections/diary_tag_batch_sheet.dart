import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../utils/tri_state_pick.dart';
import '../providers/tag_picker_sort_provider.dart';
import '../viewmodels/tag_picker_view.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../controllers/tag_create_flow.dart';
import '../widgets/publish_panel/publish_panel_tile.dart';
import '../widgets/publish_panel/publish_tag_row.dart';
import '../widgets/publish_panel/publish_tag_search_bar.dart';

export '../../../utils/tri_state_pick.dart';

/// 打开多选日记的标签面板（底部面板）。
///
/// [initial] 为各标签对所选这批日记的三态（经 [triStatePicksFor] 由每篇现有
/// 的标签算出：都有 → 勾选，部分有 → 半选，都没有不列出 → 未选）；
/// [diaryCount] 只用于标题。返回只含变化的结果（`add` 要给每篇都加上，
/// `remove` 要从每篇都去掉）；关掉面板或没有任何改动时为 null。
///
/// 面板只负责挑选，写库、撤销与提示由调用方完成（见
/// `DiariesTagBatchController`）。
Future<TriStatePickResult<int>?> showDiaryTagBatchSheet(
  BuildContext context, {
  required int diaryCount,
  Map<int, TriStatePick> initial = const <int, TriStatePick>{},
}) {
  return showModalBottomSheet<TriStatePickResult<int>>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        DiaryTagBatchSheet(diaryCount: diaryCount, initial: initial),
  );
}

/// 多选日记的标签面板：标题、检索框与排序、“新建”行、标签列表与底部
/// “完成”。
///
/// - 挑选区复用发布面板标签子页的检索、排序与分组口径（[TagPickerView]、
///   [PublishTagSearchBar]、[PublishTagRow] 的三态）；点按循环与日记本选本
///   面板相同（[TriStatePickSelection]）：部分有 → 全部加上 → 全部去掉 →
///   全部加上 → …，没点过的标签不出现在结果里；
/// - 从检索词新建标签走与发布面板相同的路径（[runCreateTagFlow]），新建
///   出来的标签直接勾选；
/// - 固定为屏高约 75% 的高度（检索使结果变少时面板不跳动），键盘弹出时
///   整块让到键盘上方、高度随之收缩。
class DiaryTagBatchSheet extends ConsumerStatefulWidget {
  const DiaryTagBatchSheet({
    super.key,
    required this.diaryCount,
    this.initial = const <int, TriStatePick>{},
  });

  final int diaryCount;
  final Map<int, TriStatePick> initial;

  @override
  ConsumerState<DiaryTagBatchSheet> createState() => _DiaryTagBatchSheetState();
}

class _DiaryTagBatchSheetState extends ConsumerState<DiaryTagBatchSheet> {
  late final TriStatePickSelection<int> _selection = TriStatePickSelection<int>(
    widget.initial,
  );
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'TagBatchSearch');
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggle(int tagId) => setState(() => _selection.toggle(tagId));

  Future<void> _create(String? name) async {
    _searchFocus.unfocus();
    final tagId = await runCreateTagFlow(
      context,
      ref.read(appDatabaseProvider),
      initialName: name,
    );
    if (tagId == null || !mounted) return;
    setState(() => _selection.select(tagId));
  }

  void _done() {
    final result = _selection.result;
    Navigator.of(context).pop(result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final tags = ref.watch(tagListProvider);
    final sort = ref.watch(tagPickerSortProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => SizedBox(
          height: math.min(media.size.height * 0.75, constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                child: Text(
                  l10n.diaryTagBatchTitle(widget.diaryCount),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: PublishTagSearchBar(
                  controller: _search,
                  focusNode: _searchFocus,
                  onChanged: (value) => setState(() => _query = value),
                  sort: sort,
                  onSortChanged: ref
                      .read(tagPickerSortProvider.notifier)
                      .select,
                ),
              ),
              Expanded(
                child: tags.when(
                  loading: () => const Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: ExpressiveLoadingIndicator(),
                      ),
                    ),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      l10n.autoT0165('$error'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  data: (list) {
                    final view = TagPickerView.of(
                      list,
                      sort: sort,
                      query: _query,
                    );
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _TagBatchListHeader(
                            view: view,
                            hasTags: list.isNotEmpty,
                            onCreate: () => unawaited(_create(view.createName)),
                          ),
                          for (final section in view.sections) ...<Widget>[
                            if (section.letter case final letter?)
                              PublishTagSectionHeader(letter: letter),
                            for (final tag in section.tags)
                              PublishTagRow(
                                key: ValueKey<String>('tag_batch_${tag.id}'),
                                tag: tag,
                                selected:
                                    _selection.stateOf(tag.id) ==
                                    TriStatePick.all,
                                partial:
                                    _selection.stateOf(tag.id) ==
                                    TriStatePick.some,
                                onToggle: (_) => _toggle(tag.id),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  media.padding.bottom + AppSpacing.l,
                ),
                child: FilledButton(
                  onPressed: _done,
                  child: Text(l10n.diaryTagBatchDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 列表最前的“新建”行与空态提示（与发布面板标签子页同一画法）。
class _TagBatchListHeader extends StatelessWidget {
  const _TagBatchListHeader({
    required this.view,
    required this.hasTags,
    required this.onCreate,
  });

  final TagPickerView view;
  final bool hasTags;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final createName = view.createName;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final String? hint;
    if (view.isSearching && view.isEmpty) {
      hint = l10n.tagPickerSearchEmpty(view.query);
    } else if (!hasTags) {
      hint = l10n.autoT0166;
    } else {
      hint = null;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PublishPanelTile(
            onTap: onCreate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const FaIcon(FontAwesomeIcons.plus, size: 12),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    createName == null
                        ? l10n.autoT0157
                        : l10n.tagPickerCreateNamed(createName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(hint, textAlign: TextAlign.center, style: hintStyle),
            ),
        ],
      ),
    );
  }
}
