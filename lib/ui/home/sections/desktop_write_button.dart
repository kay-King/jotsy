import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/simple_composer_controller.dart';
import 'package:node_diary/ui/diaries/pages/simple_composer_page.dart';

import '../widgets/desktop_card.dart';

/// 桌面页“写点什么”主按钮（从 fakeWechat 桌面页的 deskWrite 搬过来，
/// 只搬样子：白底卡 + 蓝色铅笔圆钮 + 标题/副标题 + 右箭头）。
///
/// 点一下默认进简洁编辑器（fakeWechat 式，纯文本 + 图片）。
/// 完整编辑（原来的富文本编辑器）仍可从日记页右下角新建按钮、
/// 日历页等原来的入口进，不走这里。
///
/// 续写：上次没写完就退出了，草稿还在——点进来直接回到没写完的那篇，
/// 不用从头写；发表后草稿删除，下次点进来就是空白一篇。
class DesktopWriteButton extends ConsumerWidget {
  const DesktopWriteButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DesktopCard(
      onTap: () async {
        final database = ref.read(appDatabaseProvider);
        final latest = await SimpleComposerController(
          database,
        ).findLatestSimpleDraft();
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => SimpleComposerPage(
              draftId: latest?.draftId,
              initialDraft: latest?.draft,
            ),
          ),
        );
      },
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 20,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.desktopWriteTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.desktopWriteSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
