import 'audio_embed_codec.dart';
import 'file_embed_codec.dart';

/// 将旧版 AppFlowy 节点映射为 Quill Delta，保留图片、视频和附件引用。
/// 无文件 IO；实际恢复位置由备份服务处理。
List<Map<String, Object>> legacyDocumentToQuillDelta(
  Map<String, dynamic> rawDocument,
) {
  final ops = <Map<String, Object>>[];
  for (final node in _extractChildren(rawDocument)) {
    _appendAppFlowyNode(node, ops);
  }

  if (ops.isEmpty) {
    return <Map<String, Object>>[
      <String, Object>{'insert': '\n'},
    ];
  }

  final lastInsert = ops.last['insert'];
  if (lastInsert is! String || !lastInsert.endsWith('\n')) {
    ops.add(<String, Object>{'insert': '\n'});
  }
  return ops;
}

List<dynamic> _extractChildren(Map<String, dynamic> node) {
  final directChildren = node['children'];
  if (directChildren is List) {
    return directChildren;
  }
  final root = node['root'];
  if (root is Map<String, dynamic>) {
    final rootChildren = root['children'];
    if (rootChildren is List) {
      return rootChildren;
    }
  }
  return const <dynamic>[];
}

void _appendAppFlowyNode(dynamic rawNode, List<Map<String, Object>> ops) {
  if (rawNode is! Map<String, dynamic>) {
    return;
  }

  final type = rawNode['type'] as String?;
  if (type == 'video' || diaryFileEmbedTypes.contains(type)) {
    final attributes = rawNode['attributes'];
    final file = DiaryFileAttachment.tryDecode(attributes);
    if (file != null) {
      // 保留 width 等显示 metadata 与未知字段：tryDecode 只取 path/name/size，
      // 其余字段放到 op attributes（video）或直接透传（attachment），
      // 块转换时会并入块 data，rewrite 时原样保留。
      final extra = <String, Object>{};
      if (attributes is Map) {
        for (final entry in attributes.entries) {
          final key = entry.key;
          if (key is String &&
              !const {
                'url',
                'path',
                'name',
                'fileName',
                'size',
                'sizeBytes',
              }.contains(key)) {
            extra[key] = entry.value as Object;
          }
        }
      }
      if (type == 'video') {
        ops.add(<String, Object>{
          'insert': <String, Object>{'video': file.path},
          if (extra.isNotEmpty) 'attributes': extra,
        });
      } else {
        // 附件：透传全部原始字段（不规范化键名，测试期望保留 url/size 原样），
        // 避免 file.encode() 丢掉 custom 等未知 metadata。
        final data = <String, Object>{};
        if (attributes is Map) {
          for (final entry in attributes.entries) {
            final key = entry.key;
            if (key is String) {
              data[key] = entry.value as Object;
            }
          }
        }
        // 确保 path/url 指向解码出的规范路径。
        if (!data.containsKey('path') && !data.containsKey('url')) {
          data['path'] = file.path;
        }
        ops.add(<String, Object>{
          'insert': <String, Object>{diaryAttachmentEmbedType: data},
        });
      }
      ops.add(<String, Object>{'insert': '\n'});
    }
    return;
  }
  if (type == diaryAudioEmbedType) {
    final attributes = rawNode['attributes'];
    if (attributes is Map) {
      final data = <String, Object>{
        for (final entry in attributes.entries)
          if (entry.key is String) entry.key as String: entry.value as Object,
      };
      // 确保 path 存在且非空，否则丢弃。
      final path = data['path'];
      if (path is String && path.trim().isNotEmpty) {
        data['path'] = path.trim();
        ops.add(<String, Object>{
          'insert': <String, Object>{diaryAudioEmbedType: data},
        });
        ops.add(<String, Object>{'insert': '\n'});
      }
    }
    return;
  }
  if (type == 'image') {
    final attributes = rawNode['attributes'];
    final url = attributes is Map<String, dynamic>
        ? attributes['url'] as String?
        : null;
    if (url != null && url.isNotEmpty) {
      ops.add(<String, Object>{
        'insert': <String, Object>{'image': url},
      });
      ops.add(<String, Object>{'insert': '\n'});
    }
    return;
  }

  final text = _extractAppFlowyNodeText(rawNode);
  if (text.isNotEmpty) {
    ops.add(<String, Object>{'insert': text});
  }

  if (_isBlockNode(type) && (text.isNotEmpty || type == 'paragraph')) {
    ops.add(<String, Object>{'insert': '\n'});
  }

  for (final child in _extractChildren(rawNode)) {
    _appendAppFlowyNode(child, ops);
  }
}

String _extractAppFlowyNodeText(Map<String, dynamic> rawNode) {
  final attributes = rawNode['attributes'];
  if (attributes is! Map<String, dynamic>) {
    return '';
  }

  final delta = attributes['delta'];
  if (delta is! List) {
    return '';
  }

  final buffer = StringBuffer();
  for (final op in delta) {
    if (op is Map<String, dynamic>) {
      final insert = op['insert'];
      if (insert is String) {
        buffer.write(insert);
      }
    }
  }

  return buffer.toString().replaceAll(RegExp(r'\n+$'), '');
}

bool _isBlockNode(String? type) {
  return switch (type) {
    'paragraph' => true,
    'quote' => true,
    'bulleted_list' => true,
    'numbered_list' => true,
    'todo_list' => true,
    'heading' => true,
    'code_block' => true,
    _ => false,
  };
}
