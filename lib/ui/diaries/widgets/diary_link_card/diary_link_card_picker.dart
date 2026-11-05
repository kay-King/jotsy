import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/ui/widgets/text_selection_menu/app_text_context_menu.dart';

import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../diary_mention/diary_mention_candidates.dart';

/// `/` 菜单选“日记卡片”后弹出的日记挑选器：搜索框 + 日记列表。
///
/// 返回被选日记的业务 id；取消时返回 null。
Future<String?> showDiaryLinkCardPicker(
  BuildContext context, {
  String? excludeDiaryId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) =>
        _DiaryLinkCardPicker(excludeDiaryId: excludeDiaryId),
  );
}

class _DiaryLinkCardPicker extends ConsumerStatefulWidget {
  const _DiaryLinkCardPicker({this.excludeDiaryId});

  final String? excludeDiaryId;

  @override
  ConsumerState<_DiaryLinkCardPicker> createState() =>
      _DiaryLinkCardPickerState();
}

class _DiaryLinkCardPickerState extends ConsumerState<_DiaryLinkCardPicker> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  List<MentionDiaryCandidate> _candidates = const [];
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _searchCandidates('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    // 输入停手 300ms 再查库，避免每敲一个字都读一次。
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _searchCandidates(_search.text);
    });
  }

  Future<void> _searchCandidates(String query) async {
    final seq = ++_seq;
    final db = ref.read(appDatabaseProvider);
    final candidates = await searchDiaryCandidates(
      db: db,
      query: query,
      excludeDiaryId: widget.excludeDiaryId,
    );
    if (!mounted || seq != _seq) return;
    setState(() {
      _candidates = candidates;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.linkCardPickTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                    tooltip: l10n.commonClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                contextMenuBuilder: appTextContextMenuBuilder,
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.linkCardPickSearchHint,
                  prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              // 首屏查询是本地库，一帧即回：加载中不转菊花，只留空避免闪烁。
              child: _loading
                  ? const SizedBox.shrink()
                  : _candidates.isEmpty
                  ? Center(
                      child: Text(
                        l10n.diaryMentionNoMatch,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _candidates.length,
                      itemBuilder: (BuildContext context, int index) {
                        final candidate = _candidates[index];
                        final title = candidate.title.trim();
                        return ListTile(
                          leading: FaIcon(
                            FontAwesomeIcons.book,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            title.isEmpty ? l10n.autoT0033 : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            l10n.formatFullDate(candidate.createdAt.toLocal()),
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(candidate.diaryId),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
