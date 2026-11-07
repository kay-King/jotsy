import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_preview_style/diary_preview_style.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../diary_card_style/diary_card_style_labels.dart';
import 'diary_preview_style_labels.dart';

/// “头图”标签页：显示方式、适配、高度、圆角（内嵌时）、滚动淡出与“没有
/// 封面时用正文第一张图”。头图隐藏时只保留显示方式。
class DiaryPreviewStyleCoverTab extends StatelessWidget {
  const DiaryPreviewStyleCoverTab({super.key, required this.controller});

  final DiaryPreviewStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cover = controller.style.cover;
    final hidden = cover.mode == DiaryPreviewCoverMode.hidden;

    void commit(DiaryPreviewCoverStyle next) =>
        controller.commitWith((style) => style.copyWith(cover: next));
    void preview(DiaryPreviewCoverStyle next) =>
        controller.previewWith((style) => style.copyWith(cover: next));

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          footer: hidden ? null : l10n.diaryPreviewStyleCoverHeightHint,
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.diaryPreviewStyleCoverMode,
              child: StylePillGroup<DiaryPreviewCoverMode>(
                segments: <ButtonSegment<DiaryPreviewCoverMode>>[
                  for (final choice in diaryPreviewCoverModeChoices(l10n))
                    ButtonSegment<DiaryPreviewCoverMode>(
                      value: choice.value,
                      icon: FaIcon(choice.icon),
                      label: Text(choice.label),
                    ),
                ],
                selected: <DiaryPreviewCoverMode>{cover.mode},
                onSelectionChanged: (Set<DiaryPreviewCoverMode> v) =>
                    commit(cover.copyWith(mode: v.single)),
              ),
            ),
            if (!hidden) ...<Widget>[
              SettingsChoiceTile(
                title: l10n.diaryPreviewStyleCoverFit,
                child: StylePillGroup<DiaryPreviewCoverFit>(
                  segments: <ButtonSegment<DiaryPreviewCoverFit>>[
                    ButtonSegment<DiaryPreviewCoverFit>(
                      value: DiaryPreviewCoverFit.contain,
                      label: Text(l10n.diaryPreviewStyleCoverContain),
                    ),
                    ButtonSegment<DiaryPreviewCoverFit>(
                      value: DiaryPreviewCoverFit.cover,
                      label: Text(l10n.diaryPreviewStyleCoverFill),
                    ),
                  ],
                  selected: <DiaryPreviewCoverFit>{cover.fit},
                  onSelectionChanged: (Set<DiaryPreviewCoverFit> v) =>
                      commit(cover.copyWith(fit: v.single)),
                ),
              ),
              StyleSliderRow(
                title: l10n.diaryPreviewStyleCoverHeight,
                value: cover.height,
                min: DiaryPreviewStyleLimits.coverHeight.min,
                max: DiaryPreviewStyleLimits.coverHeight.max,
                divisions: DiaryPreviewStyleLimits.coverHeight.divisions,
                valueLabel: (double v) => diaryCardDpLabel(l10n, v),
                onChanged: (double v) => preview(cover.copyWith(height: v)),
                onChangeEnd: (double v) => commit(cover.copyWith(height: v)),
              ),
              if (cover.mode == DiaryPreviewCoverMode.inset)
                StyleSliderRow(
                  title: l10n.diaryPreviewStyleCoverRadius,
                  value: cover.radius,
                  min: DiaryPreviewStyleLimits.coverRadius.min,
                  max: DiaryPreviewStyleLimits.coverRadius.max,
                  divisions: DiaryPreviewStyleLimits.coverRadius.divisions,
                  valueLabel: (double v) => diaryCardDpLabel(l10n, v),
                  onChanged: (double v) => preview(cover.copyWith(radius: v)),
                  onChangeEnd: (double v) => commit(cover.copyWith(radius: v)),
                ),
              SettingsSwitchTile(
                title: l10n.diaryPreviewStyleCoverFade,
                subtitle: l10n.diaryPreviewStyleCoverFadeSubtitle,
                value: cover.fadeOnScroll,
                onChanged: (bool v) => commit(cover.copyWith(fadeOnScroll: v)),
              ),
              SettingsSwitchTile(
                title: l10n.diaryPreviewStyleCoverFirstImage,
                value: cover.useFirstImage,
                onChanged: (bool v) => commit(cover.copyWith(useFirstImage: v)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
