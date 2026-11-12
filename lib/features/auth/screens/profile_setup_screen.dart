import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/constants/languages.dart';
import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/utils/error_messages.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/auth/widgets/auth_header.dart';
import 'package:unebb/shared/widgets/app_notice.dart';
import 'package:unebb/shared/widgets/language_dropdown.dart';
import 'package:unebb/shared/widgets/loading_button.dart';

/// First-run profile setup; also used to edit the profile from Settings
/// (fields are prefilled when a profile exists).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _nativeLanguage = SupportedLanguages.defaultNative;
  String _learningLanguage = SupportedLanguages.defaultLearning;
  bool _loading = false;
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _prefill(UserProfile? profile) {
    if (_prefilled || profile == null) return;
    _prefilled = true;
    _nameCtrl.text = profile.displayName;
    _nativeLanguage = profile.nativeLanguage;
    _learningLanguage = profile.learningLanguage;
  }

  Future<void> _save() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final displayName = _nameCtrl.text.trim();
      await upsertProfile(
        displayName: displayName,
        nativeLanguage: _nativeLanguage,
        learningLanguage: _learningLanguage,
      );
      // Cache first so the reloaded profile is available immediately and the
      // router does not bounce back here while it reloads.
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        await ref.read(cacheServiceProvider).cacheProfile(UserProfile(
              id: userId,
              displayName: displayName,
              nativeLanguage: _nativeLanguage,
              learningLanguage: _learningLanguage,
            ));
      }
      ref.invalidate(profileProvider);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e, st) {
      AppLogger.error('Saving profile failed', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(context.l10n, e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final existing = ref.watch(profileProvider).valueOrNull;
    _prefill(existing);
    final editing = existing != null;

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: l10n.displayName,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? l10n.displayNameRequired : null,
          ),
          const SizedBox(height: AppSpacing.md),
          NativeLanguageDropdown(
            value: _nativeLanguage,
            label: l10n.nativeLanguage,
            onChanged: (v) {
              if (v != null) setState(() => _nativeLanguage = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LearningLanguageDropdown(
            value: _learningLanguage,
            label: l10n.learningLanguage,
            onChanged: (v) {
              if (v != null) setState(() => _learningLanguage = v);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppNotice(
              tone: AppTone.error,
              icon: Icons.error_outline_rounded,
              message: _error!,
              dense: true,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          LoadingButton(
            onPressed: _save,
            label: editing ? l10n.save : l10n.startLearning,
            isLoading: _loading,
          ),
        ],
      ),
    );

    if (!editing) {
      return AuthScaffold(
        title: l10n.setUpProfile,
        subtitle: l10n.profileSubtitle,
        child: form,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.lg),
          child: form,
        ),
      ),
    );
  }
}
