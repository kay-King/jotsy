import 'package:flutter/material.dart';

import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../app/theme/expressive_surfaces.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../../diaries/sections/diaries_list_section.dart';
import '../../../diaries/sections/diary_head_section.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../../controllers/diary_card_style_editor_controller.dart';

/// 卡片样式的实时预览：顶部工具条（[DiaryCardStylePreviewToolbar]）切换列表/
/// 瀑布流与预览明暗，下方用真实的 [DiariesListSection] 渲染示例日记，与日记
/// 列表看到的完全一致。窄屏时工具条由页面单独放在顶部（[showToolbar] 为
/// false），预览区随下方选项面板的拖动伸缩。
///
/// 预览可滚动；点按或长按示例卡片切换选中，便于查看选中态的描边与高亮。
/// 共享元素关闭（`enableCoverHero: false`），避免与真实列表的同名 Hero 冲突。
/// 明暗与应用当前主题相反时，用同一种子色另装配一份主题（按种子色缓存），
/// 减少动画时同样去掉控件动效，与应用外壳一致。
class DiaryCardStylePreview extends StatefulWidget {
  const DiaryCardStylePreview({
    super.key,
    required this.controller,
    required this.samples,
    required this.moodOptions,
    this.showToolbar = true,
    this.bottomPadding = 0,
  });

  final DiaryCardStyleEditorController controller;
  final List<DiaryWithTags> samples;
  final List<String> moodOptions;

  /// 是否在预览上方显示工具条。
  final bool showToolbar;

  /// 列表末尾额外留白：预览底部被面板圆角压住的部分，最后一张示例仍能完整
  /// 滚到可见处。
  final double bottomPadding;

  @override
  State<DiaryCardStylePreview> createState() => _DiaryCardStylePreviewState();
}

class _DiaryCardStylePreviewState extends State<DiaryCardStylePreview> {
  final Set<String> _selected = <String>{};

  void _toggle(String diaryId) {
    setState(() {
      if (!_selected.remove(diaryId)) {
        _selected.add(diaryId);
      }
    });
  }

  ThemeData _themeFor(
    ThemeData appTheme,
    Brightness brightness, {
    required bool reduceMotion,
  }) {
    if (brightness == appTheme.brightness) {
      return appTheme;
    }
    // 应用主题由种子色装配，主色就是种子色派生的；用设置里的种子色重建
    // 另一种明暗，与切换主题模式后看到的一致。缓存返回同一实例：卡片样式
    // 的解析结果以主题实例为键复用。
    return SeededThemeCache.of(
      Color(widget.controller.settingsService.themeSeedColorValue),
      brightness,
      reduceMotion: reduceMotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final appTheme = Theme.of(context);
    final brightness = controller.previewBrightness ?? appTheme.brightness;
    final previewTheme = _themeFor(
      appTheme,
      brightness,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showToolbar)
          DiaryCardStylePreviewToolbar(controller: controller),
        Expanded(
          child: Theme(
            data: previewTheme,
            child: Builder(
              builder: (BuildContext context) {
                final scheme = Theme.of(context).colorScheme;
                return ClipRect(
                  child: Material(
                    color: ExpressiveSurfaces.pageBackground(scheme),
                    child: CustomScrollView(
                      primary: false,
                      slivers: <Widget>[
                        const SliverToBoxAdapter(child: SizedBox(height: 10)),
                        DiariesListSection(
                          diaries: widget.samples,
                          layoutMode: controller.mode == DiaryCardMode.list
                              ? DiaryLayoutMode.list
                              : DiaryLayoutMode.waterfall,
                          selectedDiaryIds: _selected,
                          isSelectionMode: _selected.isNotEmpty,
                          maxVisibleTags: controller.tagLimit,
                          onCreate: () {},
                          onOpenEditor: (diary, _) =>
                              _toggle(diary.diary.diaryId),
                          onToggleSelection: (diaryId, _) => _toggle(diaryId),
                          cardStyle: controller.style,
                          moodOptions: widget.moodOptions,
                          enableCoverHero: false,
                          opensLockedCapsulePage: false,
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 12 + widget.bottomPadding),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 预览工具条：列表/瀑布流（同时决定“专属”分组编辑哪种布局）与预览明暗。
///
/// Salt 悬浮风：白底、无边框、轻微阴影；选中段 Salt 蓝底白字。分段复用
/// 共用的 [ExpressiveButtonGroup]（组件本身不动），外层包悬浮样式、选中
/// 色经 Theme 改写组件读到的色板。
class DiaryCardStylePreviewToolbar extends StatelessWidget {
  const DiaryCardStylePreviewToolbar({super.key, required this.controller});

  final DiaryCardStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    // Stack 居中：分段轨道贴工具条正中、明暗按钮贴右，两者互不挤。
    // 以前是 Row[Expanded(居中分段)， 月亮]：月亮占右边 32px，
    // 分段的居中基准是「工具条再减月亮」，整体向左偏约 16px。
    // 脚手架顶栏左右对称（菜单 + 间距 44、间距 + 设置 44），
    // 工具条正中就是屏幕正中。
    //
    // 分段轨道不撑满全宽：封顶 200（窄屏下由 LayoutBuilder 收紧），
    // 轨道右缘与明暗按钮之间至少留 12 的缝：聊天软件压缩后近白缝隙
    // （#FAFBFC 与纯白只差 5 个色阶）会被抹掉，间距要靠空间撑出来。
    // 封顶按工具条宽算：轨道右缘 = 正中 + 宽/2，明暗按钮左缘 =
    // 工具条宽 − 32，宽 ≤ 工具条宽 − 88 时缝 ≥ 12。
    // dense 模式按钮按内容定宽，内容超宽时由 FittedBox 整体缩小
    // （组件文档的既定做法），标签不省略、窄屏也不溢出。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        var maxCenterWidth = constraints.maxWidth - 88;
        if (maxCenterWidth > 200) maxCenterWidth = 200;
        if (maxCenterWidth < 0) maxCenterWidth = 0;
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxCenterWidth),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _modeSegments(context),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: StylePreviewBrightnessButton(controller: controller),
            ),
          ],
        );
      },
    );
  }

  /// 列表/瀑布流分段：白底圆角轨道 + 轻微阴影，选中段 Salt 蓝。不要加
  /// 描边：和圆按钮一样，白底 + 柔和阴影就够辨认边缘，描边会让顶栏
  /// 发灰、显小气。轨道用 [ExpressiveButtonGroup] 的 dense 模式
  /// （36 高）：顶栏里最显大的就是它，收矮后顶栏行高只剩 40；字号收一档。
  Widget _modeSegments(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: scheme.copyWith(
            // 轨道白底；选中片 Salt 蓝、选中字白。只影响这一棵子树。
            surfaceContainerHigh: Colors.white,
            surfaceContainerLowest: const Color(0xFF0470E6),
            onSurface: Colors.white,
          ),
        ),
        child: ExpressiveButtonGroup<DiaryCardMode>(
          dense: true,
          minSegmentWidth: 64,
          segments: <ButtonSegment<DiaryCardMode>>[
            // 只放文字：预览顶栏与明暗按钮同行，窄屏大字号下带图标
            // 的“Waterfall”会折行。
            ButtonSegment<DiaryCardMode>(
              value: DiaryCardMode.list,
              label: Text(l10n.autoT0146, style: const TextStyle(fontSize: 13)),
            ),
            ButtonSegment<DiaryCardMode>(
              value: DiaryCardMode.waterfall,
              label: Text(l10n.autoT0147, style: const TextStyle(fontSize: 13)),
            ),
          ],
          selected: <DiaryCardMode>{controller.mode},
          onSelectionChanged: (Set<DiaryCardMode> selection) =>
              controller.mode = selection.single,
        ),
      ),
    );
  }
}
