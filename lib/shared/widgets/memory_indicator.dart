import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_typography.dart';

/// 메모리 강도(0.0–1.0)를 컬러 막대로 시각화하는 재사용 위젯.
///
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

  Color get _color {
    if (strength >= 0.80) return AppColors.memoryStrong;
    if (strength >= 0.60) return AppColors.memoryMedium;
    if (strength >= 0.30) return AppColors.memoryWeak;
    return AppColors.memoryCritical;
  }

  String get _stageName {
    if (strength >= 0.80) return 'Strong';
    if (strength >= 0.60) return 'Good';
    if (strength >= 0.30) return 'Weak';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _stageName,
                style: AppTypography.labelMedium.copyWith(color: _color),
              ),
              Text(
                '${(strength * 100).round()}%',
                style: AppTypography.labelMedium.copyWith(color: _color),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: AppRadius.fullBorder,
          child: LinearProgressIndicator(
            value: strength.clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceElevated,
            color: _color,
            minHeight: height,
          ),
        ),
      ],
    );
  }
}

/// 메모리 강도 변화(이전 → 이후)를 강조해서 표시하는 위젯.
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
    final color = improved ? AppColors.success : AppColors.error;

    return Row(
      children: [
        const Icon(Icons.memory, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          '${(previous * 100).round()}% → ${(updated * 100).round()}%'
          '  $arrow$delta%',
          style: AppTypography.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}
