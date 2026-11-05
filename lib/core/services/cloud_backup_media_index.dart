import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'diary_media_references.dart';

/// 网盘增量备份用的本机媒体索引与状态文件读写。
///
/// 上游这套逻辑原本放在局域网同步里（`SyncMediaIndex` /
/// `SyncStateFiles`，与局域网同步共用同一份媒体哈希缓存）；本 fork 不做
/// 局域网同步，这里按同一规格在网盘备份模块内重写一份，只服务增量备份：
/// - 媒体哈希缓存（`media_index.json.gz`）：媒体键 → 大小、修改时间、
///   sha256，大小与修改时间没变时不再重新计算；
/// - 状态文件（gzip JSON）：读写失败一律当作“没有”，丢了只会让下一次备份
///   重新计算或重新下载，不会丢数据。

/// 流式计算文件的 sha256（小写十六进制），不把文件整个读进内存。
Future<String> cloudBackupSha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// 日记媒体键（`diary_images/…` 等）在本机的绝对路径；键不合法时为 null。
///
/// 合法 = [diaryMediaKeyOf] 认它就是它自己：以托管目录名开头、后面还有
/// 文件名、不含 `..` 与第二个托管目录名。这同时挡住了目录穿越。
String? cloudBackupMediaPathFor(String dataRoot, String key) {
  if (key.contains('\\') || diaryMediaKeyOf(key) != key) return null;
  return p.joinAll(<String>[dataRoot, ...key.split('/')]);
}

/// 状态目录（`stateDir`）里 gzip JSON 文件的读写。
///
/// - 写：先写同目录下的临时文件（`<名>.tmp`），flush 后改名覆盖。同一文件
///   系统内的改名是原子的，写到一半断电 / 被杀也只会留下旧文件或临时文件，
///   不会留下半个 JSON；
/// - 读：文件不存在、解压失败、不是 JSON —— 一律当作“没有”，debugPrint 后
///   返回 null，从不抛出。
class CloudBackupStateFiles {
  const CloudBackupStateFiles(this.directory);

  final Directory directory;

  File fileOf(String name) => File(p.join(directory.path, name));

  /// 读出 [name] 的 JSON；不存在或损坏时为 null。
  Future<Object?> readJson(String name) async {
    final file = fileOf(name);
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return jsonDecode(utf8.decode(gzip.decode(bytes)));
    } catch (error) {
      debugPrint('cloud backup state file $name unreadable, discarded: $error');
      return null;
    }
  }

  /// 原子写入 [name]（gzip JSON）。
  Future<void> writeJson(String name, Object? json) async {
    await directory.create(recursive: true);
    final target = fileOf(name);
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(
      gzip.encode(utf8.encode(jsonEncode(json))),
      flush: true,
    );
    await temp.rename(target.path);
  }

  /// 删除 [name]（及可能残留的临时文件）；不存在时什么也不做。
  Future<void> delete(String name) async {
    for (final file in <File>[fileOf(name), File('${fileOf(name).path}.tmp')]) {
      if (await file.exists()) await file.delete();
    }
  }
}

/// 媒体索引（`media_index.json.gz`）：媒体键 → 大小、修改时间、sha256。
///
/// - 输入：要描述的媒体键（`diary_images/…`），文件在
///   `<dataRoot>/<键>`；
/// - 输出：每个存在的文件的 [CloudBackupMediaInfo]；
/// - 副作用：读写 `stateDir/media_index.json.gz`；只读媒体文件，从不改动。
///
/// sha256 一律流式计算，视频再大也不整个读进内存。大小与修改时间都没变时
/// 直接用索引里的哈希；任一变了就重算——托管媒体写入后通常不再改动，大多数
/// 会话里一次都不用重算。
///
/// 索引文件损坏时当作空，代价只是重新计算哈希。
class CloudBackupMediaIndex {
  CloudBackupMediaIndex({required Directory stateDir, required this.dataRoot})
    : _files = CloudBackupStateFiles(stateDir);

  static const String fileName = 'media_index.json.gz';
  static const int _version = 1;

  final Directory dataRoot;
  final CloudBackupStateFiles _files;

  Map<String, CloudBackupMediaInfo>? _entries;
  Future<void> _queue = Future<void>.value();

  /// 描述 [keys] 指向的文件；不存在的文件、不合法的键不出现在结果里，也从
  /// 索引里移除。有变化时写回索引文件。
  Future<Map<String, CloudBackupMediaInfo>> describeAll(Iterable<String> keys) {
    return _serialized(() async {
      final entries = await _load();
      final result = <String, CloudBackupMediaInfo>{};
      var changed = false;
      for (final key in keys.toSet()) {
        final path = cloudBackupMediaPathFor(dataRoot.path, key);
        final stat = path == null ? null : await File(path).stat();
        if (path == null || stat!.type != FileSystemEntityType.file) {
          changed |= entries.remove(key) != null;
          continue;
        }
        final modified = stat.modified.millisecondsSinceEpoch;
        final known = entries[key];
        if (known != null &&
            known.size == stat.size &&
            known.modifiedAt == modified) {
          result[key] = known;
          continue;
        }
        final info = CloudBackupMediaInfo(
          key: key,
          size: stat.size,
          modifiedAt: modified,
          sha256: await cloudBackupSha256OfFile(File(path)),
        );
        entries[key] = info;
        result[key] = info;
        changed = true;
      }
      if (changed) await _save(entries);
      return result;
    });
  }

  /// 描述单个键；文件不存在时为 null。
  Future<CloudBackupMediaInfo?> describe(String key) async =>
      (await describeAll(<String>[key]))[key];

  /// 只保留 [keys] 里的条目（例如当前仍被引用的媒体），其余从索引里移除。
  Future<void> retainOnly(Set<String> keys) {
    return _serialized(() async {
      final entries = await _load();
      final before = entries.length;
      entries.removeWhere((key, _) => !keys.contains(key));
      if (entries.length != before) await _save(entries);
    });
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, CloudBackupMediaInfo>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    final entries = <String, CloudBackupMediaInfo>{};
    final json = await _files.readJson(fileName);
    if (json is Map && json['v'] == _version && json['files'] is Map) {
      for (final entry in (json['files'] as Map).entries) {
        final info = CloudBackupMediaInfo._tryFromJson(entry.key, entry.value);
        if (info != null) entries[info.key] = info;
      }
    }
    return _entries = entries;
  }

  Future<void> _save(Map<String, CloudBackupMediaInfo> entries) =>
      _files.writeJson(fileName, <String, Object?>{
        'v': _version,
        'files': <String, Object?>{
          for (final info in entries.values) info.key: info._toJson(),
        },
      });
}

/// 一个媒体文件的大小（字节）、修改时间（UTC 毫秒）与 sha256（小写十六进制）。
@immutable
class CloudBackupMediaInfo {
  const CloudBackupMediaInfo({
    required this.key,
    required this.size,
    required this.modifiedAt,
    required this.sha256,
  });

  final String key;
  final int size;
  final int modifiedAt;
  final String sha256;

  static CloudBackupMediaInfo? _tryFromJson(Object? key, Object? json) {
    if (key is! String || json is! Map) return null;
    final size = json['s'];
    final modified = json['m'];
    final hash = json['h'];
    if (size is! int || modified is! int || hash is! String) return null;
    return CloudBackupMediaInfo(
      key: key,
      size: size,
      modifiedAt: modified,
      sha256: hash,
    );
  }

  Map<String, Object?> _toJson() => <String, Object?>{
    's': size,
    'm': modifiedAt,
    'h': sha256,
  };
}
