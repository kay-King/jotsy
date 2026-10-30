import 'package:flutter/foundation.dart';

/// 日记本嵌套树：由一组日记本的（业务 id，父业务 id）构建的父子关系。
///
/// `parent_id` 存父本业务 id，null 为顶级。只允许手动日记本嵌套（智能本
/// 是规则现算的成员，不参与嵌套），调用方在构建前过滤。
///
/// 纯数据结构，无副作用：防环校验（设父本时不能指自己或后代）、取子本、取
/// 后代、取祖先都经它，避免各处手写递归。
@immutable
class NotebookTree {
  factory NotebookTree(Iterable<NotebookNode> nodes) {
    final children = <String, List<String>>{};
    final parent = <String, String?>{};
    for (final node in nodes) {
      parent[node.id] = node.parentId;
      final parentId = node.parentId;
      if (parentId != null) {
        (children[parentId] ??= <String>[]).add(node.id);
      }
    }
    return NotebookTree._(children, parent);
  }

  const NotebookTree._(this._children, this._parent);

  final Map<String, List<String>> _children;
  final Map<String, String?> _parent;

  /// 直接子本的业务 id（按传入顺序）。
  List<String> childrenOf(String id) =>
      List<String>.unmodifiable(_children[id] ?? const <String>[]);

  /// 直接父本的业务 id，null 为顶级或不存在。
  String? parentOf(String id) => _parent[id];

  /// 是否为顶级日记本（无父本）。
  bool isTopLevel(String id) => _parent[id] == null;

  /// 全部后代的业务 id（含间接子孙），不含自己；传入顺序为广度优先。
  Set<String> descendantsOf(String id) {
    final result = <String>{};
    final queue = <String>[...childrenOf(id)];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (result.add(current)) {
        queue.addAll(childrenOf(current));
      }
    }
    return result;
  }

  /// 自己 + 全部后代（范围查询用：父本范围含子本的日记）。
  Set<String> selfAndDescendants(String id) => <String>{
    id,
    ...descendantsOf(id),
  };

  /// 全部祖先的业务 id（从直接父到根），不含自己。
  List<String> ancestorsOf(String id) {
    final result = <String>[];
    var current = _parent[id];
    final seen = <String>{id};
    while (current != null && seen.add(current)) {
      result.add(current);
      current = _parent[current];
    }
    return result;
  }

  /// 把 [childId] 的父本设为 [parentId] 是否会成环：parentId 是自己或自己的
  /// 后代时成环。parentId 为 null（移到顶级）不成环。
  bool wouldCycle(String childId, String? parentId) {
    if (parentId == null) return false;
    if (parentId == childId) return true;
    return descendantsOf(childId).contains(parentId);
  }
}

/// 树的一个节点：日记本业务 id + 父业务 id（null 为顶级）。
@immutable
class NotebookNode {
  const NotebookNode(this.id, this.parentId);

  final String id;
  final String? parentId;
}
