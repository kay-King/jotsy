import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 时间线页封面图文件存储服务（对照 ProfileAvatarStorageService）。
///
/// 约束：
/// - 只管理应用私有目录下的封面文件；
/// - 删除操作仅作用于本服务生成的文件，避免误删用户原始图片；
/// - 封面文件不随备份导出，恢复后路径指向的文件缺失时展示层回退为默认渐变封面。
class ProfileCoverStorageService {
  const ProfileCoverStorageService._();

  static const String _coversDirectoryName = 'profile_cover';

  static Future<String> importCover(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException('封面源文件不存在');
    }

    final coversDirectory = await _ensureCoversDirectory();
    final extension = p.extension(sourcePath);
    final targetName =
        'cover_${DateTime.now().microsecondsSinceEpoch}'
        '${extension.isEmpty ? '.jpg' : extension}';
    final targetPath = p.join(coversDirectory.path, targetName);

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  static Future<void> deleteManagedCover(String? path) async {
    final normalizedPath = path?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return;
    }
    if (!await isManagedCover(normalizedPath)) {
      return;
    }

    final file = File(normalizedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<bool> isManagedCover(String path) async {
    final coversDirectory = await _ensureCoversDirectory();
    final coversRoot = p.normalize(coversDirectory.path);
    return p.normalize(path).startsWith('$coversRoot${p.separator}');
  }

  static Future<Directory> _ensureCoversDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final coversDirectory = Directory(
      p.join(supportDirectory.path, _coversDirectoryName),
    );
    if (!await coversDirectory.exists()) {
      await coversDirectory.create(recursive: true);
    }
    return coversDirectory;
  }
}
