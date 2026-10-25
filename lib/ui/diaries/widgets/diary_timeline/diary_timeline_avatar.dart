import 'package:flutter/material.dart';

import '../../providers/diary_profile_provider.dart';
import '../../../widgets/expressive_image_frame.dart';

/// 时间线条目头像：朋友圈式圆角方块。
///
/// 有头像文件时显示照片；否则显示昵称首字（微信绿底白字，昵称未设置时
/// 为“我”，与 fakeWechat 的首字头像口径一致）。
class DiaryTimelineAvatar extends StatelessWidget {
  const DiaryTimelineAvatar({super.key, required this.profile, this.size = 40});

  final DiaryProfile profile;
  final double size;

  /// 时间线点缀色：微信绿（用户明确绿没问题，排斥的是 MD3 骨架）。
  static const Color accentGreen = Color(0xFF07C160);

  @override
  Widget build(BuildContext context) {
    final file = profile.avatarFile;
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          frameBuilder: expressiveImageFrameBuilder,
          errorBuilder: (context, error, stackTrace) => _charBlock(),
        ),
      );
    }
    return _charBlock();
  }

  Widget _charBlock() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        profile.avatarChar,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
