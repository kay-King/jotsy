import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/diary_media_storage_service.dart';
import '../../../core/services/profile_avatar_storage_service.dart';
import '../../../core/services/profile_cover_storage_service.dart';
import '../../diaries/providers/diary_profile_provider.dart';

/// 个人资料页的异步链路：昵称保存、头像更换/移除、简介保存、封面更换/移除。
///
/// 头像链路：相册选图 → 拷贝到私有目录 → 设置键落盘 → 旧头像（仅本服务
/// 管理的私有文件）删除。选图取消或导入失败时返回 false，不弹提示；
/// 相册原图只读不删，选图器的临时副本在 finally 里清理。封面链路与头像
/// 同口径（ProfileCoverStorageService）。
class ProfilePageController {
  ProfilePageController(this.ref);

  final WidgetRef ref;

  Future<void> saveNickname(String value) async {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return;
    }
    final trimmed = value.trim();
    final limited = trimmed.length > DiaryProfile.nicknameMaxLength
        ? trimmed.substring(0, DiaryProfile.nicknameMaxLength)
        : trimmed;
    await settings.setProfileNickname(limited);
  }

  Future<void> saveBio(String value) async {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return;
    }
    final trimmed = value.trim();
    final limited = trimmed.length > DiaryProfile.bioMaxLength
        ? trimmed.substring(0, DiaryProfile.bioMaxLength)
        : trimmed;
    await settings.setProfileBio(limited);
  }

  /// 换上新封面返回 true；取消或导入失败返回 false。
  Future<bool> pickCover() async {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return false;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null) {
      return false;
    }
    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      return false;
    }
    try {
      final newPath = await ProfileCoverStorageService.importCover(
        selectedPath,
      );
      final oldPath = settings.profileCoverPath;
      await settings.setProfileCoverPath(newPath);
      await ProfileCoverStorageService.deleteManagedCover(oldPath);
      return true;
    } catch (_) {
      return false;
    } finally {
      await DiaryMediaStorageService.discardPickerCopy(selectedPath);
    }
  }

  Future<void> removeCover() async {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return;
    }
    final oldPath = settings.profileCoverPath;
    await settings.setProfileCoverPath(null);
    await ProfileCoverStorageService.deleteManagedCover(oldPath);
  }

  /// 换上新头像返回 true；取消或导入失败返回 false。
  Future<bool> pickAvatar() async {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return false;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null) {
      return false;
    }
    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      return false;
    }
    try {
      final newPath = await ProfileAvatarStorageService.importAvatar(
        selectedPath,
      );
      final oldPath = settings.profileAvatarPath;
      await settings.setProfileAvatarPath(newPath);
      await ProfileAvatarStorageService.deleteManagedAvatar(oldPath);
      return true;
    } catch (_) {
      return false;
    } finally {
      await DiaryMediaStorageService.discardPickerCopy(selectedPath);
    }
  }

  Future<void> removeAvatar() async {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return;
    }
    final oldPath = settings.profileAvatarPath;
    await settings.setProfileAvatarPath(null);
    await ProfileAvatarStorageService.deleteManagedAvatar(oldPath);
  }
}
