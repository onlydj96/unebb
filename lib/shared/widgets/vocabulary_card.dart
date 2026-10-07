import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/shared/widgets/memory_indicator.dart';

/// 어휘 목록에서 단일 단어를 표시하는 카드 위젯.
///
/// [memoryStrength] 가 제공되면 AI 컨텐츠가 준비된 항목에 한해
/// [MemoryIndicator] 를 하단에 렌더링합니다.
class VocabularyCard extends StatelessWidget {
  const VocabularyCard({
    super.key,
    required this.item,
    this.memoryStrength,
    this.onTap,
  });

  final VocabularyItem item;

  /// 메모리 강도 (0.0–1.0). null 이면 표시하지 않음.
  final double? memoryStrength;

  final VoidCallback? onTap;

  bool get _hasAi => item.definition != null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.largeBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.word, style: AppTypography.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      item.language,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    if (_hasAi && memoryStrength != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      MemoryIndicator(strength: memoryStrength!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _hasAi
                  ? const Icon(Icons.chevron_right, color: AppColors.textMuted)
                  : const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
