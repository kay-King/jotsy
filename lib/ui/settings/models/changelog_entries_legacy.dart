import 'changelog_entry.dart';

/// v0.8.x 及更早的更新记录。
const List<ChangelogEntry> changelogEntriesLegacy = <ChangelogEntry>[
  _v081,
  _v080,
];

/// v0.8.1：内置模板换新、草稿箱与回收站改版、导出更忠实。
const ChangelogEntry _v081 = ChangelogEntry(
  version: 'v0.8.1',
  highlightsZh: <String>[
    '内置模板换新：8 个内置模板全部重写，可直接编辑、删除与恢复默认',
    '草稿箱与回收站支持全选；回收站改版为卡片列表',
    '导出更忠实：PDF 保留正文标题的颜色与格式，Word 跟随排版设置',
  ],
  highlightsEn: <String>[
    'Built-in templates renewed: all 8 rewritten, editable, deletable and restorable',
    'Drafts and recycle bin support select-all; recycle bin redesigned as cards',
    'More faithful export: PDF keeps heading colors and formats, Word follows your typography',
  ],
  detailsZh: '''
## 新增

- 日记模板：8 个内置模板全部重写，小标题改成与正文同字号的彩色粗体；内置模板可以直接编辑、删除，改过的随时能恢复默认。
- 草稿箱与回收站：多选时支持全选；回收站改为卡片列表，显示正文摘要、封面与"日期 · 删除时间"，选中后在底部恢复或彻底删除。

## 修复

- PDF 导出的正文标题丢失文字颜色、背景色、粗细、下划线等格式与链接。
- Word 导出的正文没有跟随"正文字体与排版"里的字号、行距、字间距与段间距。

## 说明

- 本版不升级数据库。
''',
  detailsEn: '''
## New

- Diary templates: all 8 built-in templates rewritten with colorful bold subheadings in body size; built-in templates can be edited or deleted directly, and restored to defaults anytime.
- Drafts & recycle bin: select-all in multi-select; recycle bin redesigned as a card list showing excerpts, covers and "date · deleted time", with restore or delete-forever from the bottom bar.

## Fixed

- PDF export dropped heading text colors, backgrounds, weights, underlines and links.
- Word export ignored the font size, line height, letter and paragraph spacing from typography settings.

## Notes

- This version does not upgrade the database.
''',
);

/// v0.8.0：导航栏样式、代码块重做、颜色面板色系页与"我的颜色"。
const ChangelogEntry _v080 = ChangelogEntry(
  version: 'v0.8.0',
  highlightsZh: <String>[
    '导航栏样式：底栏可换成磨砂玻璃悬浮栏，内置 6 套预设',
    '代码块重做：10 套配色主题、22 种语言高亮、行号与一键复制',
    '颜色面板新增"色系"页与"我的颜色"',
    '导出保留文字颜色与代码高亮',
  ],
  highlightsEn: <String>[
    'Navigation bar styles: floating frosted-glass bar, 6 built-in presets',
    'Code blocks redone: 10 color themes, 22 languages highlighted, line numbers, one-tap copy',
    'Color panel gains a "Families" page and "My colors"',
    'Export keeps text colors and code highlighting',
  ],
  detailsZh: '''
## 新增

- 导航栏样式：设置 → 外观与语言 → 导航栏样式。预设有经典、玻璃、通透、浓雾、主题色、紧凑 6 套，也可以存为"我的样式"或用样式码分享。
- 代码块：10 套配色主题、22 种语言的语法高亮与自动识别、行号；顶部标题栏显示语言并可一键复制。
- 颜色面板：新增"色系"页（19 个 Material 色系的全部色阶）；"我的颜色"自动存下调出的颜色。
- 编辑器设置 → 工具栏与心情 → "始终显示工具栏"：连接实体键盘时也能设置格式。
- 导出：Word 与网页保留文字颜色和背景色；PDF、Word、网页里的代码块按代码块样式着色。

## 说明

- 本版不升级数据库。导航栏样式、代码块样式与我的颜色随完整备份导出。
''',
  detailsEn: '''
## New

- Navigation bar styles: Settings → Appearance → Navigation bar style. 6 presets (Classic, Glass, Clear, Haze, Theme, Compact), saveable as "My style" or shareable via style code.
- Code blocks: 10 color themes, syntax highlighting with auto-detect for 22 languages, line numbers; the header shows the language with one-tap copy.
- Color panel: new "Families" page (all shades of 19 Material color families); "My colors" automatically keeps colors you mix.
- Editor settings → Toolbar: "Always show toolbar" for physical keyboards.
- Export: Word and web keep text and background colors; code blocks in PDF, Word and web follow your code block style.

## Notes

- This version does not upgrade the database. Navigation bar style, code block style and my colors are included in full backups.
''',
);
