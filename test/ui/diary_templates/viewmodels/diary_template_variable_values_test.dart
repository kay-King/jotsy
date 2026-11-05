import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/calendar/viewmodels/calendar_lunar_day.dart';
import 'package:node_diary/ui/diary_templates/models/built_in/diary_template_questions.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_variables.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_labels.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_variable_values.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('zh');
    await initializeDateFormatting('en');
  });

  DiaryTemplateVariableValues compute(
    DateTime day, {
    DateTime? now,
    int shift = 0,
    bool english = false,
  }) => DiaryTemplateVariableValues.compute(
    l10n: english ? en : zh,
    diaryDate: day,
    now: now ?? DateTime(2026, 10, 18, 8, 5),
    questionShift: shift,
  );

  test('dates follow the interface language', () {
    final day = DateTime(2026, 10, 18);
    final values = compute(day);
    expect(values[DiaryTemplateVariable.date], '2026年10月18日');
    expect(values[DiaryTemplateVariable.weekday], '星期日');
    expect(values[DiaryTemplateVariable.time], '08:05');
    expect(values[DiaryTemplateVariable.month], '十月');
    final english = compute(day, english: true);
    expect(english[DiaryTemplateVariable.date], 'October 18, 2026');
    expect(english[DiaryTemplateVariable.weekday], 'Sunday');
  });

  test('a backfilled diary uses its own date, but the time is now', () {
    final values = compute(
      DateTime(2026, 10, 17),
      now: DateTime(2026, 10, 18, 21, 40),
    );
    expect(values.resolve('{{日期}} {{时间}}'), '2026年10月17日 21:40');
  });

  test('ISO week numbers across a year boundary', () {
    expect(isoWeekNumber(DateTime(2026, 1, 1)), 1); // 周四
    expect(isoWeekNumber(DateTime(2027, 1, 1)), 53); // 周五，属于 2026 第 53 周
    expect(isoWeekNumber(DateTime(2024, 12, 30)), 1); // 周一，属于 2025 第 1 周
    expect(isoWeekNumber(DateTime(2026, 10, 18)), 42);
  });

  test('day of year and year progress handle leap years', () {
    expect(
      compute(DateTime(2028, 12, 31))[DiaryTemplateVariable.dayOfYear],
      '366',
    );
    expect(
      compute(DateTime(2026, 3, 1))[DiaryTemplateVariable.dayOfYear],
      '60',
    );
    expect(
      compute(DateTime(2026, 12, 31))[DiaryTemplateVariable.yearProgress],
      '100%',
    );
    expect(
      compute(DateTime(2026, 7, 2))[DiaryTemplateVariable.yearProgress],
      '50%',
    );
  });

  test('lunar date and solar term come from the calendar', () {
    final day = DateTime(2026, 10, 18);
    final lunar = CalendarLunarDay.of(day);
    final values = compute(day);
    expect(values[DiaryTemplateVariable.lunar], lunar.date);
    // 10 月 18 日不是节气当天，仍有所在的节气期（寒露）。
    expect(lunar.term, isNull);
    expect(values[DiaryTemplateVariable.solarTerm], '寒露');
  });

  test('the question is fixed per day and moves with the shift', () {
    final questions = diaryTemplateQuestions(zh);
    final day = DateTime(2026, 10, 18);
    final first = compute(day)[DiaryTemplateVariable.question];
    expect(compute(day)[DiaryTemplateVariable.question], first);
    final next = compute(day, shift: 1)[DiaryTemplateVariable.question];
    expect(questions.indexOf(next!), (questions.indexOf(first!) + 1) % 30);
    expect(
      compute(DateTime(2026, 10, 19))[DiaryTemplateVariable.question],
      next,
    );
  });

  test('time takes a format after a colon', () {
    final values = compute(
      DateTime(2026, 10, 18),
      now: DateTime(2026, 10, 18, 8, 5, 9),
    );
    expect(values.resolve('{{时间:HH:mm:ss}}'), '08:05:09');
    expect(values.resolve('{{时间:ah:mm}}'), '上午8:05');
    expect(values.resolve('{{时间}}'), '08:05');
    final english = compute(
      DateTime(2026, 10, 18),
      now: DateTime(2026, 10, 18, 20, 5),
      english: true,
    );
    // 字面图案里的空格按写出的输出；骨架 jm 查 locale 数据，AM/PM 前是
    // 窄不换行空格（U+202F）。
    expect(english.resolve('{{time:h:mm a}}'), '8:05 PM');
    // 骨架同名写法按 intl 的本地图案走。
    expect(english.resolve('{{time:jm}}'), '8:05\u202FPM');
  });

  test('a format on another variable stays as written', () {
    final values = compute(DateTime(2026, 10, 18));
    expect(values.resolve('{{日期:yyyy}}'), '{{日期:yyyy}}');
    expect(values.resolve('{{时间:}}'), '{{时间:}}');
  });

  test('unusable time patterns stay as written', () {
    final moment = DateTime(2026, 10, 18, 8, 5);
    // 认不出的字母当原文输出、未闭合的引号截掉后文、时区字段输出空串：
    // 这些图案都不能用。
    expect(formatDiaryTemplateMoment(moment, 'foo', 'zh'), isNull);
    expect(formatDiaryTemplateMoment(moment, 'hh:mm A', 'zh'), isNull);
    expect(formatDiaryTemplateMoment(moment, "hh:mm '", 'zh'), isNull);
    expect(formatDiaryTemplateMoment(moment, 'HH:mm z', 'zh'), isNull);
    // 只有原文、没有字段也不行。
    expect(formatDiaryTemplateMoment(moment, '点', 'zh'), isNull);
    // 引号里的字母原文可以。
    expect(
      formatDiaryTemplateMoment(moment, "HH'点'mm", 'zh'),
      '08点05',
    );
    // intl 仍抛错时也原样保留（6 个以上的 E）。
    expect(formatDiaryTemplateMoment(moment, 'EEEEEE', 'zh'), isNull);
  });

  test('the 12-hour time format in the variables sheet resolves', () {
    for (final l10n in [zh, en]) {
      final values = DiaryTemplateVariableValues.compute(
        l10n: l10n,
        diaryDate: DateTime(2026, 10, 18),
        now: DateTime(2026, 10, 18, 20, 5),
      );
      final token = diaryTemplateVariableToken(
        l10n,
        DiaryTemplateVariable.time,
        format: l10n.diaryTemplateVarTime12hFormat,
      );
      final resolved = values.resolve(token);
      expect(resolved, isNot(contains('{{')), reason: token);
      expect(resolved, contains('8:05'), reason: token);
    }
  });
}
