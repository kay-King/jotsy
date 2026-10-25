import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import 'diary_timeline_avatar.dart';

/// 时间线正文：超过 6 行折叠，右下角“更多”展开（fakeWechat 同款）。
///
/// 是否超行用 [TextPainter] 在布局宽度下实测（不靠字数估算，中文行宽与
/// 字号变化都算得准）；展开/收起只改 maxLines，高度经 [AnimatedSize]
/// 平滑过渡，时长走 ExpressiveMotion token。
class DiaryTimelineFoldableText extends StatefulWidget {
  const DiaryTimelineFoldableText({
    super.key,
    required this.text,
    this.style,
    this.foldLines = 6,
  });

  final String text;
  final TextStyle? style;

  /// 折叠后保留的行数。
  final int foldLines;

  @override
  State<DiaryTimelineFoldableText> createState() =>
      _DiaryTimelineFoldableTextState();
}

class _DiaryTimelineFoldableTextState extends State<DiaryTimelineFoldableText> {
  bool _expanded = false;

  // 上一次实测的条件与结果：文本、宽度、样式都不变时滚动重建不再重复量算。
  String _measuredText = '';
  double _measuredWidth = 0;
  TextStyle? _measuredStyle;
  bool _overflow = false;

  @override
  void didUpdateWidget(DiaryTimelineFoldableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effectiveStyle = DefaultTextStyle.of(
      context,
    ).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (_measuredText != widget.text ||
            _measuredWidth != width ||
            _measuredStyle != effectiveStyle) {
          _measuredText = widget.text;
          _measuredWidth = width;
          _measuredStyle = effectiveStyle;
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: effectiveStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: widget.foldLines,
          )..layout(maxWidth: width);
          _overflow = painter.didExceedMaxLines;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedSize(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: effectiveStyle,
                maxLines: _expanded ? null : widget.foldLines,
              ),
            ),
            if (_overflow)
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _expanded ? l10n.timelineCollapse : l10n.autoT0125,
                    style: effectiveStyle.copyWith(
                      color: DiaryTimelineAvatar.accentGreen,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
