import 'package:flutter/material.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/shared/widgets/app_notice.dart';
import 'package:unebb/shared/widgets/labels.dart';

/// AI 평가 피드백을 표시하는 카드 위젯.
///
/// [feedback] 을 메인 텍스트로, [weakPoint] 가 있으면
/// "집중할 부분" 노티스로 추가 표시합니다.
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
    final point = weakPoint;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (feedback.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.largeBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(l10n.feedback, icon: Icons.auto_awesome),
                const SizedBox(height: AppSpacing.sm),
                Text(feedback, style: AppTypography.bodyMedium),
              ],
            ),
          ),
        if (point != null && point.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppNotice(
            tone: AppTone.warning,
            icon: Icons.lightbulb_outline_rounded,
            message: l10n.focusArea(point),
            dense: true,
          ),
        ],
      ],
    );
  }
}
