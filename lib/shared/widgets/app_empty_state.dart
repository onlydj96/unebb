import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';

/// Centred message for empty, finished and failed states: a tone-coloured
/// badge, a title, an optional explanation and full-width actions.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.tone = AppTone.neutral,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final IconData? icon;
  final AppTone tone;

  /// Replaces the icon badge (e.g. with the brand mark or a score ring).
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final badge = leading ?? (icon == null ? null : ToneBadge(icon!, tone));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (badge != null) ...[
                Center(child: badge),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                title,
                style: AppTypography.headingMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  actions[i],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon on a soft, tone-coloured disc.
class ToneBadge extends StatelessWidget {
  const ToneBadge(this.icon, this.tone, {super.key, this.size = 80});

  final IconData icon;
  final AppTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.soft, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.42, color: tone.foreground),
    );
  }
}
