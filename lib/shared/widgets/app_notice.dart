import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';

/// Inline, tone-tinted message panel (offline, success, focus area, AI
/// status…). Flat: colour carries the meaning, no border.
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.message,
    this.tone = AppTone.neutral,
    this.icon,
    this.leading,
    this.title,
    this.action,
    this.dense = false,
  });

  final String message;
  final AppTone tone;
  final IconData? icon;

  /// Replaces [icon] (e.g. a small progress indicator).
  final Widget? leading;
  final String? title;
  final Widget? action;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final lead = leading ??
        (icon == null
            ? null
            : Icon(icon, size: dense ? 18 : 20, color: tone.foreground));
    final textStyle =
        (dense ? AppTypography.bodySmall : AppTypography.bodyMedium)
            .copyWith(color: AppColors.textPrimary);

    return Container(
      padding: EdgeInsets.all(dense ? 12 : AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: AppRadius.mediumBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lead != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(width: 20, child: Center(child: lead)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: AppTypography.labelLarge
                            .copyWith(color: tone.foreground),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(message, style: textStyle),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.only(left: lead == null ? 0 : 32),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}
