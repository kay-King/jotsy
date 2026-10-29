import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/diary_comment_providers.dart';

/// 给卡片接留言数角标的订阅层：只订阅这一篇的计数流
/// （`diaryCommentCountProvider`，按 `diary_id` 做 `COUNT`），不读留言
/// 内容、不全表扫。加载中与出错时都按“未知”处理，[builder] 收到 null，
/// 卡片隐藏角标而不是报错。
///
/// 单独成层而不把 [DiaryCard] 改成 ConsumerWidget：卡片在设置页预览与
/// 一批不包 ProviderScope 的旧测试里直接使用，改成 Consumer 会让那些
/// 调用方全部崩掉；需要实时角标的列表经 [DiariesListSection] 的
/// `watchCommentCounts` 开关显式包这一层。
class DiaryCardCommentCountBuilder extends ConsumerWidget {
  const DiaryCardCommentCountBuilder({
    super.key,
    required this.diaryId,
    required this.builder,
  });

  final String diaryId;
  final Widget Function(BuildContext context, int? commentCount) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(diaryCommentCountProvider(diaryId)).value;
    return builder(context, count);
  }
}
