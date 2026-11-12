import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_theme.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/core/utils/error_messages.dart';
import 'package:unebb/domain/models/ai_evaluation.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/models/word_reading.dart';
import 'package:unebb/features/review/providers/review_providers.dart';
import 'package:unebb/features/review/providers/voice_mode_provider.dart';
import 'package:unebb/features/review/widgets/voice_mode_widgets.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';
import 'package:unebb/shared/widgets/brand_mark.dart';
import 'package:unebb/shared/widgets/feedback_card.dart';
import 'package:unebb/shared/widgets/labels.dart';
import 'package:unebb/shared/widgets/memory_indicator.dart';
import 'package:unebb/shared/widgets/phase_switcher.dart';
import 'package:unebb/shared/widgets/score_ring.dart';
import 'package:unebb/shared/widgets/word_content.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.mode = 'due', this.limit, this.deckId});

  final String mode;
  final int? limit;
  final String? deckId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with WidgetsBindingObserver {
  final _answerController = TextEditingController();
  bool _hasCheckedSavedProgress = false;

  /// Captured up front: `ref` cannot be used inside [dispose] (the element
  /// is already unmounted), which made the old "save progress on close"
  /// throw every time and skip the rest of dispose.
  late final ReviewNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(reviewNotifierProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkForSavedProgress();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Save progress when the user closes the screen mid-session.
    _notifier.saveProgress();
    _answerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _notifier.saveProgress();
    }
  }

  Future<void> _checkForSavedProgress() async {
    if (_hasCheckedSavedProgress) return;
    _hasCheckedSavedProgress = true;

    final notifier = _notifier;
    final savedProgress = notifier.getSavedProgress(
      mode: widget.mode,
      limit: widget.limit,
      deckId: widget.deckId,
    );

    if (savedProgress != null && savedProgress.completedCount > 0) {
      final shouldResume = await _showResumeDialog(savedProgress);
      if (!mounted) return;
      if (shouldResume == null) {
        // Dismissed (e.g. Android back): leave and keep the saved progress
        // instead of treating it as "start new" and deleting it.
        _close();
        return;
      }
      if (shouldResume) {
        await notifier.resumeSession(savedProgress);
        return;
      }
      await notifier.clearSavedProgress();
    }
    await notifier.startSession(
      mode: widget.mode,
      limit: widget.limit,
      deckId: widget.deckId,
    );
  }

  Future<bool?> _showResumeDialog(ReviewSessionProgress progress) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.resumeSessionTitle),
        content: Text(
          l10n.resumeSessionMessage(
            progress.remainingCount,
            progress.completedCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.startNewSession),
          ),
          FilledButton(
            style: AppTheme.compactButton,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.continueSession),
          ),
        ],
      ),
    );
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _submit(ValueChanged<String> action) {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    _answerController.clear();
    action(answer);
  }

  static const _outsideSession = {
    ReviewPhase.loading,
    ReviewPhase.empty,
    ReviewPhase.complete,
  };

  bool _inSession(ReviewUiState state) =>
      state.session != null && !_outsideSession.contains(state.phase);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewNotifierProvider);
    final voiceEnabled =
        ref.watch(voiceModeProvider.select((s) => s.isEnabled));
    final l10n = context.l10n;
    final notifier = _notifier;
    final item = state.currentItem;

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(state),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.back,
          onPressed: _close,
        ),
        actions: const [VoiceModeToggle(), SizedBox(width: AppSpacing.sm)],
        bottom: _inSession(state)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _SessionProgressBar(progress: state.sessionProgress),
                ),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        // Views fading out ignore taps (a second tap on the old "Next word"
        // button used to skip a word) without being remounted.
        layoutBuilder: PhaseSwitcher.layoutBuilder,
        child: KeyedSubtree(
          key: ValueKey('${state.phase}-${state.currentIndex}-$voiceEnabled'),
          child: switch (state.phase) {
            ReviewPhase.loading => const _BusyView(word: '', message: ''),
            ReviewPhase.empty => _EmptyView(
                onBack: _close,
                onReviewAll: state.sessionMode == 'due'
                    ? () => notifier.startSession(
                          mode: 'all',
                          limit: state.sessionLimit,
                          deckId: state.sessionDeckId,
                        )
                    : null,
              ),
            ReviewPhase.showWord ||
            ReviewPhase.askKnowledge when voiceEnabled && item != null =>
              _VoiceShowWordView(item: item),
            ReviewPhase.showWord when item != null => _FlashCardFront(
                item: item,
                onTap: notifier.tapWord,
              ),
            ReviewPhase.askKnowledge when item != null => _AskKnowledgeView(
                item: item,
                onKnow: notifier.answerKnowWord,
                onDontKnow: notifier.answerDontKnowWord,
              ),
            ReviewPhase.generatingExplanation => _BusyView(
                word: item?.word ?? '',
                message: l10n.generatingExplanation,
              ),
            ReviewPhase.showExplanation when item != null => _ExplanationView(
                item: item,
                onNext: notifier.nextAfterExplanation,
              ),
            ReviewPhase.meaningInput when item != null => _MeaningInputView(
                item: item,
                controller: _answerController,
                onSubmit: () => _submit(notifier.submitMeaning),
              ),
            ReviewPhase.evaluatingMeaning => _BusyView(
                word: item?.word ?? '',
                message: l10n.checkingYourAnswer,
              ),
            ReviewPhase.meaningFailed
                when item != null && state.meaningEvaluation != null =>
              _MeaningFailedView(
                item: item,
                evaluation: state.meaningEvaluation!,
                onNext: notifier.nextAfterFailed,
              ),
            ReviewPhase.generatingTranslation => _BusyView(
                word: item?.word ?? '',
                message: l10n.preparingTranslationExercise,
              ),
            ReviewPhase.translationInput when voiceEnabled && item != null =>
              _VoiceTranslationInputView(
                item: item,
                sentence: state.translationSentence ?? '',
                wordHint: state.wordHint,
              ),
            ReviewPhase.translationInput when item != null =>
              _TranslationInputView(
                item: item,
                sentence: state.translationSentence ?? '',
                wordHint: state.wordHint,
                controller: _answerController,
                onSubmit: () => _submit(notifier.submitTranslation),
              ),
            ReviewPhase.evaluatingTranslation => _BusyView(
                word: item?.word ?? '',
                message: l10n.evaluatingYourTranslation,
              ),
            ReviewPhase.showResult
                when item != null && state.meaningEvaluation != null =>
              _ResultView(
                item: item,
                meaningEvaluation: state.meaningEvaluation!,
                translationEvaluation: state.translationEvaluation,
                combinedScore: state.combinedScore ??
                    state.meaningEvaluation!.overallScore,
                detectedPatterns: state.allDetectedPatterns,
                previousStrength: state.previousStrength,
                updatedStrength: state.updatedStrength,
                isLast: state.currentIndex + 1 >= state.totalItems,
                onNext: notifier.nextWord,
              ),
            ReviewPhase.complete => _CompleteView(
                correctCount: state.sessionCorrectCount,
                totalItems: state.sessionTotalCount,
                onDone: _close,
              ),
            ReviewPhase.error => _ErrorView(
                message: state.error == null
                    ? l10n.errorGeneric
                    : friendlyErrorMessage(l10n, state.error!),
                onRetry: notifier.retry,
                onSkip: state.canRetryStep ? notifier.nextWord : null,
              ),
            // A word-dependent phase without a word cannot be shown.
            _ => const _BusyView(word: '', message: ''),
          },
        ),
      ),
    );
  }

  Widget _buildTitle(ReviewUiState state) {
    if (!_inSession(state)) {
      return Text(context.l10n.review);
    }
    return Text(
      '${state.sessionPosition} / ${state.sessionTotalCount}',
      style: AppTypography.headingSmall.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SessionProgressBar extends StatelessWidget {
  const _SessionProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: AppRadius.fullBorder,
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: AppColors.surfaceElevated,
          color: AppColors.cocoa,
        ),
      ),
    );
  }
}

/// Page layout for a review step: scrollable content, optionally centred
/// vertically, with the primary actions pinned above the bottom edge.
class _ReviewPage extends StatelessWidget {
  const _ReviewPage({
    required this.children,
    this.actions,
    this.centered = false,
  });

  final List<Widget> children;
  final Widget? actions;
  final bool centered;

  static const _vPadding = AppSpacing.md + AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    AppSpacing.md,
                    20,
                    AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - _vPadding)
                          .clamp(0.0, double.infinity),
                    ),
                    child: Column(
                      mainAxisAlignment: centered
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
            if (actions != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    AppSpacing.sm,
                    20,
                    AppSpacing.md,
                  ),
                  child: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The flash card: the word set large on a sheet of paper.
class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.item,
    required this.children,
    this.onTap,
  });

  final VocabularyItem item;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      elevation: 3,
      shadowColor: AppColors.cocoa.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xLargeBorder,
        side: const BorderSide(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TagPill(item.language),
              const SizedBox(height: AppSpacing.xl),
              Text(
                item.word,
                style: AppTypography.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// "I don't know it" / "I know it": the two accents of the palette — the
/// ebb (crimson) and the flow (mint).
class _KnowButtons extends StatelessWidget {
  const _KnowButtons({required this.onKnow, required this.onDontKnow});

  final VoidCallback onKnow;
  final VoidCallback onDontKnow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _AnswerTile(
              icon: Icons.close_rounded,
              label: l10n.iDontKnowIt,
              background: AppColors.errorSoft,
              foreground: AppColors.error,
              onTap: onDontKnow,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AnswerTile(
              icon: Icons.check_rounded,
              label: l10n.iKnowIt,
              background: AppColors.mint,
              foreground: AppColors.cocoa,
              onTap: onKnow,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: AppRadius.largeBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(color: foreground),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary action enabled only when the answer is not blank.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.controller,
    required this.label,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => FilledButton(
        onPressed: value.text.trim().isEmpty ? null : onSubmit,
        child: Text(label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flash card front / knowledge question
// ---------------------------------------------------------------------------

class _FlashCardFront extends StatelessWidget {
  const _FlashCardFront({required this.item, required this.onTap});

  final VocabularyItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ReviewPage(
      centered: true,
      children: [
        _WordCard(
          item: item,
          onTap: onTap,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  context.l10n.tapToAnswer,
                  style: AppTypography.labelMedium,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _AskKnowledgeView extends StatelessWidget {
  const _AskKnowledgeView({
    required this.item,
    required this.onKnow,
    required this.onDontKnow,
  });

  final VocabularyItem item;
  final VoidCallback onKnow;
  final VoidCallback onDontKnow;

  @override
  Widget build(BuildContext context) {
    return _ReviewPage(
      centered: true,
      actions: _KnowButtons(onKnow: onKnow, onDontKnow: onDontKnow),
      children: [
        _WordCard(
          item: item,
          children: [
            Text(
              context.l10n.doYouKnowThisWord,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Explanation (after "I don't know")
// ---------------------------------------------------------------------------

class _ExplanationView extends StatelessWidget {
  const _ExplanationView({required this.item, required this.onNext});

  final VocabularyItem item;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasContent = item.definition?.isNotEmpty ?? false;
    final pronunciation = item.displayReading;

    final sections = <(String, IconData, Color, Widget)>[
      if (item.definition?.isNotEmpty ?? false)
        (
          l10n.definition,
          Icons.menu_book_outlined,
          AppColors.textSecondary,
          Text(
            item.definition!,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      if (item.explanation?.isNotEmpty ?? false)
        (
          l10n.meaning,
          Icons.lightbulb_outline_rounded,
          AppColors.textSecondary,
          Text(item.explanation!, style: AppTypography.bodyMedium),
        ),
      if (item.usage?.isNotEmpty ?? false)
        (
          l10n.usage,
          Icons.format_quote_rounded,
          AppColors.textSecondary,
          Text(item.usage!, style: AppTypography.bodyMedium),
        ),
      if (item.examples?.isNotEmpty ?? false)
        (
          l10n.examples,
          Icons.notes_rounded,
          AppColors.textSecondary,
          QuoteList(items: item.examples!),
        ),
      if (item.synonyms?.isNotEmpty ?? false)
        (
          l10n.synonyms,
          Icons.swap_horiz_rounded,
          AppColors.textSecondary,
          WordChips(items: item.synonyms!),
        ),
      if (item.collocations?.isNotEmpty ?? false)
        (
          l10n.collocations,
          Icons.link_rounded,
          AppColors.textSecondary,
          WordChips(items: item.collocations!),
        ),
      if (item.commonMistakes?.isNotEmpty ?? false)
        (
          l10n.commonMistakes,
          Icons.warning_amber_rounded,
          AppColors.error,
          MistakeList(items: item.commonMistakes!),
        ),
    ];

    return _ReviewPage(
      actions: FilledButton(onPressed: onNext, child: Text(l10n.gotIt)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TagPill(item.language, icon: Icons.translate_rounded),
        ),
        const SizedBox(height: 12),
        Text(item.word, style: AppTypography.displayMedium),
        if (pronunciation != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(pronunciation, style: AppTypography.pronunciation),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!hasContent)
          Text(
            l10n.aiContentMissing,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        for (final (title, icon, color, child) in sections) ...[
          SectionLabel(title, icon: icon, color: color),
          const SizedBox(height: 10),
          child,
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Meaning input
// ---------------------------------------------------------------------------

class _MeaningInputView extends StatelessWidget {
  const _MeaningInputView({
    required this.item,
    required this.controller,
    required this.onSubmit,
  });

  final VocabularyItem item;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ReviewPage(
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(child: TagPill(item.language)),
        const SizedBox(height: AppSpacing.md),
        Text(
          item.word,
          style: AppTypography.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(l10n.whatIsTheMeaning, style: AppTypography.headingSmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(hintText: l10n.enterMeaningHint),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: AppSpacing.md),
        _SubmitButton(
          controller: controller,
          label: l10n.submitAnswer,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Busy view — shared for all loading phases
// ---------------------------------------------------------------------------

/// The word with the brand mark breathing underneath while the AI works.
class _BusyView extends StatelessWidget {
  const _BusyView({required this.word, required this.message});

  final String word;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (word.isNotEmpty) ...[
              Text(
                word,
                style: AppTypography.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            const BrandPulse(size: 52),
            if (message.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reading of the word, centred under it. Only used after the answer was
/// given — on question screens the reading would give the answer away.
class _ReadingLine extends StatelessWidget {
  const _ReadingLine(this.item);

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    final reading = item.displayReading;
    if (reading == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        reading,
        style: AppTypography.pronunciation,
        textAlign: TextAlign.center,
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
    final l10n = context.l10n;
    return _ReviewPage(
      actions: FilledButton(onPressed: onNext, child: Text(l10n.nextWord)),
      children: [
        const SizedBox(height: AppSpacing.sm),
        const Center(
          child: ToneBadge(Icons.close_rounded, AppTone.error, size: 64),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.answerIncorrect,
          style: AppTypography.headingMedium.copyWith(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          item.word,
          style: AppTypography.displaySmall,
          textAlign: TextAlign.center,
        ),
        _ReadingLine(item),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: AppRadius.largeBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(
                l10n.correctMeaning,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.successText,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.definition ?? '',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FeedbackCard(
          feedback: evaluation.feedback,
          weakPoint: evaluation.weakPoint,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Translation input
// ---------------------------------------------------------------------------

class _TranslationPrompt extends StatelessWidget {
  const _TranslationPrompt({
    required this.item,
    required this.sentence,
    required this.wordHint,
  });

  final VocabularyItem item;
  final String sentence;
  final String? wordHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = wordHint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l10n.translateInto(item.language),
          icon: Icons.translate_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.largeBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sentence,
                style: AppTypography.headingMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              if (hint != null && hint.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                TagPill(
                  l10n.hintUseWord(hint),
                  icon: Icons.lightbulb_outline_rounded,
                  tone: AppTone.warning,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TranslationInputView extends StatelessWidget {
  const _TranslationInputView({
    required this.item,
    required this.sentence,
    required this.wordHint,
    required this.controller,
    required this.onSubmit,
  });

  final VocabularyItem item;
  final String sentence;
  final String? wordHint;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ReviewPage(
      children: [
        _TranslationPrompt(
          item: item,
          sentence: sentence,
          wordHint: wordHint,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: controller,
          maxLines: 4,
          minLines: 2,
          autofocus: true,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: l10n.yourTranslationHint(item.language),
            alignLabelWithHint: true,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: AppSpacing.md),
        _SubmitButton(
          controller: controller,
          label: l10n.submitTranslation,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result view — combined score + breakdown + pattern badges
// ---------------------------------------------------------------------------

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.item,
    required this.meaningEvaluation,
    required this.translationEvaluation,
    required this.combinedScore,
    required this.detectedPatterns,
    required this.previousStrength,
    required this.updatedStrength,
    required this.isLast,
    required this.onNext,
  });

  final VocabularyItem item;
  final AiEvaluation meaningEvaluation;
  final AiEvaluation? translationEvaluation;
  final double combinedScore;
  final List<String> detectedPatterns;
  final double previousStrength;
  final double updatedStrength;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final passed = combinedScore >= kPassScore;
    final translation = translationEvaluation;
    final primaryFeedback = translation ?? meaningEvaluation;

    // The meaning check only grades the meaning; the translation step grades
    // meaning preservation, use of the word, grammar and naturalness.
    final rows = <(String, double)>[
      (l10n.meaning, meaningEvaluation.overallScore),
      if (translation != null) ...[
        (l10n.translation, translation.meaningScore),
        (l10n.wordUsage, translation.usageScore),
        (l10n.grammar, translation.grammarScore),
        (l10n.naturalness, translation.exampleScore),
      ],
    ];

    return _ReviewPage(
      actions: FilledButton(
        onPressed: onNext,
        child: Text(isLast ? l10n.finish : l10n.nextWord),
      ),
      children: [
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: ScoreRing(
            value: combinedScore,
            color: passed ? AppColors.success : AppColors.error,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          passed ? l10n.verdictPass : l10n.verdictFail,
          style: AppTypography.headingMedium.copyWith(
            color: passed ? AppColors.successText : AppColors.error,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          item.word,
          style: AppTypography.word,
          textAlign: TextAlign.center,
        ),
        _ReadingLine(item),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: MemoryStrengthDelta(
            previous: previousStrength,
            updated: updatedStrength,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FeedbackCard(
          feedback: primaryFeedback.feedback,
          weakPoint: primaryFeedback.weakPoint,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 2,
              vertical: 14,
            ),
            child: Column(
              children: [
                for (final (label, score) in rows) _ScoreRow(label, score),
              ],
            ),
          ),
        ),
        if (detectedPatterns.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _PatternBadges(patterns: detectedPatterns),
        ],
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: AppTypography.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.fullBorder,
              child: LinearProgressIndicator(
                value: score.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceElevated,
                color:
                    score >= kPassScore ? AppColors.success : AppColors.error,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          SizedBox(
            width: 40,
            child: Text(
              '${(score * 100).round()}%',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
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
        SectionLabel(
          context.l10n.patternsToWatch,
          icon: Icons.warning_amber_rounded,
          color: AppColors.warningText,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs + 2,
          runSpacing: AppSpacing.xs + 2,
          children: [
            for (final pattern in patterns.toSet())
              TagPill(pattern, tone: AppTone.warning),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / Complete / Error views
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBack, this.onReviewAll});

  final VoidCallback onBack;

  /// Offered when only due words were requested and none are due.
  final VoidCallback? onReviewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: Icons.check_rounded,
      tone: AppTone.success,
      title: l10n.allCaughtUp,
      message: l10n.noDueWords,
      actions: [
        if (onReviewAll != null)
          FilledButton(
              onPressed: onReviewAll, child: Text(l10n.reviewAllInstead)),
        OutlinedButton(onPressed: onBack, child: Text(l10n.back)),
      ],
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
    final l10n = context.l10n;
    final ratio = totalItems == 0 ? 0.0 : correctCount / totalItems;
    return AppEmptyState(
      leading: Column(
        children: [
          const BrandMark(size: 40),
          const SizedBox(height: AppSpacing.lg),
          ScoreRing(
            value: ratio,
            color: AppColors.success,
            label: '$correctCount/$totalItems',
          ),
        ],
      ),
      title: l10n.sessionComplete,
      message: l10n.correctOutOf(correctCount, totalItems),
      actions: [FilledButton(onPressed: onDone, child: Text(l10n.done))],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.onSkip,
  });

  final String message;
  final VoidCallback onRetry;

  /// Skips the failed word (only when the session itself is fine).
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      tone: AppTone.error,
      title: message,
      actions: [
        FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        if (onSkip != null)
          OutlinedButton(onPressed: onSkip, child: Text(l10n.skipWord)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Voice Mode Views
// ---------------------------------------------------------------------------

class _VoiceShowWordView extends ConsumerStatefulWidget {
  const _VoiceShowWordView({required this.item});

  final VocabularyItem item;

  @override
  ConsumerState<_VoiceShowWordView> createState() => _VoiceShowWordViewState();
}

enum _VoiceStep { initial, spokeWord, askedKnowledge, askedMeaning }

class _VoiceShowWordViewState extends ConsumerState<_VoiceShowWordView> {
  _VoiceStep _step = _VoiceStep.initial;
  String _nativeLanguage = 'Korean';

  // Captured in initState: `ref` is unusable in dispose.
  late final VoiceModeNotifier _voice;
  late final ReviewNotifier _review;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceModeProvider.notifier);
    _review = ref.read(reviewNotifierProvider.notifier);
    _voice.bindCallbacks(
      this,
      onKnowledgeResult: (knows) => knows ? _askForMeaning() : _dontKnow(),
      onMeaningResult: (transcript) {
        if (transcript.isNotEmpty) _review.submitMeaning(transcript);
      },
      onSpeakingComplete: () {
        switch (_step) {
          case _VoiceStep.spokeWord:
            _askKnowledge();
          case _VoiceStep.askedKnowledge:
            _voice.startListeningKnowledge(_nativeLanguage);
          case _VoiceStep.askedMeaning:
            _voice.startListeningMeaning(_nativeLanguage);
          case _VoiceStep.initial:
            break;
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startVoiceFlow());
  }

  @override
  void dispose() {
    // Only clears callbacks this view registered (see bindCallbacks).
    _voice.clearCallbacks(this);
    super.dispose();
  }

  Future<void> _startVoiceFlow() async {
    if (!mounted) return;
    _nativeLanguage = ref.read(reviewNotifierProvider).nativeLanguage;
    _step = _VoiceStep.spokeWord;
    await _voice.speakWord(widget.item.word, widget.item.language);
  }

  Future<void> _askKnowledge() async {
    if (!mounted) return;
    _step = _VoiceStep.askedKnowledge;
    await _voice.askKnowledge(context.l10n.doYouKnowThisWord, _nativeLanguage);
  }

  Future<void> _askForMeaning() async {
    if (!mounted) return;
    _review.prefetchTranslation();
    _step = _VoiceStep.askedMeaning;
    await _voice.speakFeedback(context.l10n.explainTheMeaning, _nativeLanguage);
  }

  /// "Don't know" grades the word and shows its explanation. (It used to
  /// only flip the card, which re-rendered this view and asked again in an
  /// endless loop.)
  void _dontKnow() {
    unawaited(_voice.stop());
    _review.answerDontKnowWord();
  }

  void _handleMicTap() {
    final voiceState = ref.read(voiceModeProvider);
    if (voiceState.isListening) {
      _voice.stop();
    } else if (_step == _VoiceStep.askedKnowledge) {
      _voice.startListeningKnowledge(_nativeLanguage);
    } else {
      _voice.startListeningMeaning(_nativeLanguage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = context.l10n;
    final askingKnowledge =
        voiceState.phase == VoiceModePhase.askingKnowledge ||
            voiceState.phase == VoiceModePhase.listeningKnowledge;

    return _ReviewPage(
      centered: true,
      actions: askingKnowledge
          ? _KnowButtons(
              onKnow: () {
                unawaited(_voice.stop());
                _askForMeaning();
              },
              onDontKnow: _dontKnow,
            )
          : null,
      children: [
        _WordCard(
          item: widget.item,
          children: [
            const VoiceModeIndicator(),
            const SizedBox(height: AppSpacing.lg),
            VoiceMicButton(onTap: _handleMicTap, size: 80),
            const SizedBox(height: AppSpacing.md),
            Text(
              askingKnowledge
                  ? l10n.sayYesOrNo
                  : voiceState.isListening
                      ? l10n.tapToStopListening
                      : l10n.tapMicToSpeak,
              style: AppTypography.labelMedium,
            ),
            if (!askingKnowledge) ...[
              const SizedBox(height: AppSpacing.lg),
              const VoiceTranscriptDisplay(),
              if (voiceState.currentTranscript.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () {
                    final transcript = voiceState.currentTranscript;
                    unawaited(_voice.stop());
                    _review.submitMeaning(transcript);
                  },
                  child: Text(l10n.submitAnswer),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }
}

class _VoiceTranslationInputView extends ConsumerStatefulWidget {
  const _VoiceTranslationInputView({
    required this.item,
    required this.sentence,
    required this.wordHint,
  });

  final VocabularyItem item;
  final String sentence;
  final String? wordHint;

  @override
  ConsumerState<_VoiceTranslationInputView> createState() =>
      _VoiceTranslationInputViewState();
}

class _VoiceTranslationInputViewState
    extends ConsumerState<_VoiceTranslationInputView> {
  bool _hasSpokenSentence = false;

  // Captured in initState: `ref` is unusable in dispose.
  late final VoiceModeNotifier _voice;
  late final ReviewNotifier _review;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceModeProvider.notifier);
    _review = ref.read(reviewNotifierProvider.notifier);
    _voice.bindCallbacks(
      this,
      onTranslationResult: (transcript) {
        if (transcript.isNotEmpty) _review.submitTranslation(transcript);
      },
      onSpeakingComplete: () {
        if (_hasSpokenSentence) _startListening();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakSentence());
  }

  @override
  void dispose() {
    _voice.clearCallbacks(this);
    super.dispose();
  }

  Future<void> _speakSentence() async {
    if (!mounted) return;
    final nativeLanguage = ref.read(reviewNotifierProvider).nativeLanguage;
    _hasSpokenSentence = true;
    await _voice.speakExample(widget.sentence, nativeLanguage);
  }

  Future<void> _startListening() =>
      _voice.startListeningTranslation(widget.item.language);

  void _handleMicTap() {
    if (ref.read(voiceModeProvider).isListening) {
      _voice.stop();
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = context.l10n;

    return _ReviewPage(
      children: [
        _TranslationPrompt(
          item: widget.item,
          sentence: widget.sentence,
          wordHint: widget.wordHint,
        ),
        const SizedBox(height: AppSpacing.xl),
        const Center(child: VoiceModeIndicator()),
        const SizedBox(height: AppSpacing.lg),
        Center(child: VoiceMicButton(onTap: _handleMicTap, size: 96)),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            voiceState.isListening
                ? l10n.tapToStopListening
                : l10n.tapMicToSpeak,
            style: AppTypography.labelMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const VoiceTranscriptDisplay(),
        if (voiceState.currentTranscript.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              final transcript = voiceState.currentTranscript;
              unawaited(_voice.stop());
              _review.submitTranslation(transcript);
            },
            child: Text(l10n.submitTranslation),
          ),
        ],
      ],
    );
  }
}
