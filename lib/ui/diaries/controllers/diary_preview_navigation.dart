import 'package:flutter/material.dart';

import '../pages/diary_preview_page.dart';

/// 按业务 id 打开日记预览页（单篇入口，不带翻页顺序）。
///
/// 日记链接（`diary://` 行内链接、日记卡片、反向链接）点按后统一走这里。
Future<void> openDiaryPreviewById(BuildContext context, String diaryId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => DiaryPreviewPage(diaryId: diaryId),
    ),
  );
}
