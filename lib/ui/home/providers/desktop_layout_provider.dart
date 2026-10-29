import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../models/desktop_layout/desktop_layout.dart';

/// 首页布局（四个区块的顺序 + 显隐）provider。
///
/// 与首页栏样式一样是同步 Notifier 而不是 `async*` StreamProvider：
/// StreamProvider 在 settings 就绪后的第一帧必然处于 loading，首页只能先用
/// 默认布局画一帧，随后再跳成用户布局——启动时首页区块会闪一下。这里
/// settings 未就绪时给默认值；就绪后 build 立即同步解码存储值，首页首帧
/// 读到的就是用户布局。
///
/// 设置页写入、备份恢复与失败回滚都会改写 raw notifier；监听它并按 `==`
/// 去重，相同布局不触发首页重建。
final desktopLayoutProvider =
    NotifierProvider<DesktopLayoutNotifier, DesktopLayout>(
      DesktopLayoutNotifier.new,
    );

class DesktopLayoutNotifier extends Notifier<DesktopLayout> {
  @override
  DesktopLayout build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return DesktopLayout.defaults;
    }
    final rawNotifier = settings.desktopLayoutRawNotifier;
    void listener() {
      final next = DesktopLayout.decode(rawNotifier.value);
      if (next != state) {
        state = next;
      }
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    // ref.watch 已订阅 settingsServiceProvider；settings 就绪后 build 会重跑，
    // 这里立即按当前 raw 解码一次，保证首帧就是用户布局。
    return DesktopLayout.decode(rawNotifier.value);
  }
}
