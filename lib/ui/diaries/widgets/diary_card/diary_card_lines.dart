import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/diary_card_style/diary_card_style.dart';
import '../../viewmodels/diary_card_appearance.dart';
import '../../viewmodels/diary_card_date_formatter.dart';
import '../../viewmodels/diary_card_resolved_style.dart';
import '../../viewmodels/diary_card_view_data.dart';
import 'diary_card_badges.dart';

/// 卡片正文里两种有内部排版的行：眉线与底栏（`DiaryCardBlocks` 的一部分）。
///
/// 列表与瀑布流保留改版前各自的结构：列表眉线是“日期 + 徽章”整体占满、
/// 印章贴右；瀑布流眉线是日期占满、图钉贴右。默认样式下产出的部件树与
/// 改版前相同。
///
/// 元信息收敛到底栏：日期与标签不再单独成行，统一收进底栏与时间同行
/// （日期 + 标签 + 时间一行，字号用底栏小字号、超长省略防溢出），
/// 眉线只留置顶徽章与心情天气。
class DiaryCardLines {
  const DiaryCardLines({
    required this.diary,
    required this.viewData,
    required this.resolved,
    required this.appearance,
    this.maxVisibleTags = 2,
  });

  final DiaryWithTags diary;
  final DiaryCardViewData viewData;
  final DiaryCardResolvedStyle resolved;
  final DiaryCardAppearance appearance;

  /// 底栏里标签的展示上限；与正文标签块同口径（默认 2，0 隐藏）。
  final int maxVisibleTags;

  /// 置顶徽章；未置顶或样式隐藏时为 null。
  Widget? pinBadge() {
    if (!diary.diary.isPinned) {
      return null;
    }
    final badge = resolved.style.content.pinnedBadge;
    if (badge == DiaryCardPinnedBadge.hidden) {
      return null;
    }
    return DiaryCardPinBadge(
      color: appearance.accentColor,
      compact: resolved.compact,
      showLabel: badge == DiaryCardPinnedBadge.standard && !resolved.compact,
      scale: resolved.metaScale,
    );
  }

  /// 眉线行（置顶徽章、位于眉线的心情天气与选择标记）。
  ///
  /// 日期已收进底栏，不再放眉线（与标签、时间同行），所以眉线只剩徽章
  /// 与印章；三者都没有时不渲染（见 [DiaryCardBlocks.hasEyebrowContent]）。
  Widget eyebrow(
    BuildContext context, {
    required DiaryCardMetaIndicators? indicators,
    required Widget? mark,
  }) {
    final badge = pinBadge();
    final showIndicators = indicators != null && !indicators.isEmpty;
    // 徽章与印章都贴右，选择标记跟在最后；窄列放不下时整组等比缩小
    // （FittedBox 只缩不放），不会溢出。两者都没有时调用方已保证
    // 不进这里（hasEyebrowContent 为 false），这里不再兜底空行。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: resolved.centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        if (!resolved.centered) const Spacer(),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null) badge,
                if (showIndicators) ...[
                  if (badge != null) const SizedBox(width: 6),
                  indicators,
                ],
                ?mark,
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 底栏（日期、标签、时间、附加信息、位于底栏的心情天气）；没有
  /// 任何内容时为 null。
  ///
  /// 元信息收敛到底栏一行：日期 + 标签 + 时间同行，都用底栏小字号，
  /// 日期与时间单行省略、标签只取前 `maxVisibleTags` 个（多余 `+N`），
  /// 窄屏放不下时整组换行、不会溢出。
  Widget? footer(
    BuildContext context, {
    required DiaryCardMetaIndicators? indicators,
  }) {
    final meta = resolved.style.meta;
    final timeLabel = DiaryCardDateFormatter.footer(
      l10n: context.l10n,
      mode: meta.footerTime,
      createdAt: diary.diary.createdAt,
      updatedAt: diary.diary.updatedAt,
      now: DateTime.now(),
    );
    final timeStyle = resolved.footerStyle?.copyWith(
      color: appearance.footerColor,
    );
    final extras = meta.hasFooterExtras
        ? buildDiaryCardFooterExtras(
            context,
            meta: meta,
            textStyle: resolved.footerStyle,
            color: appearance.footerColor,
            location: viewData.location,
            energyLevel: viewData.energyLevel,
            wordCount: viewData.wordCount,
            media: meta.showMedia ? viewData.media : null,
            scale: resolved.metaScale,
          )
        : const <Widget>[];
    final showIndicators = indicators != null && !indicators.isEmpty;
    // 日期（眉线格式，底栏小字号）与标签都收进底栏，与时间同行。
    final dateText = meta.showDate
        ? Text(
            DiaryCardDateFormatter.eyebrow(
              l10n: context.l10n,
              meta: meta,
              createdAt: diary.diary.createdAt,
              updatedAt: diary.diary.updatedAt,
              now: DateTime.now(),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: resolved.centered ? TextAlign.center : null,
            style: timeStyle,
          )
        : null;
    // 标签收进底栏：与日期、时间同行，都用底栏小字号、可收缩省略。
    // 形态跟随样式的 tagStyle（彩色 `#` 微胶囊 / 纯文字 / 圆点）；
    // 不能用 DiaryItemTagRow（它是 Wrap，子项拿不到宽度约束、长标签
    // 名会直接撑出右边界），这里按样式逐个拼成单行可收缩的形态。
    final tagsWidget = _footerTags(
      context,
      tagStyle: resolved.style.content.tagStyle,
      textStyle: timeStyle,
    );
    if (timeLabel == null &&
        extras.isEmpty &&
        !showIndicators &&
        dateText == null &&
        tagsWidget == null) {
      return null;
    }
    final timeText = timeLabel == null
        ? null
        : Text(
            timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: resolved.centered ? TextAlign.center : null,
            style: timeStyle,
          );
    // 日期 + 标签 + 时间同行：各段都可收缩（日期与时间单行省略、标签
    // 单行富文本省略），窄屏 / 大字号 / 长标签名也不会横向溢出。
    // 附加信息（地点、电量、字数等）不进同一行——它们是复杂小部件
    // （如电量指示器是内部 Row），在 Row 里分不到足够宽度会溢出；
    // 它们另起一个 Wrap，可换行。
    final gap = SizedBox(width: 8 * resolved.metaScale);
    final Widget metaRow = Row(
      children: <Widget>[
        if (dateText != null) Flexible(child: dateText),
        if (tagsWidget != null) ...[
          if (dateText != null) gap,
          Flexible(flex: 2, child: tagsWidget),
        ],
        if (timeText != null) ...[
          if (dateText != null || tagsWidget != null) gap,
          Flexible(child: timeText),
        ],
      ],
    );
    final Widget leading = extras.isEmpty
        ? metaRow
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              metaRow,
              SizedBox(height: 2 * resolved.metaScale),
              Wrap(
                spacing: 8 * resolved.metaScale,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: extras,
              ),
            ],
          );

    if (resolved.compact) {
      // 瀑布流：时间占满一行，心情天气印章贴右（改版前的结构）。
      return Row(
        children: [
          Expanded(child: leading),
          if (indicators != null) indicators,
        ],
      );
    }
    if (!showIndicators && !resolved.centered) {
      return Row(children: [Flexible(child: leading)]);
    }
    return Row(
      mainAxisAlignment: resolved.centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        resolved.centered ? Flexible(child: leading) : Expanded(child: leading),
        if (showIndicators) ...[const SizedBox(width: 6), indicators],
      ],
    );
  }

  /// 底栏里的标签：按样式的 tagStyle 拼成单行可收缩的形态。
  ///
  /// 微胶囊是一行小胶囊（各占一份宽度、名字省略）；纯文字 / 圆点拼成
  /// 一段富文本（`# 名字` / `• 名字`，`#` 与圆点取标签色），整段省略。
  /// 多余的标签用 `+N` 汇总。没有标签或上限为 0 时返回 null。
  Widget? _footerTags(
    BuildContext context, {
    required DiaryCardTagStyle tagStyle,
    required TextStyle? textStyle,
  }) {
    if (diary.tags.isEmpty || maxVisibleTags <= 0) {
      return null;
    }
    final scale = resolved.metaScale;
    final visible = diary.tags.take(maxVisibleTags).toList(growable: false);
    final hidden = diary.tags.length - visible.length;
    if (tagStyle == DiaryCardTagStyle.chip) {
      final isLight = Theme.of(context).brightness == Brightness.light;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) SizedBox(width: 6 * scale),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: Color(
                    visible[i].color,
                  ).withValues(alpha: isLight ? 0.08 : 0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Color(
                      visible[i].color,
                    ).withValues(alpha: isLight ? 0.22 : 0.32),
                    width: 0.65,
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '# ',
                        style: TextStyle(
                          color: Color(visible[i].color),
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5 * scale,
                        ),
                      ),
                      TextSpan(text: visible[i].name, style: textStyle),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          if (hidden > 0) ...[
            SizedBox(width: 6 * scale),
            Text('+$hidden', style: textStyle),
          ],
        ],
      );
    }
    return Text.rich(
      TextSpan(
        style: textStyle,
        children: <InlineSpan>[
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const TextSpan(text: '  '),
            if (tagStyle == DiaryCardTagStyle.dot)
              TextSpan(
                text: '• ',
                style: TextStyle(
                  color: Color(visible[i].color),
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              TextSpan(
                text: '# ',
                style: TextStyle(
                  color: Color(visible[i].color),
                  fontWeight: FontWeight.w700,
                ),
              ),
            TextSpan(text: visible[i].name),
          ],
          if (hidden > 0) TextSpan(text: '  +$hidden'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: resolved.centered ? TextAlign.center : null,
    );
  }
}
