import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_button_group.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../models/explore_view_data.dart';

/// 打开媒体画廊的布局面板：视图（年/月/日）、每行数量与正/倒序。
///
/// 和日记视图选项面板同一路数：选项即点即生效且面板保持打开，常常要连着
/// 调，点一项就关闭会让用户反复打开面板。生效由页面经回调完成，网格在
/// 面板后方跟着换；下拉或点遮罩关闭面板。
///
/// 视图只决定分段粒度（ente 的 GroupType 做法），不筛掉任何照片；每行数
/// 量 2–6，改完由页面持久化。
Future<void> showGalleryLayoutSheet(
  BuildContext context, {
  required GalleryGroupType groupType,
  required int columns,
  required bool sortAsc,
  required ValueChanged<GalleryGroupType> onSelectGroupType,
  required ValueChanged<int> onSelectColumns,
  required ValueChanged<bool> onSelectSort,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 内容接近默认的 9/16 屏高上限，大字号或矮屏会超出：放开上限按内容
    // 撑高，仍超出屏幕时由内部滚动兜底（与日记视图选项面板一致）。
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => GalleryLayoutSheet(
      initialGroupType: groupType,
      initialColumns: columns,
      initialSortAsc: sortAsc,
      onSelectGroupType: onSelectGroupType,
      onSelectColumns: onSelectColumns,
      onSelectSort: onSelectSort,
    ),
  );
}

/// 布局面板内容。
///
/// 选中态由面板自己维护（初值取打开时的页面状态）：面板是独立路由，不随
/// 页面重建；打开期间布局只能经由面板修改，本地状态不会与页面分叉。
class GalleryLayoutSheet extends StatefulWidget {
  const GalleryLayoutSheet({
    super.key,
    required this.initialGroupType,
    required this.initialColumns,
    required this.initialSortAsc,
    required this.onSelectGroupType,
    required this.onSelectColumns,
    required this.onSelectSort,
  });

  final GalleryGroupType initialGroupType;
  final int initialColumns;
  final bool initialSortAsc;
  final ValueChanged<GalleryGroupType> onSelectGroupType;
  final ValueChanged<int> onSelectColumns;
  final ValueChanged<bool> onSelectSort;

  @override
  State<GalleryLayoutSheet> createState() => _GalleryLayoutSheetState();
}

class _GalleryLayoutSheetState extends State<GalleryLayoutSheet> {
  late GalleryGroupType _groupType = widget.initialGroupType;
  late int _columns = widget.initialColumns;
  late bool _sortAsc = widget.initialSortAsc;

  void _selectGroupType(GalleryGroupType type) {
    if (type == _groupType) {
      return;
    }
    setState(() => _groupType = type);
    widget.onSelectGroupType(type);
  }

  void _selectColumns(int columns) {
    if (columns == _columns) {
      return;
    }
    setState(() => _columns = columns);
    widget.onSelectColumns(columns);
  }

  void _selectSort(bool ascending) {
    if (ascending == _sortAsc) {
      return;
    }
    setState(() => _sortAsc = ascending);
    widget.onSelectSort(ascending);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SectionHeader(
              icon: FontAwesomeIcons.tableCellsLarge,
              label: l10n.galleryViewTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            ExpressiveChoiceTile(
              label: l10n.galleryViewYear,
              selected: _groupType == GalleryGroupType.year,
              onTap: () => _selectGroupType(GalleryGroupType.year),
            ),
            ExpressiveChoiceTile(
              label: l10n.galleryViewMonth,
              selected: _groupType == GalleryGroupType.month,
              onTap: () => _selectGroupType(GalleryGroupType.month),
            ),
            ExpressiveChoiceTile(
              label: l10n.galleryViewDay,
              selected: _groupType == GalleryGroupType.day,
              onTap: () => _selectGroupType(GalleryGroupType.day),
            ),
            const SizedBox(height: AppSpacing.l),
            _SectionHeader(
              icon: FontAwesomeIcons.tableColumns,
              label: l10n.galleryFilterColumns,
            ),
            const SizedBox(height: AppSpacing.xs),
            ExpressiveButtonGroup<int>(
              // 单个数字标签很窄：最小段宽按 48 算，5 段横排约 240px，
              // 在子菜单里放得下；用默认 104 会误判放不下而堆成 5 行。
              minSegmentWidth: 48,
              segments: <ButtonSegment<int>>[
                for (final columns in <int>[2, 3, 4, 5])
                  ButtonSegment<int>(value: columns, label: Text('$columns')),
              ],
              selected: <int>{_columns},
              onSelectionChanged: (selection) =>
                  _selectColumns(selection.single),
            ),
            const SizedBox(height: AppSpacing.l),
            _SectionHeader(icon: FontAwesomeIcons.sort, label: l10n.autoT0141),
            const SizedBox(height: AppSpacing.xs),
            ExpressiveButtonGroup<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  icon: const FaIcon(
                    FontAwesomeIcons.arrowDownWideShort,
                    size: 16,
                  ),
                  label: Text(l10n.gallerySortDesc),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: const FaIcon(
                    FontAwesomeIcons.arrowUpWideShort,
                    size: 16,
                  ),
                  label: Text(l10n.gallerySortAsc),
                ),
              ],
              selected: <bool>{_sortAsc},
              onSelectionChanged: (selection) => _selectSort(selection.single),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final FaIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Row(
        children: <Widget>[
          FaIcon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
