import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/ai_evaluation.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/review/providers/review_providers.dart';
import 'package:unebb/shared/widgets/feedback_card.dart';
import 'package:unebb/shared/widgets/memory_indicator.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.mode = 'due', this.limit, this.deckId});

  final String mode;
  final int? limit;
  final String? deckId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reviewNotifierProvider.notifier).startSession(
            mode: widget.mode,
            limit: widget.limit,
            deckId: widget.deckId,
          );
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(state),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey('${state.phase}-${state.currentIndex}'),
          child: switch (state.phase) {
            ReviewPhase.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            ReviewPhase.empty => _EmptyView(
                onBack: () => context.pop(),
              ),
            ReviewPhase.showWord => _FlashCardFront(
                item: state.currentItem!,
                currentIndex: state.currentIndex,
                totalItems: state.totalItems,
                onTap: () =>
                    ref.read(reviewNotifierProvider.notifier).tapWord(),
              ),
            ReviewPhase.meaningInput => _MeaningInputView(
                item: state.currentItem!,
                currentIndex: state.currentIndex,
                totalItems: state.totalItems,
                controller: _answerController,
                onSubmit: (answer) {
                  _answerController.clear();
                  ref
                      .read(reviewNotifierProvider.notifier)
                      .submitMeaning(answer);
                },
              ),
            ReviewPhase.evaluatingMeaning => _BusyView(
                word: state.currentItem?.word ?? '',
                message: AppLocalizations.of(context)!.checkingYourAnswer,
              ),
            ReviewPhase.meaningFailed => _MeaningFailedView(
                item: state.currentItem!,
                evaluation: state.meaningEvaluation!,
                onNext: () =>
                    ref.read(reviewNotifierProvider.notifier).nextAfterFailed(),
              ),
            ReviewPhase.generatingTranslation => _BusyView(
                word: state.currentItem?.word ?? '',
                message: AppLocalizations.of(context)!.preparingTranslationExercise,
              ),
            ReviewPhase.translationInput => _TranslationInputView(
                item: state.currentItem!,
                sentence: state.translationSentence ?? '',
                wordHint: state.wordHint,
                currentIndex: state.currentIndex,
                totalItems: state.totalItems,
                controller: _answerController,
                onSubmit: (answer) {
                  _answerController.clear();
                  ref
                      .read(reviewNotifierProvider.notifier)
                      .submitTranslation(answer);
                },
              ),
            ReviewPhase.evaluatingTranslation => _BusyView(
                word: state.currentItem?.word ?? '',
                message: AppLocalizations.of(context)!.evaluatingYourTranslation,
              ),
            ReviewPhase.showResult => _ResultView(
                item: state.currentItem!,
                meaningEvaluation: state.meaningEvaluation!,
                translationEvaluation: state.translationEvaluation,
                detectedPatterns: state.allDetectedPatterns,
                previousStrength: state.previousStrength,
                updatedStrength: state.updatedStrength,
                currentIndex: state.currentIndex,
                totalItems: state.totalItems,
                onNext: () =>
                    ref.read(reviewNotifierProvider.notifier).nextWord(),
              ),
            ReviewPhase.complete => _CompleteView(
                correctCount: state.correctCount,
                totalItems: state.totalItems,
                onDone: () => context.pop(),
              ),
            ReviewPhase.error => _ErrorView(
                message: state.error ?? 'An error occurred.',
                onRetry: () =>
                    ref.read(reviewNotifierProvider.notifier).startSession(),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildTitle(ReviewUiState state) {
    const activePhases = {
      ReviewPhase.showWord,
      ReviewPhase.meaningInput,
      ReviewPhase.evaluatingMeaning,
      ReviewPhase.meaningFailed,
      ReviewPhase.generatingTranslation,
      ReviewPhase.translationInput,
      ReviewPhase.evaluatingTranslation,
      ReviewPhase.showResult,
    };
    if (activePhases.contains(state.phase)) {
      return Text(
        '${state.currentIndex + 1} / ${state.totalItems}',
        style: AppTypography.headingSmall,
      );
    }
    return Text(AppLocalizations.of(context)!.review);
  }
}

// ---------------------------------------------------------------------------
// Flash card front
// ---------------------------------------------------------------------------

class _FlashCardFront extends StatelessWidget {
  const _FlashCardFront({
    required this.item,
    required this.currentIndex,
    required this.totalItems,
    required this.onTap,
  });

  final VocabularyItem item;
  final int currentIndex;
  final int totalItems;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.xLargeBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: totalItems > 0 ? currentIndex / totalItems : 0,
                    backgroundColor: AppColors.surfaceElevated,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(item.word, style: AppTypography.displayMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.language,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_outlined,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        AppLocalizations.of(context)!.tapToAnswer,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meaning input
// ---------------------------------------------------------------------------

class _MeaningInputView extends StatelessWidget {
  const _MeaningInputView({
    required this.item,
    required this.currentIndex,
    required this.totalItems,
    required this.controller,
    required this.onSubmit,
  });

  final VocabularyItem item;
  final int currentIndex;
  final int totalItems;
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: totalItems > 0 ? currentIndex / totalItems : 0,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.largeBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Text(item.word, style: AppTypography.displayMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.language,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppLocalizations.of(context)!.whatIsTheMeaning,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            maxLines: 1,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.enterMeaningHint,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              final answer = value.trim();
              if (answer.isNotEmpty) onSubmit(answer);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              final answer = controller.text.trim();
              if (answer.isNotEmpty) onSubmit(answer);
            },
            child: Text(AppLocalizations.of(context)!.submitAnswer),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Busy (spinner) view — shared for all loading phases
// ---------------------------------------------------------------------------

class _BusyView extends StatelessWidget {
  const _BusyView({required this.word, required this.message});

  final String word;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (word.isNotEmpty) Text(word, style: AppTypography.displayMedium),
            const SizedBox(height: AppSpacing.xl),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meaning failed — show correct meaning + AI feedback
// ---------------------------------------------------------------------------

class _MeaningFailedView extends StatelessWidget {
  const _MeaningFailedView({
    required this.item,
    required this.evaluation,
    required this.onNext,
  });

  final VocabularyItem item;
  final AiEvaluation evaluation;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.error, width: 2),
              ),
              child: const Icon(Icons.close, color: AppColors.error, size: 32),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(item.word, style: AppTypography.headingMedium),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(15),
              borderRadius: AppRadius.largeBorder,
              border: Border.all(color: AppColors.error.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.correctMeaning,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(item.definition ?? '', style: AppTypography.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FeedbackCard(
            feedback: evaluation.feedback,
            weakPoint: evaluation.weakPoint,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: onNext,
            child: Text(AppLocalizations.of(context)!.nextWord),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Translation input
// ---------------------------------------------------------------------------

class _TranslationInputView extends StatelessWidget {
  const _TranslationInputView({
    required this.item,
    required this.sentence,
    required this.wordHint,
    required this.currentIndex,
    required this.totalItems,
    required this.controller,
    required this.onSubmit,
  });

  final VocabularyItem item;
  final String sentence;
  final String? wordHint;
  final int currentIndex;
  final int totalItems;
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: totalItems > 0 ? currentIndex / totalItems : 0,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.secondary,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppLocalizations.of(context)!.translateInto(item.language),
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.largeBorder,
              border: Border.all(color: AppColors.secondary.withAlpha(80)),
            ),
            child: Text(sentence, style: AppTypography.bodyLarge),
          ),
          if (wordHint != null && wordHint!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)!.hintUseWord(wordHint!),
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.yourTranslationHint(item.language),
              alignLabelWithHint: true,
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              final answer = controller.text.trim();
              if (answer.isNotEmpty) onSubmit(answer);
            },
            child: Text(AppLocalizations.of(context)!.submitTranslation),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result view — combined score + pattern badges
// ---------------------------------------------------------------------------

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.item,
    required this.meaningEvaluation,
    required this.translationEvaluation,
    required this.detectedPatterns,
    required this.previousStrength,
    required this.updatedStrength,
    required this.currentIndex,
    required this.totalItems,
    required this.onNext,
  });

  final VocabularyItem item;
  final AiEvaluation meaningEvaluation;
  final AiEvaluation? translationEvaluation;
  final List<String> detectedPatterns;
  final double previousStrength;
  final double updatedStrength;
  final int currentIndex;
  final int totalItems;
  final VoidCallback onNext;

  double get _combinedScore {
    final ts = translationEvaluation?.overallScore;
    if (ts == null) return meaningEvaluation.overallScore;
    return meaningEvaluation.overallScore * 0.4 + ts * 0.6;
  }

  @override
  Widget build(BuildContext context) {
    final score = _combinedScore;
    final scoreColor = score >= 0.6 ? AppColors.success : AppColors.error;
    final primaryFeedback = translationEvaluation ?? meaningEvaluation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scoreColor.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: scoreColor, width: 2),
              ),
              child: Center(
                child: Text(
                  '${(score * 100).round()}%',
                  style: AppTypography.headingLarge.copyWith(color: scoreColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(item.word, style: AppTypography.headingMedium),
          ),
          const SizedBox(height: AppSpacing.lg),
          FeedbackCard(
            feedback: primaryFeedback.feedback,
            weakPoint: primaryFeedback.weakPoint,
          ),
          const SizedBox(height: AppSpacing.md),
          _ScoreRow(AppLocalizations.of(context)!.meaning, meaningEvaluation.meaningScore),
          _ScoreRow(AppLocalizations.of(context)!.usage, meaningEvaluation.usageScore),
          if (translationEvaluation != null)
            _ScoreRow(AppLocalizations.of(context)!.translation, translationEvaluation!.usageScore),
          _ScoreRow(AppLocalizations.of(context)!.grammar, primaryFeedback.grammarScore),
          if (detectedPatterns.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _PatternBadges(patterns: detectedPatterns),
          ],
          const SizedBox(height: AppSpacing.md),
          MemoryStrengthDelta(
            previous: previousStrength,
            updated: updatedStrength,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: onNext,
            child: Text(
              currentIndex + 1 < totalItems
                ? AppLocalizations.of(context)!.nextWord
                : AppLocalizations.of(context)!.finish,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.label, this.score);

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score,
                backgroundColor: AppColors.surfaceElevated,
                color: score >= 0.6 ? AppColors.success : AppColors.error,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${(score * 100).round()}%',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PatternBadges extends StatelessWidget {
  const _PatternBadges({required this.patterns});

  final List<String> patterns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.patternsToWatch,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: patterns
              .map(
                (p) => Chip(
                  label: Text(p, style: AppTypography.bodySmall),
                  backgroundColor: AppColors.warning.withAlpha(20),
                  side: BorderSide(color: AppColors.warning.withAlpha(80)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / Complete / Error views
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: AppColors.success),
            const SizedBox(height: AppSpacing.md),
            Text(AppLocalizations.of(context)!.allCaughtUp, style: AppTypography.headingMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context)!.noDueWords,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: onBack, child: Text(AppLocalizations.of(context)!.back)),
          ],
        ),
      ),
    );
  }
}

class _CompleteView extends StatelessWidget {
  const _CompleteView({
    required this.correctCount,
    required this.totalItems,
    required this.onDone,
  });

  final int correctCount;
  final int totalItems;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 72, color: AppColors.warning),
            const SizedBox(height: AppSpacing.md),
            Text(AppLocalizations.of(context)!.sessionComplete, style: AppTypography.headingMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context)!.correctOutOf(correctCount, totalItems),
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: onDone, child: Text(AppLocalizations.of(context)!.done)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.retry)),
          ],
        ),
      ),
    );
  }
}
