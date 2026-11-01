import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_spacing.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import '../models/changelog_entries.dart';
import '../models/changelog_entry.dart';
import '../widgets/release_notes_view.dart';

/// 更新日志页：按版本从新到旧列出历次更新。
///
/// 每张卡片显示版本号与版本要点，点"展开全部"查看完整内容（`ReleaseNotesView`
/// 渲染 Markdown 子集）。说明随应用打包，离线可看。
class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppTopBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(l10n.changelogTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.m,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        itemCount: changelogEntries.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: AppSpacing.m),
        itemBuilder: (BuildContext context, int index) =>
            _ChangelogCard(entry: changelogEntries[index]),
      ),
    );
  }
}

class _ChangelogCard extends StatefulWidget {
  const _ChangelogCard({required this.entry});

  final ChangelogEntry entry;

  @override
  State<_ChangelogCard> createState() => _ChangelogCardState();
}

class _ChangelogCardState extends State<_ChangelogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final entry = widget.entry;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.version,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w400,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final highlight in entry.highlightsFor(languageCode))
              _HighlightRow(text: highlight),
            AnimatedSize(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ReleaseNotesView(
                        markdown: entry.detailsFor(languageCode),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? l10n.changelogCollapse : l10n.changelogExpandAll,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
