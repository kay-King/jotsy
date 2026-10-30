import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// 日记列表查询的范围：全部日记、某本手动日记本、某本智能日记本，或未收录
/// （没进任何手动日记本的日记）。
///
/// 只描述“查哪些日记、按什么口径排序”，SQL 由数据库层
/// （`app_database_diary_scope_sql.dart`）生成。四种范围都遵守同一条私密规则：
/// 在隐藏 / 加锁的手动日记本里的日记只出现在那本私密日记本的范围内。
///
/// 实现了值相等：作为 Riverpod family 的 key（经 `DiaryPageQuery` 等）时，
/// 每次重建出的同一范围必须命中同一个 provider 实例。
@immutable
sealed class DiaryListScope {
  const DiaryListScope();

  /// 全部日记（全局时间线），排除私密日记。
  static const DiaryListScope all = DiaryAllScope();
}

/// 全部日记：首页默认范围，以及启动预热与各类全局查询的口径。
final class DiaryAllScope extends DiaryListScope {
  const DiaryAllScope();

  @override
  bool operator ==(Object other) => other is DiaryAllScope;

  @override
  int get hashCode => (DiaryAllScope).hashCode;

  @override
  String toString() => 'DiaryAllScope';
}

/// 一本手动日记本里的日记。
///
/// - [chapterId] 只看这一章；[unassignedChapterOnly] 只看“未分章”：章节为
///   空，或指向已不在 [chapterOrder] 里的章节（与 `updateNotebook` 清理
///   悬空章节前的口径一致）。两者互斥；
/// - [bookOrder] 为 true 时按成书顺序排：章节在 [chapterOrder] 里的先后
///   （未分章与认不出的章节排最后），再按本子内的 `position`，最后按创建时间；
///   此时列表的排序方式与置顶都不生效；
/// - [chapterOrder] 来自日记本 payload 的章节列表（`NotebookPayload.chapterIds`）。
/// - [descendantIds] 嵌套范围：自己 + 后代的业务 id（调用方经 NotebookTree
///   算好、排序后传入，保证 key 稳定）。为 null 时只查自己；章节筛选与书序
///   只作用于自己本内的成员行（子本的日记按时间混排在后，不参与章节与书序）。
@immutable
final class DiaryNotebookScope extends DiaryListScope {
  const DiaryNotebookScope({
    required this.notebookId,
    this.chapterId,
    this.unassignedChapterOnly = false,
    this.bookOrder = false,
    this.chapterOrder = const <String>[],
    this.descendantIds,
  }) : assert(
         chapterId == null || !unassignedChapterOnly,
         'chapterId 与 unassignedChapterOnly 互斥',
       );

  final String notebookId;
  final String? chapterId;
  final bool unassignedChapterOnly;
  final bool bookOrder;
  final List<String> chapterOrder;
  final List<String>? descendantIds;

  /// 实际查询的日记本 id：自己 + 后代（已排序去重）。
  List<String> get effectiveIds {
    final ids = descendantIds;
    if (ids == null || ids.isEmpty) return <String>[notebookId];
    return ids;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiaryNotebookScope &&
        other.notebookId == notebookId &&
        other.chapterId == chapterId &&
        other.unassignedChapterOnly == unassignedChapterOnly &&
        other.bookOrder == bookOrder &&
        _listEquals(other.chapterOrder, chapterOrder) &&
        _listEquals(
          other.descendantIds ?? const <String>[],
          descendantIds ?? const <String>[],
        );
  }

  @override
  int get hashCode => Object.hash(
    notebookId,
    chapterId,
    unassignedChapterOnly,
    bookOrder,
    Object.hashAll(chapterOrder),
    Object.hashAll(descendantIds ?? const <String>[]),
  );

  @override
  String toString() =>
      'DiaryNotebookScope($notebookId, chapter: $chapterId, '
      'unassigned: $unassignedChapterOnly, bookOrder: $bookOrder, '
      'descendants: ${descendantIds?.length ?? 0})';
}

/// 一本智能日记本：成员由规则现算，[predicate] 是规则编译出的 SQL 条件。
@immutable
final class DiarySmartScope extends DiaryListScope {
  const DiarySmartScope({required this.notebookId, required this.predicate});

  final String notebookId;
  final DiaryScopePredicate predicate;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiarySmartScope &&
        other.notebookId == notebookId &&
        other.predicate == predicate;
  }

  @override
  int get hashCode => Object.hash(notebookId, predicate);

  @override
  String toString() => 'DiarySmartScope($notebookId, ${predicate.sql})';
}

/// 未收录：没进任何手动日记本的日记（书架“未收录”行）。
///
/// 私密日记不在其中：私密日记在某本私密本子里，算“已收录”（只是不在全局
/// 查询里出现）。回收站与归档里的日记同样不算未收录（它们有独立的入口）。
@immutable
final class DiaryUnfiledScope extends DiaryListScope {
  const DiaryUnfiledScope();

  @override
  bool operator ==(Object other) => other is DiaryUnfiledScope;

  @override
  int get hashCode => (DiaryUnfiledScope).hashCode;

  @override
  String toString() => 'DiaryUnfiledScope';
}

/// 预先编译好的 SQL 布尔表达式，作用于别名为 `d` 的 `diaries` 表。
///
/// [sql] 里的 `?` 与 [variables] 按顺序一一对应；查询把它整体包在括号里与
/// 其他条件 AND 连接。表达式可以引用标签、日记本等其他表（相关子查询），
/// 数据库层为智能范围的流订阅了这些表的变化。
@immutable
class DiaryScopePredicate {
  const DiaryScopePredicate({
    required this.sql,
    this.variables = const <Variable<Object>>[],
  });

  final String sql;
  final List<Variable<Object>> variables;

  /// `Variable` 本身没有值相等，按参数值比较：规则不变时重新编译出的谓词
  /// 应当是同一个 key。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DiaryScopePredicate ||
        other.sql != sql ||
        other.variables.length != variables.length) {
      return false;
    }
    for (var i = 0; i < variables.length; i++) {
      if (other.variables[i].value != variables[i].value) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(sql, Object.hashAll(variables.map((v) => v.value)));
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
