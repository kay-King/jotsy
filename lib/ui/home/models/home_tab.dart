// 首页底栏的 Tab 身份。
//
// 职责：给每个 Tab 一个与位置无关的身份（文案、图标），并按功能管理开关
// 推出当前可见的 Tab 列表。桌面可在设置 → 功能管理中关闭，关闭后
// 后面的 Tab 下标会前移，所以首页一律按身份而不是下标判断“当前是哪一页”。
//
// 探索与日历已经并进桌面页（首页），不再占底栏 Tab；功能管理里也不再有
// 这两项开关。

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/app_features.dart';
import '../../../l10n/app_localizations.dart';

/// 首页 Tab。声明顺序就是底栏中的顺序。
enum HomeTab {
  desktop,
  diaries,
  settings;

  /// 底栏文案。
  String label(AppLocalizations l10n) => switch (this) {
    HomeTab.desktop => l10n.navDesktop,
    HomeTab.diaries => l10n.navDiaries,
    HomeTab.settings => l10n.navSettings,
  };

  /// 底栏图标。
  FaIconData get icon => switch (this) {
    HomeTab.desktop => FontAwesomeIcons.solidHouse,
    HomeTab.diaries => FontAwesomeIcons.solidRectangleList,
    HomeTab.settings => FontAwesomeIcons.gear,
  };
}

/// 按功能开关推出可见的 Tab（保持 [HomeTab] 的声明顺序）。
///
/// 日记与设置始终可见：日记是应用的主体，设置是重新打开功能的唯一入口；
/// 因此结果至少有两项，底栏始终是正常的导航行（不会落到单项兜底）。
List<HomeTab> visibleHomeTabs(AppFeatures features) => <HomeTab>[
  if (features.desktop) HomeTab.desktop,
  HomeTab.diaries,
  HomeTab.settings,
];
