import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/shared/widgets/memory_indicator.dart';

/// State of a word's AI content as far as the card is concerned.
enum VocabularyCardAiState { ready, generating, missing }

/// A single word in a vocabulary list.
///
/// Shows the memory strength once AI content exists, a spinner while it is
/// generated and a retry button when it is missing (generation failed or
/// was interrupted) — instead of an endless spinner.
class VocabularyCard extends StatelessWidget {
  const VocabularyCard({
    super.key,
    required this.item,
    this.memoryStrength,
    this.aiState,
    this.onRetryAi,
    this.retryTooltip,
    this.onTap,
  });

  final VocabularyItem item;

  /// Memory strength (0.0–1.0). Hidden when null.
  final double? memoryStrength;

  /// Defaults to [VocabularyCardAiState.ready] when the item has a
  /// definition, otherwise [VocabularyCardAiState.generating].
  final VocabularyCardAiState? aiState;
  final VoidCallback? onRetryAi;
  final String? retryTooltip;
  final VoidCallback? onTap;

  VocabularyCardAiState get _aiState =>
      aiState ??
      (item.definition != null
          ? VocabularyCardAiState.ready
          : VocabularyCardAiState.generating);

  @override
  Widget build(BuildContext context) {
    final state = _aiState;
    final strength = memoryStrength;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md + 2,
            14,
            AppSpacing.sm,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.word,
                          style: AppTypography.word,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(item.language, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  switch (state) {
                    VocabularyCardAiState.ready => const Padding(
                        padding: EdgeInsets.only(right: AppSpacing.xs),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    VocabularyCardAiState.generating => const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    VocabularyCardAiState.missing => IconButton(
                        icon: const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppColors.warningText,
                        ),
                        tooltip: retryTooltip,
                        onPressed: onRetryAi,
                      ),
                  },
                ],
              ),
              if (state == VocabularyCardAiState.ready && strength != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: MemoryIndicator(strength: strength),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
