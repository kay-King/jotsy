import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_schema.dart';

/// AppFlowy 的音频 / 视频是独立块节点：点中这类节点即视为播放手势，只消费
/// 它们的点击，后方正文和空行仍走正常编辑手势。
///
/// Quill 时代编辑器用透明点击识别器，还要处理“嵌入块结尾换行”的点中；块文
/// 档里媒体块没有结尾换行的概念，因此只判断节点本身。[editorState] 保留给
/// 调用方透传（手势入口持有它），判断只依赖 [node]。
bool isDiaryPlaybackTap(EditorState editorState, Node node) {
  return _isPlaybackNode(node);
}

bool _isPlaybackNode(Node node) =>
    node.type == kDiaryBlockVideo || node.type == kDiaryBlockAudio;
