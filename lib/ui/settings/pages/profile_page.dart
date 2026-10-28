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
/// 选图后拷贝进私有目录，未设置时显示昵称首字。简介与封面同口径：简介
/// 失焦即保存，封面从相册选图后拷贝进私有目录，未设置时显示默认渐变封面。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final ProfilePageController _controller = ProfilePageController(ref);
  late final TextEditingController _nicknameController;
  late final FocusNode _nicknameFocusNode;
  late final TextEditingController _bioController;
  late final FocusNode _bioFocusNode;
  bool _importingAvatar = false;
  bool _importingCover = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(diaryProfileProvider);
    _nicknameController = TextEditingController(text: profile.nickname);
    _nicknameFocusNode = FocusNode();
    _nicknameFocusNode.addListener(_onNicknameFocusChanged);
    _bioController = TextEditingController(text: profile.bio);
    _bioFocusNode = FocusNode();
    _bioFocusNode.addListener(_onBioFocusChanged);
  }

  @override
  void dispose() {
    _nicknameFocusNode.removeListener(_onNicknameFocusChanged);
    _nicknameFocusNode.dispose();
    _nicknameController.dispose();
    _bioFocusNode.removeListener(_onBioFocusChanged);
    _bioFocusNode.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onNicknameFocusChanged() {
    if (!_nicknameFocusNode.hasFocus) {
      _saveNickname();
    }
  }

  void _onBioFocusChanged() {
    if (!_bioFocusNode.hasFocus) {
      _saveBio();
    }
  }

  void _saveNickname() {
    final current = ref.read(diaryProfileProvider).nickname;
    if (_nicknameController.text != current) {
      unawaited(_controller.saveNickname(_nicknameController.text));
    }
  }

  void _saveBio() {
    final current = ref.read(diaryProfileProvider).bio;
    if (_bioController.text != current) {
      unawaited(_controller.saveBio(_bioController.text));
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

  Future<void> _pickCover() async {
    if (_importingCover) {
      return;
    }
    setState(() => _importingCover = true);
    try {
      await _controller.pickCover();
    } finally {
      if (mounted) {
        setState(() => _importingCover = false);
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
                  maxLength: DiaryProfile.nicknameMaxLength,
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
          const SizedBox(height: 20),
          SettingsCardGroup(
            title: l10n.profileBio,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: TextField(
                  controller: _bioController,
                  focusNode: _bioFocusNode,
                  maxLength: DiaryProfile.bioMaxLength,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveBio(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    helperText: l10n.profileBioHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsCardGroup(
            title: l10n.profileCover,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        FilledButton.tonal(
                          onPressed: _importingCover ? null : _pickCover,
                          child: Text(l10n.profileChangeCover),
                        ),
                        if (profile.coverFile != null)
                          TextButton(
                            onPressed: _importingCover
                                ? null
                                : () => unawaited(_controller.removeCover()),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.error,
                            ),
                            child: Text(l10n.profileRemoveCover),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.profileCoverHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
