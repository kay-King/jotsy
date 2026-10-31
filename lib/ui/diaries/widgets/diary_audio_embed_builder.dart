import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/services/audio_playback_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player.dart';
import 'package:node_diary/ui/diaries/widgets/diary_playback_interaction_guard.dart';

/// 正文录音的 AppFlowy 块组件：注册到 `audio` 类型节点的渲染器。
///
/// 数据解析与 UI 与 Quill 时代一致：节点 attributes 即
/// [DiaryAudioAttachment] 的字段（`path` / `durationMs` / `name` /
/// `waveform`），解析后交给 [DiaryAudioPlayer] 渲染。重命名经 EditorState
/// 事务写回同一节点的 attributes（Quill 时代经 controller.replaceText）。
class DiaryAudioEmbedBuilder extends BlockComponentBuilder {
  DiaryAudioEmbedBuilder({this.player});

  final AudioPlaybackService? player;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _DiaryAudioBlockWidget(key: node.key, node: node, player: player);
  }
}

class _DiaryAudioBlockWidget extends BlockComponentStatelessWidget {
  const _DiaryAudioBlockWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
    this.player,
  });

  final AudioPlaybackService? player;

  @override
  Widget build(BuildContext context) {
    final audio = DiaryAudioAttachment.tryDecode(node.attributes);
    if (audio == null) {
      return Text(
        context.l10n.recordingPlaybackFailed,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    final editorState = context
        .findAncestorWidgetOfExactType<AppFlowyEditor>()
        ?.editorState;
    final renameEnabled = editorState?.editable ?? false;
    return DiaryPlaybackInteractionGuard(
      child: DiaryAudioPlayer(
        key: ValueKey(audio.path),
        recording: audio,
        player: player,
        onRename: renameEnabled
            ? (newName) {
                final trimmed = newName.trim();
                final updated = audio.copyWith(
                  name: trimmed.isNotEmpty ? trimmed : null,
                );
                // attributes 与存储格式一致：DiaryAudioAttachment 的字段；
                // updateNode 会合并进现有 attributes 并支持撤销。
                final transaction = editorState!.transaction;
                transaction.updateNode(
                  node,
                  jsonDecode(updated.encode()) as Map<String, dynamic>,
                );
                unawaited(editorState.apply(transaction));
              }
            : null,
      ),
    );
  }
}
