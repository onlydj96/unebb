import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';

/// Settings screen with user profile and app settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Profile section
          profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (profile) {
              if (profile == null) {
                return const SizedBox.shrink();
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 24,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                _LanguageChip(
                                  label: 'Native',
                                  language: profile.nativeLanguage,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _LanguageChip(
                                  label: 'Learning',
                                  language: profile.learningLanguage,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Settings sections
          Text('Account', style: AppTypography.headingSmall),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to edit profile
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out?'),
                        content: const Text(
                            'Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await signOut();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // About section
          Text('About', style: AppTypography.headingSmall),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  trailing: Text(
                    '1.0.0',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.language,
  });

  final String label;
  final String language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(fontSize: 10),
          ),
          Text(
            language,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
