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
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/review/providers/review_providers.dart';
import 'package:unebb/features/review/providers/voice_mode_provider.dart';
import 'package:unebb/features/review/widgets/voice_mode_widgets.dart';
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
        actions: const [
          VoiceModeToggle(),
          SizedBox(width: 8),
        ],
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
            ReviewPhase.showWord => _buildShowWordView(
                context,
                ref,
                state,
              ),
            ReviewPhase.askKnowledge => _buildAskKnowledgeView(
                context,
                ref,
                state,
              ),
            ReviewPhase.generatingExplanation => _BusyView(
                word: state.currentItem?.word ?? '',
                message: AppLocalizations.of(context)!.generatingExplanation,
              ),
            ReviewPhase.showExplanation => _ExplanationView(
                item: state.currentItem!,
                currentIndex: state.currentIndex,
                totalItems: state.totalItems,
                onNext: () =>
                    ref.read(reviewNotifierProvider.notifier).nextAfterExplanation(),
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
            ReviewPhase.translationInput => _buildTranslationInputView(
                context,
                ref,
                state,
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
      ReviewPhase.askKnowledge,
      ReviewPhase.generatingExplanation,
      ReviewPhase.showExplanation,
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

  Widget _buildShowWordView(
    BuildContext context,
    WidgetRef ref,
    ReviewUiState state,
  ) {
    final voiceState = ref.watch(voiceModeProvider);
    final item = state.currentItem!;

    if (voiceState.isEnabled) {
      return _VoiceShowWordView(
        item: item,
        currentIndex: state.currentIndex,
        totalItems: state.totalItems,
      );
    }

    return _FlashCardFront(
      item: item,
      currentIndex: state.currentIndex,
      totalItems: state.totalItems,
      onTap: () => ref.read(reviewNotifierProvider.notifier).tapWord(),
    );
  }

  Widget _buildTranslationInputView(
    BuildContext context,
    WidgetRef ref,
    ReviewUiState state,
  ) {
    final voiceState = ref.watch(voiceModeProvider);
    final item = state.currentItem!;

    if (voiceState.isEnabled) {
      return _VoiceTranslationInputView(
        item: item,
        sentence: state.translationSentence ?? '',
        wordHint: state.wordHint,
        currentIndex: state.currentIndex,
        totalItems: state.totalItems,
      );
    }

    return _TranslationInputView(
      item: item,
      sentence: state.translationSentence ?? '',
      wordHint: state.wordHint,
      currentIndex: state.currentIndex,
      totalItems: state.totalItems,
      controller: _answerController,
      onSubmit: (answer) {
        _answerController.clear();
        ref.read(reviewNotifierProvider.notifier).submitTranslation(answer);
      },
    );
  }

  Widget _buildAskKnowledgeView(
    BuildContext context,
    WidgetRef ref,
    ReviewUiState state,
  ) {
    final voiceState = ref.watch(voiceModeProvider);
    final item = state.currentItem!;

    if (voiceState.isEnabled) {
      return _VoiceShowWordView(
        item: item,
        currentIndex: state.currentIndex,
        totalItems: state.totalItems,
      );
    }

    return _AskKnowledgeView(
      item: item,
      currentIndex: state.currentIndex,
      totalItems: state.totalItems,
      onKnow: () => ref.read(reviewNotifierProvider.notifier).answerKnowWord(),
      onDontKnow: () => ref.read(reviewNotifierProvider.notifier).answerDontKnowWord(),
    );
  }
}

// ---------------------------------------------------------------------------
// Ask Knowledge View (Know / Don't Know)
// ---------------------------------------------------------------------------

class _AskKnowledgeView extends StatelessWidget {
  const _AskKnowledgeView({
    required this.item,
    required this.currentIndex,
    required this.totalItems,
    required this.onKnow,
    required this.onDontKnow,
  });

  final VocabularyItem item;
  final int currentIndex;
  final int totalItems;
  final VoidCallback onKnow;
  final VoidCallback onDontKnow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      l10n.doYouKnowThisWord,
                      style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onDontKnow,
                          icon: const Icon(Icons.close),
                          label: Text(l10n.iDontKnowIt),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: onKnow,
                          icon: const Icon(Icons.check),
                          label: Text(l10n.iKnowIt),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Explanation View (for "Don't Know" selection)
// ---------------------------------------------------------------------------

class _ExplanationView extends StatelessWidget {
  const _ExplanationView({
    required this.item,
    required this.currentIndex,
    required this.totalItems,
    required this.onNext,
  });

  final VocabularyItem item;
  final int currentIndex;
  final int totalItems;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: totalItems > 0 ? currentIndex / totalItems : 0,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Word header
          Card(
            color: AppColors.warning.withAlpha(25),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(item.word, style: AppTypography.headingLarge),
                  if (item.pronunciation != null && item.pronunciation!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.pronunciation!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.language,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Definition
          if (item.definition != null && item.definition!.isNotEmpty) ...[
            _ExplanationSection(
              title: l10n.definition,
              icon: Icons.book_outlined,
              content: item.definition!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Explanation
          if (item.explanation != null && item.explanation!.isNotEmpty) ...[
            _ExplanationSection(
              title: l10n.meaning,
              icon: Icons.lightbulb_outline,
              content: item.explanation!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Usage
          if (item.usage != null && item.usage!.isNotEmpty) ...[
            _ExplanationSection(
              title: l10n.usage,
              icon: Icons.format_quote,
              content: item.usage!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Examples
          if (item.examples != null && item.examples!.isNotEmpty) ...[
            _ExplanationListSection(
              title: l10n.examples,
              icon: Icons.list_alt,
              items: item.examples!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Synonyms
          if (item.synonyms != null && item.synonyms!.isNotEmpty) ...[
            _ExplanationChipSection(
              title: l10n.synonyms,
              icon: Icons.swap_horiz,
              items: item.synonyms!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Collocations
          if (item.collocations != null && item.collocations!.isNotEmpty) ...[
            _ExplanationChipSection(
              title: l10n.collocations,
              icon: Icons.link,
              items: item.collocations!,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Common Mistakes
          if (item.commonMistakes != null && item.commonMistakes!.isNotEmpty) ...[
            _ExplanationListSection(
              title: l10n.commonMistakes,
              icon: Icons.warning_amber_outlined,
              items: item.commonMistakes!,
              isWarning: true,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: onNext,
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  final String title;
  final IconData icon;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(content, style: AppTypography.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ExplanationListSection extends StatelessWidget {
  const _ExplanationListSection({
    required this.title,
    required this.icon,
    required this.items,
    this.isWarning = false,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppColors.warning : AppColors.primary;

    return Card(
      color: isWarning ? AppColors.warning.withAlpha(15) : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: AppTypography.labelLarge.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: AppTypography.bodyMedium.copyWith(color: color)),
                      Expanded(child: Text(item, style: AppTypography.bodyMedium)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ExplanationChipSection extends StatelessWidget {
  const _ExplanationChipSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: AppTypography.labelLarge.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: items
                  .map((item) => Chip(
                        label: Text(item, style: AppTypography.bodySmall),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
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
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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

// ---------------------------------------------------------------------------
// Voice Mode Views
// ---------------------------------------------------------------------------

class _VoiceShowWordView extends ConsumerStatefulWidget {
  const _VoiceShowWordView({
    required this.item,
    required this.currentIndex,
    required this.totalItems,
  });

  final VocabularyItem item;
  final int currentIndex;
  final int totalItems;

  @override
  ConsumerState<_VoiceShowWordView> createState() => _VoiceShowWordViewState();
}

class _VoiceShowWordViewState extends ConsumerState<_VoiceShowWordView> {
  /// Flow state: 0=initial, 1=spoken word, 2=asked knowledge, 3=waiting for meaning
  int _flowState = 0;
  String? _nativeLanguage;

  @override
  void initState() {
    super.initState();
    _setupVoiceCallbacks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceFlow();
    });
  }

  void _setupVoiceCallbacks() {
    final voiceNotifier = ref.read(voiceModeProvider.notifier);

    // Called when user responds to "do you know this word?"
    voiceNotifier.onKnowledgeResult = (knowsWord) {
      if (knowsWord) {
        // User knows the word, ask them to explain the meaning
        _askForMeaning();
      } else {
        // User doesn't know the word, tap the card to show meaning (like normal mode)
        ref.read(reviewNotifierProvider.notifier).tapWord();
      }
    };

    voiceNotifier.onMeaningResult = (transcript) {
      if (transcript.isNotEmpty) {
        // Submit the voice answer
        ref.read(reviewNotifierProvider.notifier).submitMeaning(transcript);
      }
    };

    voiceNotifier.onSpeakingComplete = () {
      if (_flowState == 1) {
        // After speaking the word, ask "do you know this word?"
        _askKnowledge();
      } else if (_flowState == 2) {
        // After asking knowledge, start listening for yes/no
        _startListeningKnowledge();
      } else if (_flowState == 3) {
        // After asking for meaning, start listening
        _startListeningForMeaning();
      }
    };
  }

  Future<void> _startVoiceFlow() async {
    final profile = await ref.read(profileProvider.future);
    _nativeLanguage = profile?.nativeLanguage ?? 'Korean';

    // Step 1: Speak the word
    final voiceNotifier = ref.read(voiceModeProvider.notifier);
    await voiceNotifier.speakWord(widget.item.word, widget.item.language);
    _flowState = 1;
  }

  Future<void> _askKnowledge() async {
    final l10n = AppLocalizations.of(context)!;
    final voiceNotifier = ref.read(voiceModeProvider.notifier);
    await voiceNotifier.askKnowledge(l10n.doYouKnowThisWord, _nativeLanguage!);
    _flowState = 2;
  }

  Future<void> _startListeningKnowledge() async {
    final voiceNotifier = ref.read(voiceModeProvider.notifier);
    await voiceNotifier.startListeningKnowledge(_nativeLanguage!);
  }

  Future<void> _askForMeaning() async {
    final l10n = AppLocalizations.of(context)!;
    final voiceNotifier = ref.read(voiceModeProvider.notifier);
    await voiceNotifier.speakFeedback(l10n.explainTheMeaning, _nativeLanguage!);
    _flowState = 3;
  }

  Future<void> _startListeningForMeaning() async {
    final voiceNotifier = ref.read(voiceModeProvider.notifier);
    await voiceNotifier.startListeningMeaning(_nativeLanguage!);
  }

  void _handleMicTap() {
    final voiceState = ref.read(voiceModeProvider);
    final voiceNotifier = ref.read(voiceModeProvider.notifier);

    if (voiceState.isListening) {
      voiceNotifier.stop();
    } else if (voiceState.phase == VoiceModePhase.listeningKnowledge ||
        _flowState == 2) {
      _startListeningKnowledge();
    } else {
      _startListeningForMeaning();
    }
  }

  void _handleKnowButton(bool knows) {
    ref.read(voiceModeProvider.notifier).stop();
    if (knows) {
      _askForMeaning();
    } else {
      ref.read(reviewNotifierProvider.notifier).tapWord();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                  value: widget.totalItems > 0
                      ? widget.currentIndex / widget.totalItems
                      : 0,
                  backgroundColor: AppColors.surfaceElevated,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(widget.item.word, style: AppTypography.displayMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.item.language,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                const VoiceModeIndicator(),
                const SizedBox(height: AppSpacing.lg),
                // Show knowledge confirmation buttons during askingKnowledge or listeningKnowledge phase
                if (voiceState.phase == VoiceModePhase.askingKnowledge ||
                    voiceState.phase == VoiceModePhase.listeningKnowledge) ...[
                  VoiceMicButton(onTap: _handleMicTap, size: 80),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.sayYesOrNo,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Manual buttons as fallback
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _handleKnowButton(false),
                        icon: const Icon(Icons.close),
                        label: Text(l10n.iDontKnowIt),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => _handleKnowButton(true),
                        icon: const Icon(Icons.check),
                        label: Text(l10n.iKnowIt),
                      ),
                    ],
                  ),
                ] else ...[
                  // Show mic button for meaning input
                  VoiceMicButton(onTap: _handleMicTap, size: 80),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    voiceState.isListening
                        ? l10n.tapToStopListening
                        : l10n.tapMicToSpeak,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                  if (voiceState.currentTranscript.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadius.mediumBorder,
                        border: Border.all(color: AppColors.textMuted.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.format_quote,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              voiceState.currentTranscript,
                              style: AppTypography.bodyMedium.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  // Manual submit button as fallback
                  if (voiceState.currentTranscript.isNotEmpty &&
                      voiceState.phase != VoiceModePhase.listeningKnowledge)
                    FilledButton(
                      onPressed: () {
                        ref.read(voiceModeProvider.notifier).stop();
                        ref
                            .read(reviewNotifierProvider.notifier)
                            .submitMeaning(voiceState.currentTranscript);
                      },
                      child: Text(l10n.submitAnswer),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceTranslationInputView extends ConsumerStatefulWidget {
  const _VoiceTranslationInputView({
    required this.item,
    required this.sentence,
    required this.wordHint,
    required this.currentIndex,
    required this.totalItems,
  });

  final VocabularyItem item;
  final String sentence;
  final String? wordHint;
  final int currentIndex;
  final int totalItems;

  @override
  ConsumerState<_VoiceTranslationInputView> createState() =>
      _VoiceTranslationInputViewState();
}

class _VoiceTranslationInputViewState
    extends ConsumerState<_VoiceTranslationInputView> {
  bool _hasSpokenSentence = false;

  @override
  void initState() {
    super.initState();
    _setupVoiceCallbacks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakSentenceAndWait();
    });
  }

  void _setupVoiceCallbacks() {
    final voiceNotifier = ref.read(voiceModeProvider.notifier);

    voiceNotifier.onTranslationResult = (transcript) {
      if (transcript.isNotEmpty) {
        ref.read(reviewNotifierProvider.notifier).submitTranslation(transcript);
      }
    };

    voiceNotifier.onSpeakingComplete = () {
      if (_hasSpokenSentence) {
        _startListeningForTranslation();
      }
    };
  }

  Future<void> _speakSentenceAndWait() async {
    final profile = await ref.read(profileProvider.future);
    final nativeLanguage = profile?.nativeLanguage ?? 'Korean';
    final voiceNotifier = ref.read(voiceModeProvider.notifier);
    await voiceNotifier.speakExample(widget.sentence, nativeLanguage);
    _hasSpokenSentence = true;
  }

  Future<void> _startListeningForTranslation() async {
    final voiceNotifier = ref.read(voiceModeProvider.notifier);
    await voiceNotifier.startListeningTranslation(widget.item.language);
  }

  void _handleMicTap() {
    final voiceState = ref.read(voiceModeProvider);
    final voiceNotifier = ref.read(voiceModeProvider.notifier);

    if (voiceState.isListening) {
      voiceNotifier.stop();
    } else {
      _startListeningForTranslation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: widget.totalItems > 0
                ? widget.currentIndex / widget.totalItems
                : 0,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.secondary,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.translateInto(widget.item.language),
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
            child: Text(widget.sentence, style: AppTypography.bodyLarge),
          ),
          if (widget.wordHint != null && widget.wordHint!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  l10n.hintUseWord(widget.wordHint!),
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const Center(child: VoiceModeIndicator()),
          const SizedBox(height: AppSpacing.lg),
          Center(child: VoiceMicButton(onTap: _handleMicTap, size: 100)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              voiceState.isListening
                  ? l10n.tapToStopListening
                  : l10n.tapMicToSpeak,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          if (voiceState.currentTranscript.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.mediumBorder,
                border: Border.all(color: AppColors.textMuted.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      voiceState.currentTranscript,
                      style: AppTypography.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                ref.read(voiceModeProvider.notifier).stop();
                ref
                    .read(reviewNotifierProvider.notifier)
                    .submitTranslation(voiceState.currentTranscript);
              },
              child: Text(l10n.submitTranslation),
            ),
          ],
        ],
      ),
    );
  }
}
