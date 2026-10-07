import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  String _nativeLanguage = 'Korean';
  String _learningLanguage = 'English';
  bool _loading = false;
  String? _error;

  static const _languages = [
    'English',
    'Korean',
    'Japanese',
    'Chinese',
    'Spanish',
    'French',
    'German',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your display name.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await upsertProfile(
        displayName: _nameCtrl.text.trim(),
        nativeLanguage: _nativeLanguage,
        learningLanguage: _learningLanguage,
      );
      if (mounted) context.go('/');
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              const Text('Set up your profile',
                  style: AppTypography.headingLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This helps UnEbb personalise your experience.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Display name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Native language', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: _nativeLanguage,
                items: _languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _nativeLanguage = v!),
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('Learning language', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: _learningLanguage,
                items: _languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _learningLanguage = v!),
                decoration: const InputDecoration(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Start learning'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
