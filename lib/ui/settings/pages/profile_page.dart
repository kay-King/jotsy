import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/providers/diary_profile_provider.dart';
import '../../diaries/widgets/diary_timeline/diary_timeline_avatar.dart';
import '../../widgets/app_top_bar.dart';
import '../controllers/profile_page_controller.dart';
import '../widgets/settings_card_group.dart';

/// 设置 › 个人资料：时间线里显示的昵称与头像。
///
/// 昵称提交或失焦即保存（空表示未设置，展示时回退为“我”）；头像从相册
/// 选图后拷贝进私有目录，未设置时显示昵称首字。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final ProfilePageController _controller = ProfilePageController(ref);
  late final TextEditingController _nicknameController;
  late final FocusNode _nicknameFocusNode;
  bool _importingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: ref.read(diaryProfileProvider).nickname,
    );
    _nicknameFocusNode = FocusNode();
    _nicknameFocusNode.addListener(_onNicknameFocusChanged);
  }

  @override
  void dispose() {
    _nicknameFocusNode.removeListener(_onNicknameFocusChanged);
    _nicknameFocusNode.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _onNicknameFocusChanged() {
    if (!_nicknameFocusNode.hasFocus) {
      _saveNickname();
    }
  }

  void _saveNickname() {
    final current = ref.read(diaryProfileProvider).nickname;
    if (_nicknameController.text != current) {
      unawaited(_controller.saveNickname(_nicknameController.text));
    }
  }

  Future<void> _pickAvatar() async {
    if (_importingAvatar) {
      return;
    }
    setState(() => _importingAvatar = true);
    try {
      await _controller.pickAvatar();
    } finally {
      if (mounted) {
        setState(() => _importingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final profile = ref.watch(diaryProfileProvider);
    final hasAvatar = profile.avatarFile != null;

    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.profileTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, 24),
        children: <Widget>[
          SettingsCardGroup(
            title: l10n.profileAvatar,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DiaryTimelineAvatar(profile: profile, size: 72),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FilledButton.tonal(
                            onPressed: _importingAvatar ? null : _pickAvatar,
                            child: Text(l10n.profileChangeAvatar),
                          ),
                          if (hasAvatar)
                            TextButton(
                              onPressed: _importingAvatar
                                  ? null
                                  : () => unawaited(_controller.removeAvatar()),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.error,
                              ),
                              child: Text(l10n.profileRemoveAvatar),
                            ),
                          Text(
                            l10n.profileAvatarHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsCardGroup(
            title: l10n.profileNickname,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: TextField(
                  controller: _nicknameController,
                  focusNode: _nicknameFocusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveNickname(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    helperText: l10n.profileNicknameHint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
