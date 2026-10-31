import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/long_image/long_image_policy.dart';
import '../diary_image_source.dart';

/// 日记卡片的外观（编辑器内与预览页共用）：圆角描边容器，左封面缩略图 +
/// 右侧标题 / 日期 / 摘要；点按打开被链的日记。
///
/// 数据由调用方从 [diaryDetailProvider] 取好后传入，这里只负责展示；
/// [title] 为 null 时显示 [missingLabel] 占位（被链日记被删除或不在
/// 可见范围）。
class DiaryLinkCardView extends StatelessWidget {
  const DiaryLinkCardView({
    super.key,
    this.title,
    this.dateLabel,
    this.summary,
    this.coverPath,
    this.missingLabel,
    this.onTap,
  });

  /// null 表示被链的日记读不到（已删除等），此时只显示占位。
  final String? title;
  final String? dateLabel;
  final String? summary;
  final String? coverPath;

  /// 缺失占位文案（调用方经 l10n 传入）；title 非空时忽略。
  final String? missingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: onTap != null,
      label: title,
      excludeSemantics: title == null,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: title == null
                ? _missingRow(context)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (coverPath != null && coverPath!.isNotEmpty)
                        _cover(context, coverPath!),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (dateLabel != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                dateLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (summary != null &&
                                summary!.trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                _shortSummary(summary!),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: FaIcon(
                          FontAwesomeIcons.angleRight,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _cover(BuildContext context, String source) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image(
          image: boundedImageProvider(
            diaryImageProvider(source),
            width: 112,
            height: 112,
          ),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          frameBuilder: expressiveImageFrameBuilder,
          errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56),
        ),
      ),
    );
  }

  Widget _missingRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        FaIcon(
          FontAwesomeIcons.triangleExclamation,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            missingLabel ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 摘要只取前 120 字：卡片里只显示两行，整篇 contentText 不必进来。
String _shortSummary(String summary) {
  final trimmed = summary.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 120) return trimmed;
  return '${trimmed.substring(0, 120)}…';
}
