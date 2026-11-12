import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/auth/widgets/sign_out.dart';
import 'package:unebb/shared/widgets/brand_mark.dart';
import 'package:unebb/shared/widgets/labels.dart';

/// Settings screen with user profile and app settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 40),
        children: [
          if (profile != null) ...[
            _ProfileHeader(profile: profile),
            const SizedBox(height: AppSpacing.xl),
          ],
          SectionLabel(l10n.account),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(l10n.editProfile),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => context.push('/profile-setup'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    l10n.signOut,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () => confirmAndSignOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.about),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.version),
              trailing: Text(
                '1.0.0',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Column(
              children: [
                const BrandLockup(markSize: 40),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.tagline,
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = profile.displayName.trim();
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.cocoa,
            shape: BoxShape.circle,
          ),
          child: Text(
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.textOnDark,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.headingMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TagPill('${l10n.nativeShort} · ${profile.nativeLanguage}'),
                  TagPill(
                    '${l10n.learningShort} · ${profile.learningLanguage}',
                    icon: Icons.school_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
