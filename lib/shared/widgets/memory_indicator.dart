import 'package:flutter/material.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_typography.dart';

/// 메모리 강도(0.0–1.0)를 컬러 막대로 시각화하는 재사용 위젯.
///
/// 색은 망각(crimson) → 회상(mint) 축을 따라 4단계로 변합니다.
/// [showLabel] = true 이면 단계 이름과 퍼센트를 위에 표시합니다.
class MemoryIndicator extends StatelessWidget {
  const MemoryIndicator({
    super.key,
    required this.strength,
    this.showLabel = false,
    this.height = 4.0,
  });

  final double strength;
  final bool showLabel;
  final double height;

  /// Stage colour for [strength].
  static Color colorFor(double strength) {
    if (strength >= 0.80) return AppColors.memoryStrong;
    if (strength >= 0.60) return AppColors.memoryMedium;
    if (strength >= 0.30) return AppColors.memoryWeak;
    return AppColors.memoryCritical;
  }

  /// Localised stage name for [strength].
  static String stageName(AppLocalizations l10n, double strength) {
    if (strength >= 0.80) return l10n.memoryStrong;
    if (strength >= 0.60) return l10n.memoryGood;
    if (strength >= 0.30) return l10n.memoryWeak;
    return l10n.memoryCritical;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(strength);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              StageDot(color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stageName(context.l10n, strength),
                  style: AppTypography.labelLarge.copyWith(fontSize: 14),
                ),
              ),
              Text(
                '${(strength * 100).round()}%',
                style: AppTypography.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        // Animates memory strength changes (design system: motion
        // communicates state changes).
        TweenAnimationBuilder<double>(
          tween: Tween(end: strength.clamp(0.0, 1.0)),
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => ClipRRect(
            borderRadius: AppRadius.fullBorder,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: AppColors.surfaceElevated,
              color: color,
              minHeight: height,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small filled circle used as a colour key.
class StageDot extends StatelessWidget {
  const StageDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// 메모리 강도 변화(이전 → 이후)를 강조해서 표시하는 칩.
class MemoryStrengthDelta extends StatelessWidget {
  const MemoryStrengthDelta({
    super.key,
    required this.previous,
    required this.updated,
  });

  final double previous;
  final double updated;

  @override
  Widget build(BuildContext context) {
    final improved = updated >= previous;
    final delta = ((updated - previous) * 100).round().abs();
    final arrow = improved ? '↑' : '↓';
    final foreground = improved ? AppColors.successText : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: improved ? AppColors.successSoft : AppColors.errorSoft,
        borderRadius: AppRadius.fullBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            improved ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Text(
            '${(previous * 100).round()}% → ${(updated * 100).round()}%',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$arrow$delta%',
            style: AppTypography.labelMedium.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
