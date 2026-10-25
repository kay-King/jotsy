import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home_tab.dart';

/// 首页之外的页面（或首页内的桌面页）请求切到某个 Tab。
///
/// 状态是（请求序号，目标 Tab）：每次 [request] 序号加一，`HomePage` 监听到
/// 变化就切到目标 Tab；序号保证同一目标连续点两次也会触发（例如桌面 → 设置
/// → 桌面 → 设置）。只在内存里，不需要初始化，测试也无需替换。
///
/// 例子：预览页里点日记本胶囊——回到首页并在日记页打开那本（目标日记 Tab）。
class HomeTabRequestNotifier extends Notifier<(int, HomeTab)?> {
  @override
  (int, HomeTab)? build() => null;

  void request(HomeTab tab) {
    final id = (state?.$1 ?? 0) + 1;
    state = (id, tab);
  }
}

final homeTabRequestProvider =
    NotifierProvider<HomeTabRequestNotifier, (int, HomeTab)?>(
      HomeTabRequestNotifier.new,
    );
