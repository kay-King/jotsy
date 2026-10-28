import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';

/// 时间线条目右下角“...”菜单里可做的事。
enum DiaryTimelineEntryMenuAction {
  /// 编辑这篇日记（简洁 / 完整选择走共用流程）。
  edit,

  /// 查看详情（打开预览页，与点条目本身一致）。
  viewDetail,

  /// 删除这篇日记（调用方先弹确认框再软删）。
  delete,
}

/// 打开时间线条目的“...”菜单（底部面板），返回用户选的动作；
/// 点遮罩或下滑关闭返回 null。
///
/// 仿朋友圈（my-diary-fakeWechat 的 openPostMenu）：编辑 / 查看详情 /
/// 删除三项，删除为危险动作（红色）。面板只负责挑选，真正的编辑、
/// 打开预览与删除由调用方（时间线页）执行。
Future<DiaryTimelineEntryMenuAction?> showDiaryTimelineEntryMenuSheet(
  BuildContext context,
) {
  return showModalBottomSheet<DiaryTimelineEntryMenuAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final colors = Theme.of(sheetContext).colorScheme;
      Widget item({
        required DiaryTimelineEntryMenuAction action,
        required FaIconData icon,
        required String label,
        Color? color,
      }) {
        return ListTile(
          leading: FaIcon(icon, size: 18, color: color ?? colors.onSurface),
          title: Text(label, style: TextStyle(color: color)),
          onTap: () => Navigator.of(sheetContext).pop(action),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            item(
              action: DiaryTimelineEntryMenuAction.edit,
              icon: FontAwesomeIcons.pen,
              label: l10n.timelineEntryEdit,
            ),
            item(
              action: DiaryTimelineEntryMenuAction.viewDetail,
              icon: FontAwesomeIcons.eye,
              label: l10n.timelineEntryViewDetail,
            ),
            item(
              action: DiaryTimelineEntryMenuAction.delete,
              icon: FontAwesomeIcons.trash,
              label: l10n.commonDelete,
              color: colors.error,
            ),
          ],
        ),
      );
    },
  );
}
