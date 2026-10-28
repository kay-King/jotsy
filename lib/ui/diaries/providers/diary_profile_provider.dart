import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';

/// 时间线个人资料（昵称 + 头像路径 + 简介 + 封面路径）。
///
/// 展示层回退规则集中在这里，不由各处自行判断：
/// - 昵称空 → 显示“我”；
/// - 头像路径空、或指向的文件已不存在（备份恢复后文件未跟随）→ 首字头像；
/// - 简介空 → 时间线页不显示简介行；
/// - 封面路径空、或指向的文件已不存在 → 默认蓝色封面。
class DiaryProfile {
  const DiaryProfile({
    required this.nickname,
    required this.avatarPath,
    this.bio = '',
    this.coverPath,
  });

  /// 未设置时的默认昵称。
  static const String defaultNickname = '我';

  final String nickname;
  final String? avatarPath;

  /// 个人简介（空字符串表示未设置）。
  final String bio;

  /// 时间线页封面图路径（null 表示未设置）。
  final String? coverPath;

  String get displayNickname {
    final trimmed = nickname.trim();
    return trimmed.isEmpty ? defaultNickname : trimmed;
  }

  /// 展示用的简介：去首尾空白，空即未设置。
  String get displayBio => bio.trim();

  /// 首字头像用的字：昵称首个字符（按 rune 取，表情符号不取半个代理项），
  /// 昵称为空时为“我”。
  String get avatarChar {
    final display = displayNickname;
    return String.fromCharCode(display.runes.first);
  }

  /// 可展示的头像文件：路径非空且文件真实存在，否则为 null（首字头像）。
  File? get avatarFile {
    final path = avatarPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// 可展示的封面文件：路径非空且文件真实存在，否则为 null（默认蓝色封面）。
  File? get coverFile {
    final path = coverPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryProfile &&
      nickname == other.nickname &&
      avatarPath == other.avatarPath &&
      bio == other.bio &&
      coverPath == other.coverPath;

  @override
  int get hashCode => Object.hash(nickname, avatarPath, bio, coverPath);
}

/// 时间线个人资料 provider：监听设置服务的两个 notifier，变化时同步重建
/// （与 diaryCardStyleSettingsProvider 同一套“同步 Notifier + 监听去重”
/// 写法，避免 settings 未就绪首帧闪烁）。
final diaryProfileProvider =
    NotifierProvider<DiaryProfileNotifier, DiaryProfile>(
      DiaryProfileNotifier.new,
    );

class DiaryProfileNotifier extends Notifier<DiaryProfile> {
  @override
  DiaryProfile build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return const DiaryProfile(nickname: '', avatarPath: null);
    }
    final nicknameNotifier = settings.profileNicknameNotifier;
    final avatarPathNotifier = settings.profileAvatarPathNotifier;
    final bioNotifier = settings.profileBioNotifier;
    final coverPathNotifier = settings.profileCoverPathNotifier;
    void listener() {
      final next = DiaryProfile(
        nickname: nicknameNotifier.value,
        avatarPath: avatarPathNotifier.value,
        bio: bioNotifier.value,
        coverPath: coverPathNotifier.value,
      );
      if (next != state) {
        state = next;
      }
    }

    nicknameNotifier.addListener(listener);
    avatarPathNotifier.addListener(listener);
    bioNotifier.addListener(listener);
    coverPathNotifier.addListener(listener);
    ref.onDispose(() {
      nicknameNotifier.removeListener(listener);
      avatarPathNotifier.removeListener(listener);
      bioNotifier.removeListener(listener);
      coverPathNotifier.removeListener(listener);
    });
    return DiaryProfile(
      nickname: nicknameNotifier.value,
      avatarPath: avatarPathNotifier.value,
      bio: bioNotifier.value,
      coverPath: coverPathNotifier.value,
    );
  }
}
