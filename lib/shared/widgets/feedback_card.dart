import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';

/// AI 평가 피드백을 표시하는 카드 위젯.
///
/// [feedback] 을 메인 텍스트로, [weakPoint] 가 있으면
/// 하이라이트 박스로 추가 표시합니다.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.feedback,
    this.weakPoint,
  });

  final String feedback;
  final String? weakPoint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 피드백 본문
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.mediumBorder,
          ),
          child: Text(feedback, style: AppTypography.bodyMedium),
        ),

        // 약점 하이라이트 (있을 때만)
        if (weakPoint != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              borderRadius: AppRadius.mediumBorder,
              border: Border.all(
                color: AppColors.warning.withAlpha(80),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Focus area: $weakPoint',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
