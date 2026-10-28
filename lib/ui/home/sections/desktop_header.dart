import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/utils/relative_time_formatter.dart';

import '../models/desktop_view_data.dart';

/// 桌面页顶部：日期 + 问候（问候语按时间变，昵称来自个人资料）。
class DesktopHeader extends StatelessWidget {
  const DesktopHeader({super.key, required this.now, required this.nickname});

  final DateTime now;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _dateLine(now, l10n),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_greeting(now, l10n)}，$nickname',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// 日期行：中文 “10月25日 · 星期六”，英文 “Saturday, Oct 25”。
  String _dateLine(DateTime date, AppLocalizations l10n) {
    final locale = l10n.localeName;
    if (locale.startsWith('zh')) {
      return '${DateFormat('M月d日', locale).format(date)} · '
          '${DateFormat.EEEE(locale).format(date)}';
    }
    return DateFormat('EEEE, MMM d', locale).format(date);
  }

  /// 问候语（与 fakeWechat 的 greetWord 同一套时间分段）。
  String _greeting(DateTime date, AppLocalizations l10n) {
    final hour = date.hour;
    if (hour < 6) return l10n.desktopGreetingLateNight;
    if (hour < 11) return l10n.desktopGreetingMorning;
    if (hour < 14) return l10n.desktopGreetingNoon;
    if (hour < 18) return l10n.desktopGreetingAfternoon;
    return l10n.desktopGreetingEvening;
  }
}

/// 总览数一行：已记录 N 篇 · 连续记录 X 天 · 最近更新 …；没有日记时一句空态。
class DesktopStatsLine extends StatelessWidget {
  const DesktopStatsLine({super.key, required this.data, required this.now});

  final DesktopData? data;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final current = data;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurfaceVariant,
    );
    if (current == null || current.latestDiary == null) {
      return Text(l10n.desktopStatsLineEmpty, style: style);
    }
    return Text(
      l10n.desktopStatsLine(
        current.totalRecords,
        current.streakDays,
        RelativeTimeFormatter.formatUpdatedAt(
          updatedAt: current.latestDiary!.updatedAt,
          now: now,
          l10n: l10n,
        ),
      ),
      style: style,
    );
  }
}
