import 'changelog_entries_legacy.dart';
import 'changelog_entry.dart';

/// 更新日志：按版本从新到旧排列。说明随应用打包，离线可看。
const List<ChangelogEntry> changelogEntries = <ChangelogEntry>[
  _v0100,
  _v090,
  ...changelogEntriesLegacy,
];

/// v0.10.0：心情色板 + 更新日志。
const ChangelogEntry _v0100 = ChangelogEntry(
  version: 'v0.10.0',
  highlightsZh: <String>[
    '心情色板：十种心情各有自己的颜色，可逐个修改',
    '预览页配色基调选"心情"时，整页按这篇日记的心情着色',
    '预览页新增"着色强度"（柔和 / 原色 / 鲜明）与"纸张随基调染色"',
    '设置 → 关于 → 更新日志：离线查看历次更新',
  ],
  highlightsEn: <String>[
    'Mood palette: each of the 10 moods has its own color, editable one by one',
    'Preview page tints the whole page with the diary\'s mood color when the color seed is "Mood"',
    'New preview options: color intensity (Soft / Original / Vivid) and tinting the paper with the seed',
    'Settings → About → Changelog: browse past updates offline',
  ],
  detailsZh: '''
## 心情色板

- 十种心情各有自己的颜色，从靛紫、蓝、青、绿一路暖到橙、珊瑚与玫红。
- 设置 → 编辑器设置 → 心情符号：每个心情左侧多了一个色块，点开即可换颜色；"重置"会同时恢复符号与颜色。
- 预览页配色基调选"心情"时，整页按这篇日记的心情着色；以前开心的几档和"跟随应用"看起来一样，现在每种心情都能看出区别。
- 预览页样式 → 页面 → 配色：新增"着色强度"（柔和 / 原色 / 鲜明，默认柔和）与"纸张随基调染色"开关。
- 预设"心情色"改为按心情着色并给纸张染色。
- 日历年视图与探索页心情图表的配色不变。
- 心情色板随完整备份导出。

## 更新日志

- 设置 → 关于 → 更新日志：按版本从新到旧列出历次更新，卡片显示版本要点，点"展开全部"查看完整内容。
- 说明随应用打包，没有网络也能看。
''',
  detailsEn: '''
## Mood palette

- Each of the 10 moods has its own color, from indigo, blue, cyan and green warming up to orange, coral and rose.
- Settings → Editor settings → Mood symbols: every mood now has a color swatch on its left; tap it to pick another color. "Reset" restores both symbols and colors.
- When the preview page color seed is "Mood", the whole page is tinted with that diary's mood color; every mood is now distinguishable, where the happier ones used to look the same as "Follow app".
- Preview style → Page → Colors: new "Color intensity" (Soft / Original / Vivid, Soft by default) and "Tint paper with seed" options.
- The "Mood colors" preset now tints by mood and tints the paper too.
- The year-view calendar and Explore mood charts keep their existing colors.
- The mood palette is included in full backups.

## Changelog

- Settings → About → Changelog: lists past updates from newest to oldest; each card shows the highlights, tap "Show all" for the full notes.
- The notes ship with the app, so they are readable offline.
''',
);

/// v0.9.0：桌面版、全新块编辑器、背景与材质、探索页重写、日记本嵌套等。
const ChangelogEntry _v090 = ChangelogEntry(
  version: 'v0.9.0',
  highlightsZh: <String>[
    '桌面版：Windows 与 Linux 首次提供安装包',
    '全新块编辑器：Markdown 快捷输入、/ 命令菜单、拖动段落',
    '背景与材质：全局或按页面设背景色、背景图与磨砂玻璃',
    '探索页重写：21 张卡片可排序、显隐、调宽度，内置 5 套布局',
    '日记本支持嵌套子本与自定义封面；新增日记留言、日历"这天的心情"',
  ],
  highlightsEn: <String>[
    'Desktop builds: installers for Windows and Linux for the first time',
    'Brand-new block editor: Markdown shortcuts, / command menu, drag paragraphs',
    'Backgrounds & materials: background colors, images and frosted glass per page or globally',
    'Explore rewrite: 21 cards sortable, hideable and resizable, with 5 built-in layouts',
    'Nested notebooks with custom covers; new diary comments and "day mood" on the calendar',
  ],
  detailsZh: '''
## 新增

- 桌面版：Windows 10 及以上（x64）提供安装程序与便携版，Linux（x64）提供压缩包与安装脚本；宽窗口下有侧边导航、日记列表与阅读双栏，支持右键菜单、键盘快捷键与拖入文件。
- 全新块编辑器：软键盘上也能用 Markdown 写法直接转换格式；`/` 命令弹出内联菜单；段落把手可上移、下移或长按拖动；列表可选多种编号与符号；工具栏可调大小；正文排版新增首行缩进。
- 背景与材质：可给全局或单个页面设背景颜色、背景图片；顶栏、工具栏、面板、对话框、卡片与小控件可分别换成磨砂玻璃。
- 探索页重写：21 张卡片任意排序、显隐、调宽度与选项；顶部按本周 / 本月 / 今年 / 全部统计；内置 5 套布局，也可存为"我的布局"。
- 日记本：支持最多三层的子日记本；自定义封面（5 种版式、4 种纹理）；书架新增"未收录"。
- 留言：给重读的日记写一段回应，可带心情，显示"写下后 N 天"。
- 这天的心情：在日历上长按某一天记下这天的心情，没写日记的日子也能记。
- 导入：支持榴莲日记与锤子便签。

## 说明

- 本版升级数据库并改用新的正文格式，升级后请不要降级回旧版本。
''',
  detailsEn: '''
## New

- Desktop builds: installers and portable builds for Windows 10+ (x64), archives with an install script for Linux (x64); side navigation and a list-plus-reader two-pane layout on wide windows, with context menus, keyboard shortcuts and drag-and-drop files.
- Brand-new block editor: Markdown shortcuts work from the soft keyboard; a `/` command opens an inline menu; paragraph handles move or drag-and-drop blocks; multiple list numbering and bullet styles; resizable toolbar; first-line indent for body text.
- Backgrounds & materials: background colors and images globally or per page; frosted glass for the top bar, toolbar, panels, dialogs, cards and small controls.
- Explore rewrite: 21 cards that can be reordered, hidden, resized and configured; week / month / year / all-time stats at the top; 5 built-in layouts plus "My layout".
- Notebooks: nested sub-notebooks up to three levels; custom covers (5 layouts, 4 textures); new "Unfiled" shelf.
- Comments: write a response to a diary you re-read, optionally with a mood, shown as "N days after writing".
- Day mood: long-press a calendar day to record how the day felt, even without a diary.
- Import: from Durian Diary and Smartisan Notes.

## Notes

- This version upgrades the database and switches to a new body format; do not downgrade afterwards.
''',
);
