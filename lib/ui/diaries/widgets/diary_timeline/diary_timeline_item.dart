import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/relative_time_formatter.dart';
import '../../models/time_capsule.dart';
import '../../pages/locked_diary_page.dart';
import '../../providers/diary_profile_provider.dart';
import '../../viewmodels/diary_card_view_data.dart';
import '../diary_card/diary_card.dart';
import 'diary_timeline_avatar.dart';
import 'diary_timeline_grid.dart';
import 'diary_timeline_text.dart';

/// 时间线的一条日记（朋友圈式）：头像 + 昵称 + 正文折叠 + 九宫格。
///
/// 点按/长按/多选/未解封胶囊的行为与 [DiaryCard] 完全一致，只换了排布：
/// - 点按：多选态切换选中；未解封胶囊进封存页；否则进现有预览页（不带封面
///   共享元素，时间线没有封面图）；
/// - 长按：iOS 补一次震动后进入多选；
/// - 未解封胶囊只显示标题与“未解封的时间胶囊”，正文与图片一律不外露。
class DiaryTimelineItem extends ConsumerWidget {
  const DiaryTimelineItem({
    super.key,
    required this.diary,
    required this.selected,
    required this.isSelectionMode,
    required this.maxVisibleTags,
    required this.onOpenEditor,
    required this.onToggleSelection,
    required this.opensLockedCapsulePage,
  });

  final DiaryWithTags diary;
  final bool selected;
  final bool isSelectionMode;
  final int maxVisibleTags;
  final DiaryOpenCallback onOpenEditor;
  final void Function(String noteId, bool forceSelect) onToggleSelection;

  /// 点按未解封胶囊是否进入封存页；设置页预览的示例胶囊不是真实日记，
  /// 关闭后改为走 [onOpenEditor]（与 DiaryCard 同口径）。
  final bool opensLockedCapsulePage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entry = diary.diary;
    final diaryId = entry.diaryId;
    // metadata、摘要与封面按 (diaryId, updatedAt) 缓存，滚动重建不再重复解析。
    final viewData = DiaryCardViewData.of(entry);
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: entry.capsuleLockedAt,
      unlockAt: entry.capsuleUnlockAt,
      now: DateTime.now(),
    );
    final isLockedCapsule = capsuleState.isLocked;
    final profile = ref.watch(diaryProfileProvider);
    // 时间以日记的发表日为准（与卡片默认的 dateSource: created 一致）。
    final timeLabel = RelativeTimeFormatter.formatUpdatedAt(
      updatedAt: entry.createdAt,
      now: DateTime.now(),
      l10n: l10n,
    );
    final title = entry.title.trim();
    final body = entry.contentText.trim();

    return Column(
      children: <Widget>[
        Material(
          color: selected ? colors.surfaceContainerLow : colors.surface,
          child: InkWell(
            onTap: () {
              if (isSelectionMode) {
                onToggleSelection(diaryId, false);
                return;
              }
              if (isLockedCapsule && opensLockedCapsulePage) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        LockedDiaryPage(diaryId: diaryId, initialDetail: diary),
                  ),
                );
                return;
              }
              onOpenEditor(diary, null);
            },
            onLongPress: () {
              // Android 上 InkWell 已经通过 Feedback.forLongPress 震动；
              // iOS 不会，补一次以确认进入多选（与 DiaryCard 同口径）。
              if (Theme.of(context).platform == TargetPlatform.iOS) {
                unawaited(HapticFeedback.mediumImpact());
              }
              onToggleSelection(diaryId, true);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _avatarWithSelectionBadge(colors, profile),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          profile.displayNickname,
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (isLockedCapsule)
                          _lockedBody(context, title)
                        else ...<Widget>[
                          if (title.isNotEmpty)
                            Text(
                              title,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 15,
                                color: colors.onSurface,
                              ),
                            ),
                          if (body.isNotEmpty) ...<Widget>[
                            if (title.isNotEmpty) const SizedBox(height: 2),
                            DiaryTimelineFoldableText(
                              text: body,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 15,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                          if (_timelineImages(viewData).isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            DiaryTimelineGrid(
                              sources: _timelineImages(viewData),
                              diaryId: diaryId,
                            ),
                          ],
                        ],
                        const SizedBox(height: 6),
                        _metaLine(context, viewData, timeLabel),
                        if (!isLockedCapsule &&
                            diary.tags.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            diary.tags
                                .take(maxVisibleTags)
                                .map((tag) => '#${tag.name}')
                                .join(' '),
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: 68,
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ],
    );
  }

  /// 头像 + 多选标记：选中为绿底白勾，未选中（多选态）为空心圈，
  /// 非多选态不画标记。
  Widget _avatarWithSelectionBadge(ColorScheme colors, DiaryProfile profile) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        DiaryTimelineAvatar(profile: profile),
        if (selected || isSelectionMode)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: selected
                    ? DiaryTimelineAvatar.accentGreen
                    : colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.surface : colors.onSurfaceVariant,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const FaIcon(
                      FontAwesomeIcons.check,
                      size: 8,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  /// 未解封胶囊：锁图标 + 标题 + “未解封的时间胶囊”，正文与图片不外露。
  Widget _lockedBody(BuildContext context, String title) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final displayTitle = title.isEmpty ? l10n.autoT0033 : title;
    return Row(
      children: <Widget>[
        FaIcon(FontAwesomeIcons.lock, size: 12, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$displayTitle · ${l10n.calendarBadgeCapsule}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// 时间 + 心情 + 地点（未解封胶囊只显示时间）。
  Widget _metaLine(
    BuildContext context,
    DiaryCardViewData viewData,
    String timeLabel,
  ) {
    final colors = Theme.of(context).colorScheme;
    final buffer = StringBuffer(timeLabel);
    final mood = viewData.moodEmoji;
    if (mood != null && mood.isNotEmpty) {
      buffer.write('  $mood');
    }
    final location = viewData.location;
    if (location != null && location.isNotEmpty) {
      buffer.write(' · $location');
    }
    return Text(
      buffer.toString(),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
    );
  }

  /// 九宫格图片：封面优先，其余按正文出现顺序，去重，最多 9 张。
  static List<String> _timelineImages(DiaryCardViewData viewData) {
    final seen = <String>{};
    final result = <String>[];
    void add(String? source) {
      final trimmed = source?.trim();
      if (trimmed != null && trimmed.isNotEmpty && seen.add(trimmed)) {
        result.add(trimmed);
      }
    }

    add(viewData.previewCover);
    for (final image in viewData.media.images) {
      add(image);
    }
    return result.take(DiaryTimelineGrid.maxImages).toList(growable: false);
  }
}
