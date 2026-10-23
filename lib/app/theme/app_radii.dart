/// Salt 风皮肤的容器圆角：卡片与对话框取 16 的柔和圆角（照 IdeaMemo
/// 的分组卡片），输入框略收；控件的按压/选中形态由 ExpressiveControls 管理。
class AppRadii {
  const AppRadii._();

  static const double card = 16;
  static const double nav = 12;
  // 弹窗比卡片再圆一档（Salt 弹窗观感），与底部弹层顶角 20 对齐。
  static const double dialog = 20;
  static const double input = 10;
}
