import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 时间线个人资料头像文件存储服务（对照 DiaryCoverStorageService）。
///
/// 约束：
/// - 只管理应用私有目录下的头像文件；
/// - 删除操作仅作用于本服务生成的文件，避免误删用户原始图片；
/// - 头像文件不随备份导出，恢复后路径指向的文件缺失时展示层回退为首字头像。
class ProfileAvatarStorageService {
  const ProfileAvatarStorageService._();

  static const String _avatarsDirectoryName = 'profile_avatar';

  static Future<String> importAvatar(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException('头像源文件不存在');
    }

    final avatarsDirectory = await _ensureAvatarsDirectory();
    final extension = p.extension(sourcePath);
    final targetName =
        'avatar_${DateTime.now().microsecondsSinceEpoch}'
        '${extension.isEmpty ? '.jpg' : extension}';
    final targetPath = p.join(avatarsDirectory.path, targetName);

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  static Future<void> deleteManagedAvatar(String? path) async {
    final normalizedPath = path?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return;
    }
    if (!await isManagedAvatar(normalizedPath)) {
      return;
    }

    final file = File(normalizedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<bool> isManagedAvatar(String path) async {
    final avatarsDirectory = await _ensureAvatarsDirectory();
    final avatarsRoot = p.normalize(avatarsDirectory.path);
    return p.normalize(path).startsWith('$avatarsRoot${p.separator}');
  }

  static Future<Directory> _ensureAvatarsDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final avatarsDirectory = Directory(
      p.join(supportDirectory.path, _avatarsDirectoryName),
    );
    if (!await avatarsDirectory.exists()) {
      await avatarsDirectory.create(recursive: true);
    }
    return avatarsDirectory;
  }
}
