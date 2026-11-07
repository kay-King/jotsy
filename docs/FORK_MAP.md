# Fork 整理清单（FORK_MAP）

> **这是什么**：kay-King/jotsy 相对上游 CikeSeven/jotsy 的改动清单，按页面、按功能列清楚，标明哪些能一起改、哪些不能。目标是让以后的改动（包括合上游 v0.12.0）不用每次现翻代码，先查这份清单。
>
> **活文档**：每次改动顺手更新这里。改了一个页面的文件，就把对应行改对；新增了功能，就在对应表里加一行；从上游合进来的东西，把对应行划掉或改成“已与上游一致”。
>
> **只列清单，不动手改**：疑似冗余只列出收益与风险，改回原版是下一步、要用户点头。

## 0. 基线与口径（先读这节，不然数字会对不上）

- **基线**：`git diff upstream/main...HEAD`（三点式），合并基 `b6959397`（上游 PR #72），HEAD `36cbf65e`（样式编辑器 v5–v8，2026-11-07）。上游 main 当时已是 v0.12.0+25、数据库 v18。
- **口径 A（三点 diff vs 合并基）**：fork 自分叉点以来做了什么。共 **792 个文件，+111,507 / −24,267 行**（新增 320、修改 437、删除 35）。本文的四类统计用口径 A。
- **口径 B（fork HEAD vs 上游 main 逐文件比对）**：现在合上游还剩多少真实差异。结果出人意料：**96 个文件与上游逐字节相同**（见 §6.1）——fork 当初改造着合进来的 v0.10.0/v0.11.0 功能，很多已被上游原样收编，整理时可直接划掉。
- **一个结构性事实**：合并基 `b6959397` 里既没有 `lib/core/services/lan_sync/`（上游 v0.11.0 有 76 个文件），也没有 `lib/ui/diaries/widgets/diary_editor/`（上游 v0.11.0 有 40 个文件）。这两个目录是分叉之后上游新增的，fork 从未取过（局域网同步是用户决定不做；Quill 编辑器在 AppFlowy 迁移时被 fork 自己的实现取代）。所以三点 diff 里看不到它们；拿 fork 树直接对上游 v0.11.0 树比（两点式）是 **1701 个文件、+66,137 / −206,986**，差额主要就是这两块“上游有、fork 没有”的内容。
- **分类方法**：每个文件按主导性质单归一类，混合文件在清单里注明次要性质。测试文件（224 个）只统计、不逐项分类。

## 1. 总览：四类统计

| 类 | 含义 | 文件数（口径 A，约数） |
|---|---|---|
| ① 纯样式/主题 | 只改颜色、间距、字号、图标、控件外观，不改逻辑 | **约 119** |
| ② 布局调整 | 页面结构、导航、排列、Tab 合并/分组方式变了 | **约 24** |
| ③ 自加新功能 | fork 自己加的，原版没有（或 fork 版与上游平行实现且差异大） | **约 326** |
| ④ 疑似冗余 | 逻辑与原版完全一样、只是换了写法/换名/挪位（能直接改回原版的见 §6 细分，真能直接改回的其实很少） | **约 83** |
| 不计入四类 | 生成文件（`app_database.g.dart`、l10n 生成文件 ×3、`pubspec.lock`）、文档（`AGENTS.md`、`DESIGN.md`）、`pubspec.yaml`、已删文件 | 约 19 |

分片明细（口径 A）：

| 范围 | 文件数 | ① | ② | ③ | ④ |
|---|---|---|---|---|---|
| `lib/ui/diaries/`（日记列表/预览/编辑器/时间线/卡片等） | 194（新增 63、修改 128、删除 3） | 31 | 8 | 100 | 55 |
| `lib/ui/settings/`、`home/`、`notebooks/`、`explore/`、`widgets/`、`diary_templates/`、`calendar/`、`anniversaries/` | 188（新增 51、修改 129、删除 8） | 80 | 16 | 61 | 28 |
| `lib/core/`、`lib/ui/ai/`、`lib/app/`、`lib/l10n/`、`android/`、`pubspec.*`、文档 | 181（新增 115、修改 66） | 8 | 0 | 约 165 | 约 0（严格口径） |
| 测试 `test/`（只统计） | 224（`test/ui/` 168、`test/core/` 35、`test/preview/` 12、`test/support/` 8、`test/app/` 1） | — | — | — | — |
| 其余（`lib/utils/`、`ios/`、`.gitignore`、`.github/workflows/`、`macos/`） | 5 | — | — | — | — |
| **合计** | **792** | **约 119** | **约 24** | **约 326** | **约 83** |

> 注：边界文件按主导性质计数，个别文件在 ①/②/③ 之间可能有一两处主观出入；④ 的细分见 §6——三个分片对 ④ 的判定口径不同，§6 会讲清楚。

### 1.1 各类一句话画像

- **① 纯样式（约 119）**：Salt 主题是最大头——页面底 `#FAFBFC`、卡片纯白、Salt 蓝 `#0470E6`、分组白卡+卡内蓝组标题、平铺行（不要灰色长条行）、行首图标深黑 20、标题字重 w400、自绘 Salt 风控件（`lib/ui/widgets/salt_switch.dart` 等）。集中在 `lib/ui/settings/`（45 个）和 `lib/ui/diaries/models/diary_card_style/`、`diary_preview_style/`。
- **② 布局调整（约 24）**：首页合并 v4、样式编辑器 v5–v8（药丸+滑杆行、直角满宽面板、底部 tab）、探索页删除并进首页、筛选从顶栏搬进 BottomSheet、Dismissible→自研侧滑。集中在 `lib/ui/home/` 与样式编辑器外壳。
- **③ 自加新功能（约 326）**：AI 助手全套、增量备份、拍照/录像、文字选区菜单、时间线 Moments 页、简洁编辑器、日记留言、笔记本嵌套、暖阳/备忘预设、心情色板、个人资料、桌面布局、那年今日/情绪趋势页、画廊 v2。集中在 `lib/ui/ai/`（60 个全新增）、`lib/core/services/ai/`（15 个全新增）、`lib/ui/diaries/`（100 个）。
- **④ 疑似冗余（约 83）**：大头是 50 个 Quill→AppFlowy 迁移适配文件——逻辑与原版等价，但**不可单独改回**（调用方已不再传 Quill 对象，改回即编译失败）。真正能直接改回原版的是 §6.1 的 96 个“与上游逐字节相同”文件（口径 B，含 ④ 之外的已合上游代码）。

## 2. 按页面 / 功能的清单

符号：① 纯样式 ② 布局调整 ③ 新功能 ④ 疑似冗余。只列本范围（口径 A）的文件；“牵连”指共用状态 / 设置项 / 控件 / 数据库表，牵连的页面不能单独改。

### 2.1 日记列表页（`lib/ui/diaries/pages/diaries_page.dart`，② 为主，混合 ③）

| 文件 | 类 | 说明 |
|---|---|---|
| `pages/diaries_page.dart` | ② | +377/−447（1049→979 行），逻辑抽到控制器 |
| `controllers/diaries_page_controller.dart` | ③ | 批量操作事务化 |
| `controllers/diaries_notebook_scope_controller.dart` | ③ | 未收录入口 + 多选复位 |
| `controllers/diaries_notebook_membership_controller.dart` | ③ | 日记本成员操作 |
| `controllers/diaries_select_all_controller.dart` | ③ 新增 | 全选常驻多选 |
| `controllers/diaries_tag_batch_controller.dart` | ③ 新增 | 批量打标签 |
| `controllers/diary_list_transition_coordinator.dart` | ③ | `_HideBatch` 批量隐藏 |
| `sections/diary_head_section.dart` | ② | 多选顶栏 + 抽屉/AI 入口 |
| `sections/diaries_list_section.dart` | ③ | 留言数接线 |
| `sections/diary_view_options_sheet.dart` | ① | Salt 分段 + 收紧 |
| `sections/diary_tag_batch_sheet.dart` | ③ 新增 | 批量标签面板 |
| `widgets/diary_notebook_drawer.dart` | ③ 新增（491 行） | 左侧边栏（日记本树 + 标签筛选） |
| `widgets/diary_filter_sheet.dart` | ② 新增 | 筛选从顶栏搬进 BottomSheet |
| `widgets/diaries_fast_scroller.dart` | ③ 新增 | 快速滚动条（见 §5.4） |
| `viewmodels/diary_timeline_index.dart` | ③ 新增 | 快滚条数据（气泡标签与分段刻度） |
| `viewmodels/diary_selection_summary.dart` | ③ 新增 | 多选顶栏派生状态 |
| `providers/diary_timeline_provider.dart` | ③ 新增 | `watchDiaryTimeline` |
| `providers/diary_filters.dart` | ③ | `timelineKey` |
| `widgets/diary_swipe_action_item.dart` | ② | Dismissible→自研侧滑（AGENTS.md §6 规定：只经此组件，禁止改回 Dismissible） |
| `widgets/diary_swipe_action_background.dart` | ③ 新增 | 侧滑背景 |

**牵连**：时间线页（共用 `pagedDiariesProvider` 与 `diaryTimelineProvider`）、搜索/归档页（共用 `DiariesListSection` + `DiaryCard`）、预览页（翻页顺序来自同一查询）。

### 2.2 预览页（`lib/ui/diaries/pages/diary_preview_page.dart` + `widgets/diary_preview/`）

| 文件 | 类 | 说明 |
|---|---|---|
| `pages/diary_preview_page.dart` | ③ | +12：`diary://` 点按开新预览 |
| `widgets/diary_preview/diary_appflowy_preview.dart` | ④-M 新增（1387 行） | 替代 Quill 预览渲染（迁移适配，不可单独改回） |
| `widgets/diary_preview/diary_preview_body.dart` | ④-M | 预览正文 |
| `widgets/diary_preview/diary_preview_content.dart` | ③ | 留言区 + AI 回应 + 标题分隔线 |
| `widgets/diary_preview/diary_preview_view.dart` | ④-M 为主 + ③ | Quill→`EditorState` 绑定、`_toggleTodo` 走 transaction；AI 回应入口 |
| `widgets/diary_preview/diary_preview_header.dart` | ① | 标题分隔线 |
| `widgets/diary_preview/diary_preview_pager.dart` | ③ | `onOpenDiary` 透传 |
| `widgets/diary_preview/diary_preview_top_bar.dart` | ① | FaIcon→Material Icons |
| `widgets/diary_preview/diary_preview_actions_sheet.dart` | ③ | AI 回应菜单项 |
| `widgets/diary_preview/diary_preview_comments.dart` | ③ 新增（375 行） | 留言区 |
| `widgets/diary_preview/diary_backlinks.dart` | ③ 新增（205 行） | 反向链接 |
| `controllers/diary_preview_navigation.dart` | ④-E 新增（14 行） | `openDiaryPreviewById` 小 helper（见 §6.3） |
| `controllers/diary_edit_entry_flow.dart` | ③ 新增 | 编辑入口含简洁/完整选择 |

**牵连**：留言表（`providers/diary_comment_providers.dart`，§2.7）、编辑器页（`openDiaryEditorForDetail` 返回后刷新）、时间线页（点条目进预览）、卡片/链接（`diary://` 来源）。

### 2.3 编辑器页（`lib/ui/diaries/pages/edit_diary_page.dart`，③ 为主，混合 ④-M）

| 文件 | 类 | 说明 |
|---|---|---|
| `pages/edit_diary_page.dart` | ③ | +812/−161（1375→2026 行） |
| `controllers/edit_diary_controller.dart` | ④-M | `replaceContentController`→`replaceEditorState` |
| `controllers/edit_diary_media_controller.dart` | ③ | 拍照/录像 + 这天照片插入 |
| `controllers/edit_diary_persistence_controller.dart` | ③ | 返回先收 AI 面板 |
| `controllers/edit_diary_recording_controller.dart` | ④-M | 录音 |
| `controllers/edit_diary_template_flow.dart` | ④-M | 模板套用 |
| `controllers/edit_diary_ai_flow.dart` | ③ 新增（240 行） | AI 写入流程（part of 编辑页） |
| `controllers/diary_ai_editing.dart` | ③ 新增（570 行） | AI 唯一正文写入出口 |
| `controllers/diary_editor_controller.dart` | ③ 新增（167 行） | AI 用薄 wrapper |
| `controllers/diary_editor_selection.dart` | ③ 新增 | 选区菜单剪贴板 |
| `controllers/diary_embed_editing.dart` + `diary_embed_keys.dart` | ③ 新增 | 嵌入块退格/Delete 两段删除 |
| `controllers/diary_paragraph_indent_editing.dart` | ③ 新增 | 首行缩进（上游 #122） |
| `controllers/diary_text_process_flow.dart` | ③ 新增 | Android 文字处理 |
| `controllers/diary_code_block_editing.dart`、`diary_caret_follow_controller.dart`、`diary_code_language_tracker.dart`、`diary_todo_autosave_controller.dart` | ④-M | 代码块/光标跟随/待办自动保存 |
| `controllers/diary_media_import_controller.dart` | ③（含迁移） | 相机拍摄 |
| `controllers/diary_image_embed_actions.dart` | ④-M | 按偏移→按 `Node` |
| `controllers/diary_video_player_controller.dart` | ③ | `content://` 视频 |
| `widgets/diary_toolbar_config.dart` | ③（含迁移） | +591/−235：AI/表格/分隔线/折叠/提示块新工具项 + AppFlowy 重写 |
| `widgets/diary_mobile_toolbar.dart`、`diary_floating_toolbar*.dart`、`diary_toolbar_media_button.dart` | ④-M 为主 + ③ | 工具栏（+AI/相机） |
| `widgets/diary_color_panel/*` | ④-M | 颜色面板 |
| `widgets/diary_code_block/*` | ④-M | 代码块（见 §6.4） |
| `widgets/diary_mention/*` | ③ 新增 | @提及 + `/` 菜单 + `diary://`/`notebook://` |
| `widgets/diary_link_card/*` | ③ 新增（5 文件） | 链接卡片 |
| `widgets/diary_toggle_block/*` | ③ 新增（3 文件） | 折叠块 |
| `widgets/diary_callout_block/*` | ③ 新增 | 提示块 |
| `models/diary_table_block.dart` + `diary_divider_block.dart` | ③ 新增 | 表格块/分隔线块 |
| `viewmodels/diary_first_line_indent.dart` | ③ 新增 | 首行缩进 |
| `widgets/diary_editor_selection_menu_items.dart` + `diary_selection_toolbar_overlay.dart` | ③ 新增 | 手机选区菜单 |
| `widgets/diary_trailing_line_tap.dart` | ③ 新增 | 末行点按 |
| `widgets/diary_armed_embed_frame.dart` | ③ 新增 | 嵌入块选中框 |
| `widgets/diary_quote_bar.dart` | ① 新增 | 替代写死亮青 `#00BCF0` |
| `widgets/diary_image_options_menu.dart` | ④-M + ③ | +AI 看图说话 |
| `widgets/diary_image_embed_builder.dart`、`diary_video_embed_builder.dart`、`diary_audio_embed_builder.dart`、`diary_attachment_embed_builder.dart`、`diary_divider_embed_builder.dart` | ④-M | 嵌入块渲染器 |
| `widgets/diary_playback_interaction_guard.dart` | ④-M | 播放交互守卫 |
| `models/` 下 `image_insertion.dart`、`media_insertion.dart`、`recording_insertion.dart`、`diary_image_embed_data.dart`、`diary_playback_gestures.dart`、`diary_text_colors.dart`、`diary_toolbar_time_format.dart` | ④-M | 插入/颜色/时间（Quill→AppFlowy） |

**牵连**：预览页（同一块文档 schema，编辑后预览刷新）、发布页（`publish_diary_preview.dart` ④-M，共用 `DiaryAppFlowyPreview`）、这天照片（`diary_day_photos_*` 插入链路）、草稿（`new_diary_draft.dart` ③，`simpleComposer` 标记）。

### 2.4 时间线页（Moments，③ 新增整页）

| 文件 | 类 | 说明 |
|---|---|---|
| `pages/timeline_page.dart` | ③ 新增（493 行） | 朋友圈式：封面+头像+昵称+简介+分页，复用 `pagedDiariesProvider` |
| `widgets/diary_timeline/diary_timeline_item.dart`、`diary_timeline_grid.dart`（九宫格）、`diary_timeline_avatar.dart`、`diary_timeline_text.dart` | ③ 新增 | 时间线条目 |
| `providers/diary_profile_provider.dart` | ③ 新增（137 行） | 昵称默认“我” |
| `sections/diary_timeline_entry_menu_sheet.dart` | ③ 新增 | 条目菜单（编辑/查看/删除，软删+4 秒撤销） |
| `viewmodels/diary_card_media_summary.dart` | ③ | `maxImages` 4→9 + `totalCount` 徽章 |

**牵连**：日记页（`diary_view_preferences.dart` ②：`timeline` 布局值已移除，旧值回退列表；时间线视图移入独立页）、个人资料（设置页 `profile_page.dart` + 桌面页共用 `diary_profile_provider`）、预览页（点条目进入）、卡片（九宫格取前 9 张与 `maxImages=9` 绑定）。

### 2.5 相册 / 这天照片视频

范围内没有独立画廊页文件（画廊年/月/日页在 `lib/ui/explore/`，见 §2.13）。范围内只有“这天照片视频”一组：

| 文件 | 类 | 说明 |
|---|---|---|
| `pages/diary_day_photo_preview_page.dart` | ③ 新增（352 行） | 这天照片预览页 |
| `controllers/diary_day_photos_controller.dart` | ③ | 视频权限/计数/封面 |
| `widgets/diary_day_photos/diary_day_photo_tile.dart` | ③ | +206/−182：视频时长 + Hero 预览重写 |
| `widgets/diary_day_photos/diary_day_photo_badges.dart`、`diary_day_photo_preview_items.dart` | ③ 新增 | 徽章/预览项 |
| `widgets/diary_day_photos/diary_day_photos_sheet.dart`、`diary_day_photos_limited_hint.dart`、`diary_day_photos_sheet_states.dart`、`diary_day_photos_strip.dart` | ③ | 视频授权与插入 |

**牵连**：编辑器页（插入链路）、视频播放器（`diary_video_player_controller.dart` 的 `content://` + `diary_video_controls.dart` ③，共用进度条）。

### 2.6 日记卡片（列表 / 搜索 / 归档 / 日历共用渲染器——改一处影响四处）

| 文件 | 类 | 说明 |
|---|---|---|
| `widgets/diary_card/diary_card.dart` | ③ | 留言数 + 媒体徽章 + 底栏封面 |
| `widgets/diary_card/diary_card_content.dart` | ② | `_bottom` 通栏封面 + 暖阳配色 |
| `widgets/diary_card/diary_card_blocks.dart` | ② | 日期块兜底/行内日期/页脚开关 |
| `widgets/diary_card/diary_card_lines.dart` | ① | +302/−133，按预设重写行排布 |
| `widgets/diary_card/diary_card_cover.dart` | ① | 拼贴最多 3 张 |
| `widgets/diary_card/diary_card_cover_placeholder.dart` | ① | 封面占位 |
| `widgets/diary_card/diary_card_comment_count.dart` | ③ 新增 | 留言数角标 |
| `models/diary_card_style/*`（9 文件） | ① | `diary_card_style_presets.dart` 新增暖阳 `_warm` + 备忘 `_memo` 预设与杂志重调；`diary_card_color_spec.dart` 删 light/dark 双值、加 `warm` 源；`diary_card_meta_style.dart` 加 `bigDate`/`inlineDate`/`mediaBadge`/`dateAccent`；其余为默认值/枚举/JSON |
| `viewmodels/diary_card_appearance.dart`、`diary_card_colors.dart`（暖阳陶土橘 `#C47030`）、`diary_card_date_formatter.dart`（备忘用 `dateTime` 格式）、`diary_card_resolved_style.dart`、`diary_card_shadows.dart`（投影 0.6→0.15） | ① | 卡片外观解析 |
| `viewmodels/diary_card_media_summary.dart` | ③ | 媒体摘要 |

**牵连**：`DiariesListSection` 是 `DiaryCard` 唯一调用方，日记页/搜索页/归档页都经它渲染；样式模型同时被设置页样式编辑器（§2.9）读写。**注意**：`diary_card_color_spec.dart` 删 light/dark 后，旧存档里的深色值读取时被丢弃（`diary_card_style_json.dart` 同步删了 `_argb`/`_hex` 辅助函数）。

### 2.7 搜索 / 归档 / 草稿页

| 文件 | 类 | 说明 |
|---|---|---|
| `pages/diary_search_page.dart` | ③ | +180：搜留言开关 + “留言匹配”分组，去重后用 `DiariesListSection` 复用渲染 |
| `providers/diary_comment_providers.dart` | ③ 新增（62 行） | 留言 provider |
| `pages/archived_diaries_page.dart` | ③ | +12/−4：`swipeArchive` 功能开关 + 留言数 |
| `controllers/archived_diaries_controller.dart` | ④-C | 仅 1 行注释改动（见 §6.3） |
| `pages/diary_drafts_page.dart` | ④-C | 仅 1 行注释改动（见 §6.3） |
| `sections/diary_draft_picker_sheet.dart` | ① | 图标 16→20 |

**留言牵连（跨页）**：留言表 `diary_comments`（`core/database/app_database_diary_comment_*`）被 `diary_comment_providers.dart`、预览留言区、卡片角标、搜索页、导出（`export/diary_export_controller.dart` ③逐篇读留言；`diary_export_markdown/html/text.dart` ③追加“留言”段；`diary_export_entry.dart` ③加 `comments` 字段）共用；`lib/ui/ai/sections/ai_replies_section.dart` 也读同一 provider。

### 2.8 发布页与简洁编辑器

| 文件 | 类 | 说明 |
|---|---|---|
| `pages/publish_diary_page.dart` | ③ | +71：发表后自动 AI 回应 + AI 建议 |
| `widgets/publish_diary_preview.dart` | ④-M | 发布预览 |
| `widgets/publish_panel/publish_tag_row.dart` | ② | 三态部分选中 |
| `widgets/publish_panel/publish_mood_energy_sections.dart` | ① | SaltSwitch |
| `widgets/publish_panel/publish_resolvable_field.dart`、`publish_tag_search_bar.dart` | ③ | 各 +2 行接 `appTextContextMenuBuilder` |
| `pages/simple_composer_page.dart` | ③ 新增（391 行） | 简洁编辑器 |
| `controllers/simple_composer_controller.dart` | ③ 新增（252 行） | 简洁编辑器控制器 |
| `widgets/simple_composer_image_grid.dart` | ③ 新增 | 简洁编辑器图片格 |

**牵连**：写同一张 `diaries` 表（`metadata.simpleComposer: true`，`new_diary_draft.dart` ③加标记字段）、与富文本草稿同表、编辑入口经 `diary_edit_entry_flow.dart` 分流（简洁/完整选择）。

### 2.9 样式模型（样式编辑器 v5–v8 的数据层，设置页在 §2.11）

| 文件 | 类 | 说明 |
|---|---|---|
| `models/diary_preview_style/*`（5 文件） | ① | `diary_preview_page_style.dart` 删 `seedColor`/`paperLight…` 改 `colorIntensity`/`tintPaper`；`diary_preview_title_style.dart` 删 `colorLight/Dark` 改 `divider`/`bodyGap`；`diary_preview_style_enums.dart` 加 `DiaryPreviewColorIntensity`；`diary_preview_presets.dart` 心情预设加 `tintPaper`；`diary_preview_style_limits.dart` 加 `titleBodyGap` 范围 |
| `viewmodels/diary_preview_resolved_style.dart` | ① | 心情色板/强度/纸面染色 |
| `viewmodels/diary_text_appearance.dart` | ① | 正文字体显式 `HarmonyOSSansSC`，与 UI 系统字体解耦 |
| `widgets/diary_typography_metrics_editor.dart` | ③ | 首行缩进滑块 |
| `widgets/diary_typography_preview.dart` | ④-M | Quill 控制器→AppFlowy 预览 |

**牵连**：设置页样式编辑器（`lib/ui/settings/sections/diary_preview_style/`）读写同一模型；旧存档的 `colorLight`/`Dark`、`seedColor` 等键读取时被丢弃。

### 2.10 设置首页及各子设置页

| 文件 | 类 | 说明 |
|---|---|---|
| `settings/pages/settings_page.dart` | ② | 377 行：两张分组大卡（界面组/内容组，组标题卡内蓝字）取代“一项一张卡摞满屏”；图标 FA→Material outlined；新增个人资料、AI 设置入口 |
| `settings/pages/appearance_language_page.dart` | ② | 新增“首页布局”分组 + 语言行 padding 4→2、字重 w600→w400 |
| `settings/sections/settings_theme_section.dart` | ① | 199 行：删调色板选择器，主题色锁 Salt 蓝 |
| `settings/sections/settings_editor_section.dart` | ③ | AI 写作不可用时工具栏隐藏 AI 项（`aiModuleAvailableProvider`），传 `aiAvailable` 给工具栏排序页 |
| `settings/pages/diary_toolbar_order_page.dart` | ③ | AI 项显隐与拖拽拼回逻辑 + 文本菜单 import（与上游 tip-diff 360 行，双方改法分叉大，见 §7） |
| `settings/pages/diary_typography_page.dart` | ① | 仅两处 padding/字阶微调 |
| `settings/pages/app_features_page.dart` | ② | 结构重组：新增桌面/时间线开关，纪念日从“日历下嵌套 Reveal”改平级，新增日记留言（`comments`）、AI 助手（`ai`）、侧滑归档（`swipeArchive`，仅手机）三行；删 `settings_reveal.dart` 嵌套 |
| `settings/pages/profile_page.dart` + `settings/controllers/profile_page_controller.dart` | ③ 新增（265 行） | 昵称/简介/头像/封面（FilePicker→私有目录→设置键落盘→删旧文件） |
| `settings/pages/mood_options_page.dart` + `settings/models/mood_palette.dart`（③，新增 227 行）+ `settings/widgets/mood_color_picker.dart`（③，新增 151 行） | ③ | 心情符号+颜色自定义，存单 JSON 键 `app.settings.mood_palette`，旧 `mood_options` 键只迁移读一次 |
| `settings/pages/tag_management_page.dart` | ① | 列表整体装进分组白卡、SaltSwitch、图标 FA→Material |
| `settings/pages/data_management_page.dart` | ① | 仅行首图标 16→20、深色、行距 4→2 |
| `settings/pages/data_privacy_page.dart` | ① | 同上 + `SwitchListTile`→`ListTile`+`SaltSwitch` |
| `settings/pages/cloud_backup_page.dart` | ① | 图标 16→20 + 自动备份时多一行上次结果 |
| `settings/pages/cloud_backup_target_page.dart` | ③ | 增量备份入口、`List<CloudBackupEntry>`→`CloudBackupListing`、配置表单收进分组白卡 |
| `settings/pages/about_page.dart` | ① | `Divider`→`SettingsCardGroupDivider`、`_SectionCard` 去阴影描边改纯白扁平卡、行首图标 18→20 深色 + 新增“更新日志”入口 |
| `settings/pages/changelog_page.dart` + `settings/models/changelog_entry.dart` + `changelog_entries.dart` + `changelog_entries_legacy.dart` | ③ 新增 | 手写双语条目 + 展开/收起卡片（与上游平行实现，见 §7） |
| `settings/widgets/release_notes_view.dart` | ④ | 与上游逐字节相同（§6.1） |

**牵连**：设置首页改分组结构要同步改全部子页入口；功能管理页改开关即改底栏 Tab 列表（`home/models/home_tab.dart`、`home_page_controller.dart`、`home_page.dart`）；心情色板格式改动要同步日历聚合、探索趋势、预览页配色三处消费方；云备份页牵连 controllers 全套（§6.1，实为上游代码）+ `home_page.dart`（自动调度在首页启动）。

### 2.11 样式编辑器 4 页（卡片 / 预览 / 代码块 / 导航栏）——牵连中心

| 文件 | 类 | 说明 |
|---|---|---|
| `settings/widgets/style_editor/style_editor_scaffold.dart` | ② | 787 行（+644/−143）：v5–v8 阅读软件式重建——默认只看全屏预览、点空白处才呼出顶栏/底栏；顶部悬浮 32 白圆按钮、底部 48 高直角满宽 tab（图标在上文字在下）、设置面板矮面板≤屏幕 30%、字号×0.85。新增 `tabIcons` 参数。**4 个样式页全部依赖它，改外壳即改 4 页** |
| `settings/widgets/style_editor/style_editor_common.dart` | ② | 456 行（+424/−32）：新增 `StylePillGroup`（药丸分段）、`StyleSliderRow`（带步进按钮的滑杆行）、`StyleEditorMergedTab`（合并 tab）、`StyleEditorFirstGroupScope`/`StyleEditorEmbeddedScope`（面板内首组贴顶/紧凑模式）。**全部样式 tab 页的控件都走这里；同时 `settings_card_group.dart` 读它的 EmbeddedScope 做面板内紧凑模式——样式编辑器与全站设置卡是双向牵连** |
| `settings/widgets/style_editor/style_preset_list.dart` | ③ 新增（43 行） | 药丸组（Salt 蓝底白字选中态），`StylePresetOption` 砍掉 `icon`/`description` 字段，取代上游 `style_preset_grid.dart`（fork 已删） |
| `settings/widgets/style_editor/style_library_tab.dart` | ① | 仅小改 |
| `settings/widgets/settings_card_group.dart` | ② | 样式编辑器面板与全站设置页的共用底座 |
| `settings/widgets/settings_option_tiles.dart` | ① | SaltSwitch + w400 |
| `diary_card_style_page.dart` + 11 个 section（`color`/`content`/`cover`/`date`/`layout`/`order`/`presets`/`text`/`texture_tab`/`labels`/`preview`） | ② 为主，section 多为 ① | tab 从 8 个合并为大类 + `tabIcons`；section 多为控件换皮（`SettingsSliderTile`→`StyleSliderRow`、`ExpressiveIconChoiceRow`→`StylePillGroup`）；`labels.dart` 加 memo/暖阳预设名、封面 `bottom` 位置、色源 `custom`→`warm`；`preview.dart` 预览工具条重写为药丸组 |
| `diary_preview_style_page.dart` + 8 个 section（`body`/`cover`/`labels`/`meta`/`page`/`paging`/`preview`/`title`） | ② 为主，section 全 ① | tab 合并 + `tabIcons`；`page_tab` 删自定义色种子分支、`title_tab` 滑杆/分段换药丸、`labels.dart` 删 `custom` 种子/纸张、新增着色强度三档 |
| `diary_code_block_style_page.dart` + 4 个 section（`display`/`font`/`theme_tab`/`preview`） | ②（页）/ ①（section）/ ③（`preview.dart`） | 页仅加 `tabIcons` + 亮度按钮参数简化；`preview.dart`（fork 145 / tip 185）：Quill 预览控制器→AppFlowy `Document`，fork 自家改法与上游分叉 |
| `home_bar_style_page.dart` + 7 个 section（`common`/`floating`/`items`/`labels`/`material`/`outline`/`preview_toolbar`） | ②（页）/ ①（section） | `tabIcons` + 材质/悬浮 tab 合并为 `StyleEditorMergedTab`；section 删自定义 tint/线色分支、按钮组换药丸 |

**已删（fork 删除，上游 tip 仍保留）**：`style_color_dialog.dart`（262 行）、`style_custom_color_tile.dart`（90 行）——自定义取色入口被砍（与暖阳 `warm` 色源取代 `custom` 呼应）；`style_preset_grid.dart`（148 行）——被 `style_preset_list.dart` 取代。合上游时这三处会冲突：上游仍在用它们，fork 的 labels/common 已不再引用。

**牵连**：卡片样式页牵连范围外 `diaries/models/diary_card_style/*`（暖阳/备忘预设本体）；预览样式页牵连范围外预览样式模型；导航栏样式页牵连 `home/models/home_bar_style/*`（①，模型层删 custom 字段、默认 `topBarHairline` false→true、`barHeight` 64→60、指示器色改 `primaryContainer`）。

### 2.12 首页（合并 v4）

| 文件 | 类 | 说明 |
|---|---|---|
| `home/pages/desktop_page.dart` | ③ 新增（494 行） | 题头（日期+问候+总览数）→写点什么→快捷入口 6 格（2 行 3 格：时间线/相册/日历/标签/那年今日/情绪趋势）→最近记录 3 条；四区块顺序/显隐可配（`DesktopLayout`）；数据复用探索页 `ExplorePageController` + `exploreDiariesProvider`。牵连中心 |
| `home/sections/desktop_header.dart`（③，109 行）、`desktop_recent.dart`（③，200 行）、`desktop_tiles.dart`（③，181 行）、`desktop_write_button.dart`（③）、`home/widgets/desktop_card.dart`（③，38 行） | ③ | 四个区块的拆分实现 |
| `home/models/desktop_layout/desktop_layout.dart`（③，187 行）+ `desktop_layout_code.dart`（③，26 行）+ `home/providers/desktop_layout_provider.dart`（③，42 行） | ③ | 单 JSON 键 `desktopLayoutRaw` 持久化 + 同步 Notifier（防首帧闪烁） |
| `home/pages/home_page.dart` | ② | 底栏 5→3（桌面/日记/设置；日历/探索并进桌面，时间线新增）、`HomeTab.desktop`/`timeline`、Tab 请求改为 `(int, HomeTab)`、冷启动挂 `CloudBackupAutoScheduler` |
| `home/models/home_tab.dart`（②，30 行）、`home/controllers/home_page_controller.dart`（②，38 行）、`home/providers/home_tab_request_provider.dart`（②，28 行） | ② | 底栏 Tab 定义、跨页切 Tab 请求、返回键行为；与 `notebook_navigation.dart`（④）绑定 |
| `home/pages/home_page_chrome.dart`（①，13 行）、`home/widgets/home_bar/home_create_fab.dart`（③，新增） | ①/③ | FAB 长文案胶囊→浅紫圆角方钮+深紫铅笔图标 |
| `home/widgets/home_bar/home_floating_bar.dart`（①，5 行）、`home_nav_destination.dart`（①，6 行） | ① | 仅微调 |
| `home/models/home_bar_style/*`（6 文件） | ① | 见 §2.11 末尾 |

### 2.13 笔记本页

**嵌套 cluster（③，全部 fork-only，10 个文件互相牵连，不能单独改/单独回滚）**：

| 文件 | 说明 |
|---|---|
| `notebooks/models/notebook_tree.dart`（③，新增 87 行） | 防环/子孙/祖先纯数据结构 |
| `notebooks/controllers/notebook_editor_controller.dart`（③） | +`parentId` 字段，智能本恒 null |
| `notebooks/sections/notebook_editor_parent.dart`（③） | fork 版父本选择器（与上游平行实现，见 §7） |
| `notebooks/pages/notebook_contents_page.dart`（③） | 面包屑 `NotebookBreadcrumb` + 子本列表 |
| `notebooks/sections/notebook_contents_nesting.dart`（③，新增 154 行） | 嵌套内容区 |
| `notebooks/models/notebook_scope_resolver.dart`（③） | +`descendantIds` |
| `notebooks/providers/home_notebook_scope_provider.dart`（③） | 首页本子范围 |
| `notebooks/providers/notebook_providers.dart`（③） | 父本篇数含后代 + 新增 `unfiledDiaryCountProvider` |
| `notebooks/sections/notebook_shelf_sheet.dart`（③，54 行） | 书架新增“未收录”行 |

其余 ①（各 2–10 行）：`notebooks_page.dart`（FA plus→Material add）、`notebook_add_diaries_page.dart`、`notebook_action_sheets.dart`、`notebook_chapter_dialogs.dart`、`notebook_editor_appearance`/`behavior`/`rules`、`notebook_quick_create_dialog.dart`、`notebook_rule_date_editor.dart`、`notebook_rule_sheets.dart`。`notebooks/controllers/notebook_navigation.dart` 是 ④（见 §6.2）。

### 2.14 探索页

| 文件 | 类 | 说明 |
|---|---|---|
| `explore/pages/explore_page.dart` | ② | **删除 316 行**：整页删除，功能并进首页；上游 tip 仍保留此页，合上游时是结构冲突点 |
| `explore/pages/explore_memory_page.dart` | ③ 新增 | 那年今日页（概况卡 + 那年今日 + AI 洞察卡组合） |
| `explore/pages/explore_insight_page.dart` | ③ 新增 | 情绪与精力趋势页（复用 `ExploreInsightCard`） |
| `explore/sections/explore_overview_card.dart` | ③ | fork 简化概况卡（与上游平行实现，见 §7） |
| `explore/sections/explore_ai_insight_card.dart` | ③ | fork 版 AI 卡（上游有自己的 AI 卡） |
| `explore/controllers/explore_writing_stats_builder.dart` | ③ 新增（49 行） | 概况卡三行聚合 |
| `explore/models/explore_view_data.dart` | ③ | +`ExploreWritingStats` |
| `explore/pages/explore_media_gallery_page.dart`（③，fork 475 / tip 578）+ `gallery_filter_bar.dart`（③，245 行）+ `gallery_layout_sheet.dart`（③，216 行）+ `gallery_media_tile.dart`（③） | ③ | 画廊 v2（年/月/日分组、列数持久化、分类筛选、音频/视频） |
| `explore/controllers/explore_content_extractor.dart`（③，135 行）+ `explore_media_gallery_controller.dart`（③，33 行）+ `explore_page_controller.dart`（③）+ `explore/providers/explore_providers.dart`（③） | ③ | 媒体从“仅图片”扩展到图片/音频/视频（`ExploreMediaSource` typed 元组） |
| `explore/widgets/explore_shared_widgets.dart` | ① | 共用卡片/标题样式重刷 |
| 删除且上游也删（④，§6.1）：`explore_content_section.dart`、`explore_media_gallery_card.dart`、`explore_stats_card.dart`、`explore_tag_cloud_card.dart` | ④ | 删除动作本身不是 fork 定制 |

### 2.15 模板页 / 日历页 / 纪念日

| 文件 | 类 | 说明 |
|---|---|---|
| `diary_templates/controllers/diary_template_editor_controller.dart` | ③ | fork 仅 27 行——Quill→AppFlowy 主干是上游已合代码，fork 只剩事务流订阅 + `diaryBlocksToQuillOps` 转换 |
| `diary_templates/sections/diary_template_editor_content_tab.dart` | ③ | AppFlowy 编辑器 + 变量插入 + 工具栏高度预算（与上游分叉，见 §7） |
| `diary_templates/models/diary_template_variables.dart` | ③ | 时间变量带格式 `{{时间:HH:mm}}`，全角冒号兼容 |
| `diary_templates/viewmodels/diary_template_variable_values.dart` | ③ | `formatDiaryTemplateMoment` 图案校验（tip-diff 仅 3 行，见 §6.2） |
| `diary_templates/widgets/diary_template_variable_bar.dart` | ③ | 12 小时制格式行 + `_VariableTile` 抽取 |
| `diary_templates/sections/diary_template_auto_apply_groups.dart`、`diary_template_editor_settings_tab.dart`、`diary_templates_settings_group.dart`、`widgets/diary_template_search_field.dart`、`diary_template_tags_field.dart` | ① | 图标/SaltSwitch/文本菜单等小改 |
| `diary_templates/viewmodels/diary_template_labels.dart` | ④ | 与上游逐字节相同（§6.1） |
| `calendar/controllers/calendar_page_controller.dart` + `calendar/pages/calendar_page.dart` | ③ | 上下滑 300px/s 切月/年视图（成对，不能单改） |
| `calendar/calendar_day_actions_sheet.dart`、`calendar_day_heading.dart`、`calendar_header.dart`、`calendar_options_controls.dart` | ① | 图标/字重/开关换皮 |
| `anniversaries/anniversary_edit_page.dart`、`anniversary_diary_picker.dart` | ① | 各 3–4 行小改 |

### 2.16 AI 助手（`lib/ui/ai/` 60 文件全新增 + `lib/core/services/ai/` 15 文件全新增）

| 分组 | 文件数 | 说明 |
|---|---|---|
| `lib/ui/ai/pages/` | 15 | AI 聊天/设置/人设/回顾等页面 |
| `lib/ui/ai/controllers/` | 12 | 其中 9 个与上游逐字节相同（§6.1） |
| `lib/ui/ai/viewmodels/` | 9 | 其中 7 个与上游逐字节相同（§6.1） |
| `lib/ui/ai/sections/` | 8 | 含 `ai_replies_section.dart`（读留言 provider，§2.7） |
| `lib/ui/ai/models/` | 8 | 其中 5 个与上游逐字节相同（§6.1） |
| `lib/ui/ai/widgets/` | 6 | 其中 4 个与上游逐字节相同（§6.1） |
| `lib/ui/ai/providers/` | 2 | 其中 1 个与上游逐字节相同（§6.1） |
| `lib/core/services/ai/` | 15 | 客户端/预设/用量等，**全部 15 个与上游逐字节相同**（§6.1） |
| 数据库 | 3 表 | `ai_conversations`、`ai_messages`、`ai_results`（见 §4） |

**注意**：AI 大文件与上游差异大，不可单文件改回——`ai_chat_page.dart`（391 行差）、`ai_model_sheets.dart`（396 行差）、`ai_page_scaffold.dart`（154 行差）：fork 是“无背景系统/无 @链接/无 app_modal”的适配版（自带 `AiPageArea`、`_readingWidth` shim、直接推 `DiaryPreviewPage`），上游用 `AppPageBackground`/`AppGlassField`/`showAppModalBottomSheet`/`openDiaryLinkTarget`。单文件改回需先合入 `app_surface` + `diary_link_target` + `app_modal` 整套基础设施（见 §7）。

**牵连**：`hardDeleteDiary` 联动删 AI 回应（`diary_writes.dart`）；备份（完整备份随行、日记包不带）；AI 上限 fork 低于上游（`maxPersonas` 20 vs 上游 50、`maxCustomActions` 30 vs 50，见 §7）。

### 2.17 备份与核心服务（`lib/core/services/` 63 文件）

| 分组 | 文件数 | 说明 |
|---|---|---|
| `services/ai/` | 15 | 见 §2.16，全部与上游逐字节相同 |
| `services/cloud_backup*` | 24 | 网盘 7 目标 + 增量 12 + 服务/模型/配置 5；其中增量 8 个与上游逐字节相同（§6.1），10 个修改文件含 `cloud_backup_service.dart`（与上游仅 3 行差，见 §6.2） |
| `services/` 根目录其他 | 24 | `backup_*` 6、`journal_import_*` 3、`day_photo_*` 2、`app_*` 3、`settings_service*` 2、`data_archive`、`diary_camera`、`diary_media_storage`、`diary_typography`、`http_cancel_token`、`profile_avatar`/`cover`、`text_process_actions` |
| 新增 fork-only 服务 | — | `cloud_backup_media_index.dart`（219 行，网盘备份内重写的媒体索引，见 §6.2）、`profile_avatar_storage_service.dart`、`profile_cover_storage_service.dart`（各 65 行，个人资料头像/封面存储） |

**牵连与缺口**：`BackupPayload` 有 `diaryComments` 但**无 `dayMoods`**；`backup_merge.dart` 里 `diaryComments`/`dayMoods` 出现 0 次——合并模式会静默丢弃载荷里的留言与心情（只有完整恢复 `writeDatabase` 会写留言）。上游有 `_prepareDiaryComments` / `_mergeDayMoods` / 计数回填。**这是已知旧缺口，合 v0.12.0（#154 留言图片）时顺带修**（见 §7）。另：`settings_service.dart`（+226/−23）新增画廊列数/分组、个人资料、心情色板、桌面布局、`aiPrefsRaw` 等设置键；`backup_settings.dart` 同步新增上述键的导出/恢复（+72 行）。

### 2.18 数据库（`lib/core/database/` 35 文件）

根目录 25 个（schema/ops/迁移/编解码，新增 8、修改 17）+ `diary_blocks/` 10 个（块文档 9 + `diary_list_style`，全新增）。变迁表见 §4。

**共用表（改动会牵连的功能）**：
- `diaries`：几乎全部功能（列表/搜索/探索/日历/归档/导出/备份/同步口径/私密排除）。牵连点：`diary_scope_sql.dart`（私密递归 CTE + `DiaryUnfiledScope`）、`diary_list_queries.dart`（时间轴）、`diary_writes.dart`（`hardDeleteDiary` 删 AI 回应）、`diary_queries.dart`（`getDiaryImageSourceRefs`）。
- `notebooks` + `parent_id`：嵌套树、私密递归（子孙本继承私密）、未收录、书架、备份合并（`_repairDanglingParents`）、智能本。`diary_notebooks` 关联表同理。
- `diary_comments`：预览页留言区、卡片角标计数、备份（见 §2.17 缺口）、上游还有探索回看/搜索命中（fork 无）。
- `day_moods`：日历长按心情、探索统计/年视图着色；备份缺口（§2.17）。
- `ai_*`：AI 聊天/回顾/读后回应、备份、`hardDeleteDiary` 联动删除。

### 2.19 应用外壳 / 主题 / 配置

| 文件 | 类 | 说明 |
|---|---|---|
| `lib/app/node_diary_app.dart` | ③ | 应用装配 |
| `lib/app/theme/`（6 文件：`theme`、`theme_color_schemes`、`expressive_controls`/`surfaces`、`app_effects`、`app_radii`） | ① | Salt 蓝 `#0470E6`、底 `#FAFBFC`、卡片纯白、圆角收小（`app_radii` card 16 vs 上游 24） |
| `lib/l10n/app_en.arb`、`app_zh.arb` + 生成文件 ×3 | — | ARB 3108 条（上游约 3950 条；fork 独有 187 键，多为桌面/更新日志） |
| `pubspec.yaml` | — | 版本 0.10.0+22；依赖：`provider ^6.1.5` 新增、AppFlowy 编辑器 git 版 + `keyboard_height_plugin` override；仍用 `flutter_quill`（PDF/导入/编解码桥接）；`archive ^3.6.1` / `xml ^6.6.1` / `drift ^2.32.0`（上游已是 `archive ^4.6.0` / `xml ^7.0.1` / `drift ^2.35.3`，见 §7） |
| `android/`（6 文件） | ③ 为主 | `DiaryCameraCapture.kt` + `diary_camera_paths.xml`（与上游逐字节相同）+ 相机权限（fork 独有）；`AndroidManifest` 上游多 LAN 组播/扫码权限，fork 多相机权限与相册 `PICK` intent；`MainActivity.kt` 上游多预测返回与 LAN 通道，fork 多相机通道 |
| `DESIGN.md`、`AGENTS.md` | — | 文档（fork 改动记录） |
| `.github/workflows/build-apk.yml` | ③ | fork 签名构建（68 行，上游另有 `ci.yml`/`release-apk.yml`/`download-stats.yml`） |

## 3. 能一起改的分组

下面每组内的文件改动时可以放同一批、一起测试；组与组之间没有直接牵连，可以分开做。

| 组 | 内容 | 涉及文件（核心） |
|---|---|---|
| A. Salt 主题皮 | 只换颜色/间距/字号/图标，不改逻辑。77 个文件 tip-diff ≤ 30 行，都是薄薄一层 Salt 皮盖在上游底子上 | `lib/app/theme/*`、`lib/ui/widgets/salt_switch.dart`、各页 ① 文件（图标 16→20、开关换 SaltSwitch、字重 w500→w400、padding 收紧） |
| B. 样式编辑器外壳 + 控件 | 外壳、共用控件、预设列表三件套一起改 | `style_editor_scaffold.dart`、`style_editor_common.dart`、`style_preset_list.dart`（§5.1） |
| C. 样式编辑器 4 个页 | 卡片/预览/代码块/导航栏各页的 tab 与 section（共用 B 的组件） | §2.11 各页（改一页的 tab 不影响其他页，但改 B 会影响全部） |
| D. 首页桌面四区块 | 题头/写点什么/快捷入口/最近记录 + 桌面布局模型 | `desktop_page.dart`、`desktop_header.dart`、`desktop_recent.dart`、`desktop_tiles.dart`、`desktop_write_button.dart`、`desktop_layout/*`、`desktop_layout_provider.dart` |
| E. 笔记本嵌套 cluster | 10 个文件一体（§2.13） | `notebook_tree.dart`、`notebook_editor_controller.dart`、`notebook_editor_parent.dart`、`notebook_contents_page.dart`、`notebook_contents_nesting.dart`、`notebook_scope_resolver.dart`、`home_notebook_scope_provider.dart`、`notebook_providers.dart`、`notebook_shelf_sheet.dart` |
| F. 时间线 Moments 页 | 整页 + 条目组件 + 个人资料 provider | `timeline_page.dart`、`diary_timeline/*`、`diary_profile_provider.dart`、`diary_timeline_entry_menu_sheet.dart` |
| G. AI 助手 | UI 全套 + 服务 + 三张表（但大文件与上游分叉，见 §2.16 注意） | `lib/ui/ai/*`、`lib/core/services/ai/*`、`app_database_ai_*` |
| H. 增量备份 | 增量扫描/打包/状态 + 媒体索引 + 备份服务 | `cloud_backup_incremental*.dart`、`cloud_backup_media_index.dart`、`cloud_backup_service_incremental.dart`、`backup_archive_io.dart` |
| I. 日记卡片渲染 | 卡片组件 + 样式模型 + 预设（改一处影响列表/搜索/归档/日历四处，见 §5.10） | `widgets/diary_card/*`、`models/diary_card_style/*`、`diary_card_appearance.dart` 等 |
| J. 简洁编辑器 | 简洁编辑器三件套 + 编辑入口分流 | `simple_composer_page.dart`、`simple_composer_controller.dart`、`simple_composer_image_grid.dart`、`diary_edit_entry_flow.dart` |
| K. 这天照片视频 | 预览页 + 控制器 + 贴条/面板 | `diary_day_photo_preview_page.dart`、`diary_day_photos_controller.dart`、`diary_day_photos/*` |
| L. 模板变量与时间格式 | 变量解析 + 取值 + 变量栏 | `diary_template_variables.dart`、`diary_template_variable_values.dart`、`diary_template_variable_bar.dart` |
| M. 日历月/年视图 | 控制器 + 页面成对 | `calendar_page_controller.dart`、`calendar_page.dart` |
| N. 选区菜单（本体是上游代码，别碰） | 消费方每处只加一行 `contextMenuBuilder`；本体 6 个文件与上游逐字节相同 | `lib/ui/widgets/text_selection_menu/*`（§6.1） |
| O. 快速滚动条（本体是上游代码，别碰） | 消费方只复用 `FastScroller`；本体 5 个文件与上游逐字节相同 | `lib/ui/widgets/fast_scroller/*`（§6.1） |

## 4. 数据库变迁（fork v14→v17；上游已到 v18）

**版本错位是最大坑**：fork 与上游的 v14/v16 含义互换，v15 相同，v17 相同，fork 缺 v18。

| 版本 | fork | 上游 | 表 / 列 | 负责文件 |
|---|---|---|---|---|
| v14 | **日记留言** | 这天的心情 | fork：新建 `diary_comments`（`comment_id` unique、`diary_id` 业务 id、`content` 1–2000 字、`created_at`、`updated_at`；索引 `idx_diary_comments_diary_id`） | `app_database_diary_comment_schema.dart`、`app_database_diary_comment_ops.dart`、`app_database_migrations.dart::_migrateAddDiaryComments`、`app_database.dart` 注册 |
| v15 | `notebooks.parent_id` | 同 fork | `notebooks` 加可空 TEXT 列，存父本业务 id；新建/更新/删除/合并时维护嵌套与防环 | `app_database_notebook_schema.dart`、`app_database_notebook_ops.dart`（`_requireNestableParent`）、`_migrateAddNotebookParent` |
| v16 | **这天的心情** | 日记留言 | 新建 `day_moods`（`day` TEXT 主键 `YYYY-MM-DD`、`mood` 枚举名、`updated_at`；无业务 id、无索引） | `app_database_day_mood_schema.dart`、`app_database_day_mood_ops.dart`、`_migrateAddDayMoods`（按表存在性判断，不依赖 `from`，注释已写明错位） |
| v17 | AI 三表 | 同 fork | 新建 `ai_conversations`（`conversation_id`、`persona_id`、`scope` JSON、`pinned`；索引 `idx_ai_conversations_updated`）、`ai_messages`（`message_id`、`conversation_id`、`role`、`content`、`reasoning`、`citations` JSON、`meta` JSON、`status`；索引 `idx_ai_messages_conversation`）、`ai_results`（`result_id`、`kind`、`diary_id` 业务 id；索引 `idx_ai_results_diary`、`idx_ai_results_kind`） | `app_database_ai_schema.dart`、`app_database_ai_ops.dart`、`app_database_ai_context_ops.dart`、`_migrateAddAiTables` |
| v18 | **fork 没有** | 留言加图片 | 上游：`diary_comments` 加 `images`（可空，托管图片 JSON 数组）+ `mood`（emoji 原文）+ `editedAt`（替代 fork 的 `updatedAt`）；`_migrateDiaryCommentsAddImages`；另有 `diary_comment_images.dart` 编解码 | fork 缺失；若合 v0.12.0（#154）需补迁移 + 改 `DiaryComments` 表定义 + 改 ops（编辑/图片/心情） |

迁移总入口：`app_database.dart`（`schemaVersion` fork 17 vs 上游 18；`onUpgrade` 里 `from < 14/15/16/17` 四个分支）+ `app_database_migrations.dart`。生成文件 `app_database.g.dart`（fork vs 上游约 1400 行差，主因表定义与 v18 差异）随 schema 重跑生成即可。

**注意**：`_migrateAddNotebookParent` 的迁移函数可与上游对齐（上游 `_migrateNotebooksAddParent` 用 `migrator.addColumn`，fork 用原生 `ALTER TABLE` + `PRAGMA table_info` 查列），但 `if (from < N)` 的版本门必须按 fork 已有用户库的实际版本链保留，**不可无脑改回**（见 §6.2 第 8 项）。

## 5. 牵连总图（不能单独改的节点）

1. **样式编辑器外壳 + 共用控件**：`style_editor_scaffold.dart` + `style_editor_common.dart` —— 4 个样式页 + 全部样式 tab + `style_preset_list.dart` + `settings_card_group.dart`（面板紧凑模式）。动一处，4 页 + 全站设置卡联动。
2. **设置卡片组 + Salt 开关**：`settings_card_group.dart`（②）——设置首页、全部子设置页、笔记本编辑器各 section、云备份目标页、标签页、心情页都在用；改卡片留白/标题样式 = 全站联动。`salt_switch.dart`（③，`lib/ui/widgets/salt_switch.dart`）——设置开关、数据与隐私、云备份表单、模板设置组、日历选项、编辑/发布/搜索页都在用；换外观即全站开关变。
3. **底栏 Tab 四件套**：`home_tab.dart` + `home_tab_request_provider.dart` + `home_page_controller.dart` + `home_page.dart` ——底栏 Tab 定义、跨页切 Tab 请求（桌面快捷入口、笔记本跳转、预览页日记本胶囊）、返回键行为；与 `notebook_navigation.dart`（④）绑定。
4. **日记页快速滚动条链路**：`diaries_fast_scroller.dart` → `FastScroller`（`lib/ui/widgets/fast_scroller/`）→ `diary_timeline_index.dart` → `diary_timeline_provider.dart`（`watchDiaryTimeline`）→ `pagedDiariesProvider`。位置一律按“第几篇”换算；替换 `pagedDiariesProvider` 且会滚动长列表的测试须同时替换 `diaryTimelineProvider`，不打开真实数据库。
5. **桌面布局读写两端**：`desktop_layout` 模型 + provider + `desktop_page.dart` + `desktop_layout_page.dart` ——首页区块顺序/显隐的读写两端。
6. **探索页轻量日记流**：`explore_page_controller.dart` + `explore_view_data.dart` + `explore_providers.dart` ——桌面题头统计、最近记录、那年今日页、洞察页、画廊页、笔记本篇数统计共用同一套轻量日记流与媒体来源。
7. **笔记本嵌套 cluster**：见 §3 组 E，10 文件一体。
8. **云备份链路**：云备份 controllers（④×5，实为上游代码）+ `cloud_backup_target_page.dart` + `home_page.dart`（自动调度）——增量备份链路；改 `cloud_backup_controller.dart` 等于改上游已合代码，合上游时应直接取上游版。
9. **选区菜单 / 快滚条本体（上游代码）**：`text_selection_menu/*`（④，上游代码）+ `fast_scroller/*`（④，上游代码）——范围内的文件只是消费方（每处加一行 `contextMenuBuilder` 或复用 `FastScroller`）；本体别碰，合上游直接取上游版。
10. **日记卡片渲染器**：`DiariesListSection` 是 `DiaryCard` 唯一调用方，日记页/搜索页/归档页/日历都经它渲染；样式模型同时被设置页样式编辑器读写。改卡片即改四处。
11. **块文档 schema**：`core/database/diary_blocks/diary_blocks_schema.dart` ——范围内 29 个文件引用：编辑器各控制器、导出、mention/link 卡片、toolbar、预览、toggle/callout 等。改 schema 即全链路联动。
12. **留言表**：`diary_comments` ——预览留言区、卡片角标、搜索页、导出、AI 回应区共用（见 §2.7）。

## 6. 疑似冗余清单（只列清单，不动手改回）

结论先行：**严格口径下（vs 合并基，逻辑全同、只换写法/换名/挪位）真正能直接改回原版的文件很少**。三个分片的判定汇总如下，分四档，收益最大的在前。

### 6.1 第一档：已与上游逐字节相同（96 个文件）——改回 = 不用改，已是上游版

逐文件 `git diff upstream/main HEAD -- <文件>` 行数为 0。这些是 fork 当初改造着合进来的 v0.10.0/v0.11.0 功能、后来被上游原样收编的。**整理时可直接划掉；未来合上游时这 96 个文件零工作量。**

| 分组 | 文件（举例，完整清单见下） | 数量 |
|---|---|---|
| `lib/core/services/ai/` | 15 个客户端/预设/用量等，全部 | 15 |
| `lib/ui/ai/` | controllers 9 + viewmodels 7 + models 5 + widgets 4 + pages 1 + providers 1 | 27 |
| `lib/core/services/cloud_backup*` | 增量 8 个（`cloud_backup_incremental*.dart`） | 8 |
| `lib/core/database/` | AI/心情 schema+ops、batch_writes 等 | 5 |
| `lib/core/database/diary_blocks/` | 5 个 | 5 |
| `lib/core/services/` 修改后相同 | `backup_zip_writer.dart`、`cloud_backup_aliyun/baidu/dropbox/google_drive/onedrive`、`cloud_backup_models.dart`、`cloud_backup_settings_service.dart`、`cloud_backup_target.dart`、`cloud_backup_webdav.dart` | 10 |
| `android/` | 相机 `DiaryCameraCapture.kt` + `diary_camera_paths.xml` | 2 |
| `lib/core/services/` | `diary_camera_capture_service.dart` | 1 |
| `lib/ui/settings/controllers/` | `cloud_backup_auto_scheduler.dart`、`cloud_backup_busy.dart`、`cloud_backup_controller.dart`、`cloud_backup_failure.dart`、`cloud_backup_incremental_flows.dart` | 5 |
| `lib/ui/settings/sections/` | `cloud_backup_incremental_section.dart` | 1 |
| `lib/ui/settings/widgets/` | `cloud_backup_labels.dart`、`cloud_backup_state_builder.dart`、`release_notes_view.dart` | 3 |
| `lib/ui/widgets/fast_scroller/` | 全套 5 个：`fast_scroller.dart`、`fast_scroller_geometry.dart`、`fast_scroller_overlay.dart`、`fast_scroller_parts.dart`、`fast_scroller_seek.dart` | 5 |
| `lib/ui/widgets/text_selection_menu/` | 全套 6 个：`app_text_context_menu.dart`、`app_text_context_menu_panel.dart`、`app_text_menu_action.dart`、`app_text_selection_layout.dart`、`app_text_selection_toolbar.dart`、`app_text_toolbar_buttons.dart` | 6 |
| `lib/ui/widgets/` | `desktop_horizontal_scroll.dart`、`select_all_button.dart` | 2 |
| `lib/ui/diary_templates/viewmodels/` | `diary_template_labels.dart` | 1 |
| **合计** | | **96** |

> 迷惑性案例：`cloud_backup_controller.dart` 相对合并基有 176 行 diff（`_run`/`_runResult`/`_progress`/`CloudBackupHost` 被抽成 mixin 并改名 `_host`→`host`、`_service()`→`service()`），但那是**上游自己的重构**，fork 只是原样合进来了。不要误判为 fork 改动。

**收益**：未来合上游时这 96 文件零工作量；清单可直接划掉。**风险**：无。唯一注意：`cloud_backup_*` 目标文件相同，说明 fork 当初的改动已被上游原样采纳。

另外 4 个文件是“上游也删了”（fork 与上游 tip 都没有，删除动作本身不是 fork 定制）：`explore/sections/explore_content_section.dart`、`explore_media_gallery_card.dart`、`explore_stats_card.dart`、`explore_tag_cloud_card.dart`。只有 `explore_page.dart` 上游 tip 还保留（fork 删了，见 §2.14）。

### 6.2 第二档：近等价小文件（与上游只差几行）——可对齐，收益小、风险低

| # | 文件 / 函数 | 与上游的差异 | 改回收益 | 风险 |
|---|---|---|---|---|
| 1 | `lib/core/database/app_database_tag_ops.dart`（约 182 行新增 vs 合并基） | 仅 3 行：注释里上游多一句“局域网同步的标签分面也由这张表现算” | 取上游版即得最新注释与 LAN 口径 | 无逻辑风险 |
| 2 | `lib/core/services/cloud_backup_service.dart` | 仅 3 行：上游用 `appDataRootDirectory`（`app_data_directory.dart`），fork 用 `getApplicationDocumentsDirectory` | 与上游同源，少一个分叉点 | fork **没有** `app_data_directory.dart`，单文件改回会编译失败，需连带取该文件（及 `heif_image_converter.dart` 等，见 §7） |
| 3 | `lib/core/database/file_embed_codec.dart` | 仅 5 行：fork 多一段注释（说明旧版提取已迁往 `diary_blocks_media.dart`） | 几乎为零，仅注释统一 | 无 |
| 4 | `lib/core/database/notebook_rules.dart` | 仅 7 行：注释措辞差（“紧凑 Delta” vs “紧凑块文档”） | 仅注释 | 无 |
| 5 | `lib/core/services/cloud_backup_s3.dart` | 7 行：`findAllElements('Contents', namespace: '*')` vs 上游 `namespaceUri: '*'` | 跟上 `xml` 新 API | fork `pubspec.yaml` 是 `xml: ^6.6.1`，上游 `^7.0.1`；单改文件不升级依赖会编译失败 |
| 6 | `lib/core/services/backup_archive_io.dart`（`encodeEntries` 及 `extract`） | 19 行：fork 用 archive 3.x 写法，上游用 archive 4.x | 逻辑等价，跟上 archive 大版本 | fork `archive: ^3.6.1`，上游 `^4.6.0`；需同步升级依赖并跑备份测试 |
| 7 | `lib/ui/diary_templates/viewmodels/diary_template_variable_values.dart` | tip-diff 仅 3 行：`_values` 的 12 项 map 构造与原版逐行相同，只是挪进构造器参数并多存 `_now`/`_locale`；新增只有 `valueOf(variable, format)` + `formatDiaryTemplateMoment`（时间格式功能） | 删包装、调用方改走 typed 版 | 低，但调用方含日记本统计页 |
| 8 | `lib/core/database/app_database_migrations.dart`：`_migrateAddNotebookParent` | fork 原生 `ALTER TABLE notebooks ADD COLUMN parent_id` + `PRAGMA table_info('notebooks')` 查列；上游 `_migrateNotebooksAddParent` 用 `migrator.addColumn(notebooks, notebooks.parentId)`，同样先查列存在性 | 与上游同名同实现，未来 diff 消失 | **中**：不可无脑改回——版本号错位（见 §4）：fork v14=留言、v15=parent、v16=心情；上游 v14=心情、v15=parent、v16=留言。迁移函数可对齐，但 `if (from < N)` 的版本门必须按 fork 已有用户库的实际版本链保留 |
| 9 | `lib/core/services/cloud_backup_media_index.dart`（219 行）vs 上游 `lan_sync/sync/sync_media_index.dart`（152 行）+ `sync_media_refs.dart` + `sync_state_files.dart` | fork 文件头注释自述：“上游这套逻辑原本放在局域网同步里……本 fork 不做局域网同步，这里按同一规格在网盘备份模块内重写一份”；增量扫描/打包/状态三处 fork 用 `CloudBackupMediaIndex`/`cloudBackupSha256OfFile`，上游用 `SyncMediaIndex`/`syncSha256OfFile` | 若合入 lan_sync，可删 fork 版、改用 `SyncMediaIndex`，少一份重复实现 | **中**：fork 已删 `lan_sync/`（用户决定），短期无替代；且需核对两边 `media_index.json.gz` 的键/格式是否真一致（注释称同一规格，未实测比对文件内容） |
| 10 | `lib/core/database/app_database_diary_comment_schema.dart` / `..._ops.dart` vs 上游 `app_database_comment_schema.dart` / `..._ops.dart` | 仅**文件名**对应（fork 多 `diary_` 前缀），内容不等价：上游表多 `mood`、`images`（v18）、`editedAt`，索引为 `(diary_id, created_at)`；fork 只有 `content`/`created_at`/`updated_at`，索引仅 `diary_id`；ops 上游多编辑/恢复/跨日记回看/搜索，fork 只有读写+计数 | 改名对齐可减少未来 diff | **不可直接改回**：这是 fork 旧版 → 上游新版的升级，不是等价替换；`updatedAt` vs `editedAt` 语义不同，见 §4 |
| 11 | `lib/ui/notebooks/controllers/notebook_navigation.dart` | fork-diff 5 行，tip-diff 11 行：`homeDiariesTabRequestProvider`→`homeTabRequestProvider`、`tabs.request()`→`tabs.request(HomeTab.diaries)` | 合上游时可直接取上游版 | 它与 fork 的 `HomeTab` 重构绑定，不能单独改回，必须连 `home_tab.dart`、`home_tab_request_provider.dart`、`home_page.dart` 一起动 |

### 6.3 第三档：抽取拆分与注释（体量极小，改回收益几乎为零）

| 文件 | 证据 | 改回收益 / 风险 |
|---|---|---|
| `controllers/tag_create_flow.dart`（新增 41 行）+ `controllers/diary_meta_actions.dart`（+9/−15） | 原版 `DiaryMetaActions.createTag` 内联实现，fork 抽成共用文件（发布/编辑页标签子页与多选标签面板共用）；`diary_meta_actions.dart` 现只剩 `runCreateTagFlow(...)` 调用 | 改回合回即删新文件、恢复内联，收益：上游合并不用再管一个文件；风险：低，但两个调用方会重新各写一份 |
| `controllers/diary_preview_navigation.dart`（新增 14 行） | 无原版对应（原版预览页内联 `Navigator.push`）；薄 helper，供预览页/翻页器/反向链接共用 | 严格说是 ③ 的小 helper，不建议动 |
| `controllers/archived_diaries_controller.dart:153` | diff 仅 1 行注释：`Dismissible 已播放离场动画` → `侧滑组件已播完滑出与收起`；逻辑 0 行 | 收益：无（纯文字）。风险：无 |
| `pages/diary_drafts_page.dart:56` | 同上，1 行注释 | 同上 |
| `models/diary_card_style/diary_card_style_json.dart:14-18` | 删 4 行未使用的 `_argb` / `_hex` 辅助函数 | 收益：无（删的是死代码，改回等于加回死代码）。风险：无 |

**反例（不是冗余，别改回）**：`controllers/diaries_notebook_membership_controller.dart:124` 与 `diaries_notebook_scope_controller.dart` 的 `_selectedDiaryIds.clear` → `_state._resetSelection`，但 `_resetSelection` 还做 `_selectionKeptOpen=false` + `_selectAll.cancelPending()`，且上游根本没有 `_resetSelection` / `_selectionKeptOpen` / `DiariesSelectAllController`。这是新功能（全选常驻多选）的接线，不是重命名。

### 6.4 第四档：迁移适配（50 个文件，逻辑等价但**不可单独改回**）

判定标准：diff 中同时出现 `flutter_quill` 删除 + `appflowy_editor` 新增，且文件头或注释写明“逻辑不变/规则不变/语义一致”。全部在 `lib/ui/diaries/` 内：

- **代码块**：`controllers/diary_code_block_editing.dart`（`onReplaceText` 钩子 → `handleDiaryCodeBlockEnter`）、`models/diary_code_block/diary_code_block_newline.dart`（头注“规则本身不变”，`Delta` 计划 → `Transaction` 计划）、`viewmodels/diary_code_span_builder.dart`（头注“语义不变”，`textSpanBuilder` → `textSpanDecorator`）、`controllers/diary_code_language_tracker.dart`（头注“逻辑不变”，`Block` 键 → `Node` 键）、`viewmodels/diary_code_block_look.dart`、`viewmodels/diary_quill_styles.dart`（删代码块钩子与 `tracker` 字段，`DiaryQuillStylesBuilder` 从 Stateful 降为 ConsumerWidget，`controller`/`scrollController` 标 `@Deprecated` 保留；仍被 PDF 导出与未迁移页面使用，**不可删**）、`widgets/diary_code_block/diary_code_block_chrome.dart` + `diary_code_block_header_geometry.dart` + `diary_code_block/diary_code_block_panel.dart` + `diary_toolbar_code_block_button.dart` + 删除 `render_diary_code_block_chrome.dart`（421 行 Quill `RenderObject` 层）与 `diary_code_block_header_gestures.dart`（101 行 Quill 手势）。
- **颜色/时间/插入**：`models/diary_text_colors.dart`、`models/diary_toolbar_time_format.dart`、`models/image_insertion.dart`、`models/media_insertion.dart`、`models/recording_insertion.dart`、`models/diary_image_embed_data.dart`、`models/diary_playback_gestures.dart`。
- **编辑器壳**：`controllers/diary_caret_follow_controller.dart`、`controllers/diary_todo_autosave_controller.dart`、`controllers/edit_diary_controller.dart`、`controllers/edit_diary_recording_controller.dart`、`controllers/edit_diary_template_flow.dart`、`controllers/diary_image_embed_actions.dart`。
- **渲染器/工具栏**：`widgets/diary_preview/diary_appflowy_preview.dart`（新增 1387 行，替代 Quill 预览）、`widgets/diary_preview/diary_preview_body.dart`、`widgets/diary_preview/diary_preview_view.dart`、`widgets/publish_diary_preview.dart`、`widgets/diary_typography_preview.dart`、`widgets/diary_mobile_toolbar.dart`、`widgets/diary_floating_toolbar.dart`、`diary_floating_toolbar_bar.dart`、`diary_floating_toolbar_code.dart`、`widgets/diary_toolbar_more_button.dart`、`widgets/diary_toolbar_panel_reserve.dart`、`widgets/diary_playback_interaction_guard.dart`、`widgets/diary_image_embed_builder.dart`、`diary_video_embed_builder.dart`、`diary_audio_embed_builder.dart`、`diary_attachment_embed_builder.dart`、`diary_divider_embed_builder.dart`、`widgets/diary_color_panel/diary_color_panel.dart`、`diary_color_custom_picker.dart`、`diary_toolbar_color_button.dart`、`widgets/diary_image_options_menu.dart`。
- **导出**：`export/diary_export_pdf.dart`（`flutter_quill_to_pdf` 插件 → 自研渲染器）、`export/diary_export_pdf_appflowy.dart`（新增 643 行）、删除 `export/diary_export_pdf_heading.dart`（75 行，标题逻辑并入新渲染器）、`export/diary_export_pdf_inline.dart`（`DiaryPdfInlineSource` 整类删除，插件适配层不再需要）。

**改回收益/风险（适用于全部 50 个）**：收益为零——上游原版是 Quill 实现，fork 的编辑器/预览/导出已整体迁到 AppFlowy，单文件改回即编译失败（类型 `QuillController`/`Block`/`Delta` 在调用方已不存在）。只有在“整个 AppFlowy 迁移回滚”时才有意义，那不在本次任务范围。真正能降低未来合流成本的只有 §6.1 的 96 个已相同文件和 §6.2–6.3 的小项。

**明确不等价、不可改回的（抽查结论，防误判）**：`content_codec.dart`（fork Delta 路线 vs 上游 AppFlowy Document 路线，270 行差）、`legacy_content_codec.dart`（117 行差）、`diary_blocks_codec.dart`（97 行差：上游多表格/标注/折叠/链接卡片处理 + `diary_blocks_table.dart`，fork 无此文件）、`diary_blocks_schema.dart`（101 行差：上游多 `callout`/`toggle_list`/`table`/`link_card`）、`diary_list_scope.dart`（89 行差：上游 `subNotebookIds`/`subPredicates` + `UnfiledScope`，fork `descendantIds`/`effectiveIds`，同功能不同设计）、`app_platform.dart`（fork 37 行最小版 vs 上游 122 行完整版，fork 是子集）、`settings_service.dart`（399 行差）、`app_features.dart`（102 行差）、`journal_import_html/markdown.dart`（218/186 行差：上游 `JournalBlockWriter` + 表格/链接处理，fork `JournalDeltaWriter`）、`diary_typography.dart`（55 行差）、`app_database_notebook_ops.dart`（152 行差）、`ai_chat_page.dart`/`ai_model_sheets.dart`/`ai_page_scaffold.dart`（见 §2.16）。

## 7. Fork 落后上游的清单（反向差异：不是 fork 冗余，是 fork 缺东西；合 v0.12.0 时需补）

- **备份缺口（已确认，见 §2.17）**：`BackupPayload` 有 `diaryComments` 但无 `dayMoods`；`backup_merge.dart` 合并模式丢留言与心情。合 v0.12.0（#154）时顺带修，可参照上游 `_prepareDiaryComments` 的写法，但注意 fork 留言表无 `mood`/`images`，需先定是否同步升 v18。
- **留言 v18**：见 §4（`mood`/`images`/`editedAt` + 索引改名 + `diary_comment_images.dart`）。
- **日记链接体系**：上游 `diary_blocks/diary_link_target.dart`、`diary_blocks_table.dart`、`app_database_diary_link_ops.dart`、`app_database_notebook_tree_ops.dart`，fork 全无（AI 页因此用直接推预览页的降级写法）。
- **数据目录与 HEIF**：上游 `app_data_directory.dart`、`heif_image_converter.dart`、`heif_media_repair_service.dart`；fork 无。影响：`cloud_backup_service.dart`、`diary_media_storage_service.dart`（上游导入图片时 HEIC/HEIF/AVIF 转 JPEG）、`data_archive_service.dart`、`app_database.dart`、`app_service.dart`。
- **依赖大版本**：fork `archive ^3.6.1` / `xml ^6.6.1` / `drift ^2.32.0` / 仍用 `flutter_quill` + `appflowy_editor` git 版 + `keyboard_height_plugin` override；上游 `archive ^4.6.0` / `xml ^7.0.1` / `drift ^2.35.3` / 已弃 Quill、AppFlowy 编辑器走 git main 固定提交、`provider ^6.1.5`。另上游新增 LAN 同步依赖（`cryptography`、`qr`、`mobile_scanner`、`pasteboard`、`dart_quill_delta`、`desktop_drop`）——LAN 同步是 fork **已删**的目录，用户决定不做，勿误合。
- **应用锁与主题系统**：上游 l10n 多约 1029 个消息键（fork 3108 vs 上游约 3950；fork 独有 187 键），集中在应用锁（`appLock*` 约 40 键）、`appSurface*`、桌面拖放等；`MainActivity.kt` 上游多预测返回与 LAN 通道；`theme.dart` 上游 `buildSeededAppTheme(seedColor, brightness)` + `MaterialThemeSchemes.withNeutralSurfaces`，fork 为 Salt 静态方案。
- **其他上游已演进、fork 旧版**：`diary_writes.updateDiary` 上游返回 `Future<DateTime>`、fork `Future<void>`；`diary_list_queries` 上游支持留言搜索（`matchComments`），fork 无；`app_features` 默认值差异（上游 `anniversaries` 默认 true、`comments` true；fork 旧默认值）；AI 上限 fork 低（`maxPersonas` 20 vs 上游 50、`maxCustomActions` 30 vs 50、About Me 1000 vs `kAiPromptTextMaxLength`）。

### 7.1 平行实现（不是冗余，是冲突警告——合上游时必须人工二选一，不能直接取任一版）

| fork 文件 | fork 实现 | 上游实现 |
|---|---|---|
| `explore/sections/explore_overview_card.dart`（fork 193 行新增 / tip-diff 186） | 简化概况卡（顶部三数 + 三行统计，热力图/节奏/内容卡已下线） | “指标网格数据看板”（`ExploreModuleConfig` + 最多 9 指标） |
| `explore/sections/explore_ai_insight_card.dart`（fork 193 / tip 104） | fork 的 AI 卡 | 上游有自己的 AI 卡，另一套实现 |
| `notebooks/sections/notebook_editor_parent.dart`（fork 新增 / tip 227） | 自写 `NotebookTree` + 底部面板，只手动本、无路径显示 | `notebookTreeProvider` + `notebook_parent_picker_sheet.dart`，支持智能本、显示完整路径“旅行 › 2025”、最多三层 |
| `settings/models/changelog_entry.dart`（fork 31 / tip 91）与 `settings/pages/changelog_page.dart`（fork 154 / tip 239） | 手写 `highlightsZh/highlightsEn/detailsZh/detailsEn` 双语字段 + `changelog_entries.dart` / `changelog_entries_legacy.dart` 手写条目 | 基于 `BundledReleaseNotes`/`release_notes_catalog` 自动拆要点 |
| `diary_templates/sections/diary_template_editor_content_tab.dart`（fork 297 / tip 294）、`settings/sections/settings_theme_section.dart`（fork 199 / tip 221）、`settings/pages/diary_toolbar_order_page.dart`（fork 250 / tip 360） | fork 自家改法 | 上游改法分叉大 |

另：**128/188 个 settings 片区文件上游在合并基之后也改过**，只有 60 个文件上游未动。以后合上游时，128 个是冲突高发区；60 个上游未动的（含全部 `desktop_*`、`notebook_tree`、`mood_palette`、`profile` 相关、`salt_switch`、`style_preset_list` 等）是纯 fork 增量，最安全。

## 8. 维护约定（以后每次改动顺手更新这份文档）

1. **改动先查清单**：改一个页面/功能前，先看 §2 对应行的“牵连”列，牵连的页面要一起回归；改 §5 里的牵连节点前，先评估联动范围。
2. **改完更新文档**：改了一个页面的文件，就把 §2 对应行改对（文件增删、分类变化）；新增了功能，在 §2 对应表里加一行、在 §3 里决定进哪个组；从上游合进来的东西，把 §6.1/§6.2 对应行划掉或改成“已与上游一致”；删了文件，在对应行标注“已删”。
3. **分类口径不变**：① 只改外观、② 改结构、③ 新功能、④ 逻辑等价。混合文件按主导性质归一类，正文注明次要性质。
4. **冗余只列不擅自改**：§6 的项目改回原版前要用户点头；§6.4（迁移适配）与 §7.1（平行实现）不要单文件硬改。
5. **版本号与数据库**：`pubspec.yaml` 版本与 §4 的数据库版本表同步更新；`if (from < N)` 的版本门按 fork 已有用户库的实际版本链保留（§4 的错位不要“顺手修掉”）。
6. **定期复核**：每次合上游大版本后，重新跑一次 `git diff upstream/main...HEAD --stat` 与逐文件 tip-diff，更新 §1 的数字与 §6.1 的“已相同”清单（只会越来越多）。

---

*初版：2026-11-07，基线 HEAD `36cbf65e`（样式编辑器 v5–v8），合并基 `b6959397`。下次更新时把这行改成新的 HEAD 与日期。*
