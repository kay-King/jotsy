import '../../../../core/database/app_database.dart';
import '../../../../utils/pinyin/name_index.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';

/// @ 提及的候选：日记或日记本（名称匹配 + 拼音）。
///
/// 检索只经 [NameIndexKey]（汉字 A–Z 归组、拼音排序与拼音检索的统一入口，
/// 见 AGENTS.md）：标题/名称包含检索词，或拼音/首字母匹配。

/// @ 候选。
sealed class DiaryMentionCandidate {
  const DiaryMentionCandidate();
}

/// 日记候选。
class MentionDiaryCandidate extends DiaryMentionCandidate {
  const MentionDiaryCandidate({
    required this.diaryId,
    required this.title,
    required this.createdAt,
    this.coverPath,
  });

  final String diaryId;
  final String title;
  final DateTime createdAt;
  final String? coverPath;
}

/// 日记本候选。
class MentionNotebookCandidate extends DiaryMentionCandidate {
  const MentionNotebookCandidate({
    required this.notebookId,
    required this.name,
  });

  final String notebookId;
  final String name;
}

/// 在内存里过滤 @ 候选：日记（标题匹配 + 拼音）与日记本（名称匹配 + 拼音）。
///
/// [diaries] 由调用方按需取好（拼音检索走不了 SQL LIKE，所以不在库里
/// 过滤）；[query] 为空时返回最近的日记与日记本。[excludeDiaryId]：
/// 正在编辑的这篇不列为候选（不自己链自己）。
List<DiaryMentionCandidate> filterMentionCandidates({
  required List<Diary> diaries,
  required List<NotebookView> notebooks,
  required String query,
  String? excludeDiaryId,
  int diaryLimit = 6,
  int notebookLimit = 4,
}) {
  final nameQuery = normalizeNameQuery(query);
  final matchedDiaries = <MentionDiaryCandidate>[];
  for (final diary in diaries) {
    if (diary.diaryId == excludeDiaryId) continue;
    if (!NameIndexKey.of(diary.title).matches(nameQuery)) continue;
    matchedDiaries.add(
      MentionDiaryCandidate(
        diaryId: diary.diaryId,
        title: diary.title,
        createdAt: diary.createdAt,
        coverPath: diary.cover,
      ),
    );
    if (matchedDiaries.length >= diaryLimit) break;
  }
  final matchedNotebooks = <MentionNotebookCandidate>[];
  for (final notebook in notebooks) {
    if (notebook.isClosed) continue;
    if (!NameIndexKey.of(notebook.name).matches(nameQuery)) continue;
    matchedNotebooks.add(
      MentionNotebookCandidate(notebookId: notebook.id, name: notebook.name),
    );
    if (matchedNotebooks.length >= notebookLimit) break;
  }
  return <DiaryMentionCandidate>[...matchedDiaries, ...matchedNotebooks];
}

/// 搜索 @ 候选：取最近 [recentLimit] 篇日记再经 [filterMentionCandidates]
/// 过滤（拼音检索走不了 SQL LIKE）。
Future<List<DiaryMentionCandidate>> searchMentionCandidates({
  required AppDatabase db,
  required List<NotebookView> notebooks,
  required String query,
  String? excludeDiaryId,
  int diaryLimit = 6,
  int notebookLimit = 4,
  int recentLimit = 120,
}) async {
  final diaries = await db.getActiveDiariesPage(limit: recentLimit, offset: 0);
  return filterMentionCandidates(
    diaries: diaries,
    notebooks: notebooks,
    query: query,
    excludeDiaryId: excludeDiaryId,
    diaryLimit: diaryLimit,
    notebookLimit: notebookLimit,
  );
}

/// 日记卡片挑选器用的候选：只搜日记。
Future<List<MentionDiaryCandidate>> searchDiaryCandidates({
  required AppDatabase db,
  required String query,
  String? excludeDiaryId,
  int limit = 30,
}) async {
  final nameQuery = normalizeNameQuery(query);
  final diaries = await db.getActiveDiariesPage(limit: 200, offset: 0);
  final matched = <MentionDiaryCandidate>[];
  for (final diary in diaries) {
    if (diary.diaryId == excludeDiaryId) continue;
    if (!NameIndexKey.of(diary.title).matches(nameQuery)) continue;
    matched.add(
      MentionDiaryCandidate(
        diaryId: diary.diaryId,
        title: diary.title,
        createdAt: diary.createdAt,
        coverPath: diary.cover,
      ),
    );
    if (matched.length >= limit) break;
  }
  return matched;
}
