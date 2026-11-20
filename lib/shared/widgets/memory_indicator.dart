import 'package:flutter/material.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/memory_reading.dart';

/// 단어의 기억 상태(레벨 + 강도 0.0–1.0)를 컬러 막대로 시각화하는 재사용 위젯.
///
/// 색은 망각(crimson) → 회상(mint) 축을 따라 변하고, 아직 한 번도 맞히지 못한
/// 단어(학습 중)는 중립색입니다. [showLabel] = true 이면 레벨 이름과 퍼센트를
/// 위에 표시합니다.
class MemoryIndicator extends StatelessWidget {
  const MemoryIndicator({
    super.key,
    required this.reading,
    this.showLabel = false,
    this.height = 4.0,
  });

  final MemoryReading reading;
  final bool showLabel;
  final double height;

  /// Colour of [level].
  static Color colorOf(MemoryLevel level) => switch (level) {
        MemoryLevel.strong => AppColors.memoryStrong,
        MemoryLevel.good => AppColors.memoryMedium,
        MemoryLevel.weak => AppColors.memoryWeak,
        MemoryLevel.critical => AppColors.memoryCritical,
        MemoryLevel.learning => AppColors.memoryLearning,
      };

  /// Localised name of [level].
  static String nameOf(AppLocalizations l10n, MemoryLevel level) =>
      switch (level) {
        MemoryLevel.strong => l10n.memoryStrong,
        MemoryLevel.good => l10n.memoryGood,
        MemoryLevel.weak => l10n.memoryWeak,
        MemoryLevel.critical => l10n.memoryCritical,
        MemoryLevel.learning => l10n.memoryLearning,
      };

  /// Whole percent shown for [strength]. Rounded down, so a word just below
  /// a level's lower bound never shows that bound (0.799 → 79%, good).
  static int percentOf(double strength) =>
      (strength.clamp(0.0, 1.0) * 100).floor();

  @override
  Widget build(BuildContext context) {
    final level = reading.level;
    final strength = reading.strength;
    final color = colorOf(level);
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
                  nameOf(context.l10n, level),
                  style: AppTypography.labelLarge.copyWith(fontSize: 14),
                ),
              ),
              // Nothing is remembered yet while learning.
              if (level != MemoryLevel.learning)
                Text(
                  '${percentOf(strength)}%',
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
    final from = MemoryIndicator.percentOf(previous);
    final to = MemoryIndicator.percentOf(updated);
    final change = to - from;
    // Unchanged (e.g. a correct answer before the word was due): neutral.
    final (icon, foreground, background, deltaLabel) = switch (change.sign) {
      1 => (
          Icons.trending_up_rounded,
          AppColors.successText,
          AppColors.successSoft,
          '↑$change%',
        ),
      -1 => (
          Icons.trending_down_rounded,
          AppColors.error,
          AppColors.errorSoft,
          '↓${-change}%',
        ),
      _ => (
          Icons.trending_flat_rounded,
          AppColors.textSecondary,
          AppColors.surfaceElevated,
          null,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.fullBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Text(
            '$from% → $to%',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (deltaLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              deltaLabel,
              style: AppTypography.labelMedium.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
