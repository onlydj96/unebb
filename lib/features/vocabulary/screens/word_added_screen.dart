import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/constants/languages.dart';
import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/core/utils/error_messages.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/ai_evaluation.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/models/word_reading.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/review/providers/review_providers.dart'
    show kPassScore;
import 'package:unebb/features/vocabulary/providers/ai_content_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/features/vocabulary/screens/word_detail_screen.dart'
    show AiContentStatusPanel;
import 'package:unebb/shared/widgets/app_empty_state.dart';
import 'package:unebb/shared/widgets/app_notice.dart';
import 'package:unebb/shared/widgets/brand_mark.dart';
import 'package:unebb/shared/widgets/feedback_card.dart';
import 'package:unebb/shared/widgets/labels.dart';
import 'package:unebb/shared/widgets/phase_switcher.dart';
import 'package:unebb/shared/widgets/score_ring.dart';
import 'package:unebb/shared/widgets/word_content.dart';

/// Steps of the optional practice right after adding a word.
enum WordAddedPhase {
  showExplanation,
  generatingTranslation,
  translationInput,
  evaluatingTranslation,
  showResult,
  error,
}

/// Screen shown after a word is added, allowing immediate practice.
///
/// The word itself comes from [vocabularyItemProvider], so the explanation
/// appears as soon as the background generation finishes (or offers a retry
/// if it failed) — no matter which finishes first.
class WordAddedScreen extends ConsumerStatefulWidget {
  const WordAddedScreen({super.key, required this.vocabularyId});

  final String vocabularyId;

  @override
  ConsumerState<WordAddedScreen> createState() => _WordAddedScreenState();
}

class _WordAddedScreenState extends ConsumerState<WordAddedScreen> {
  WordAddedPhase _phase = WordAddedPhase.showExplanation;
  String? _translationSentence;
  String? _wordHint;
  AiEvaluation? _evaluation;
  Object? _error;

  final _translationController = TextEditingController();

  @override
  void dispose() {
    _translationController.dispose();
    super.dispose();
  }

  void _setPhase(WordAddedPhase phase, [void Function()? update]) {
    if (!mounted) return;
    setState(() {
      update?.call();
      _phase = phase;
    });
  }

  /// Falls back to the default language when the profile cannot be loaded
  /// (a failed profile fetch must not break practice).
  Future<String> _nativeLanguage() async {
    try {
      final profile = await ref.read(profileProvider.future);
      return profile?.nativeLanguage ?? SupportedLanguages.defaultNative;
    } catch (e) {
      AppLogger.warning('Profile unavailable for practice', details: e);
      ref.invalidate(profileProvider);
      return SupportedLanguages.defaultNative;
    }
  }

  Future<void> _startTranslationPractice(VocabularyItem item) async {
    // A double tap (or a tap on the fading view) must not request two
    // questions — the later one would replace the sentence being translated.
    if (_phase != WordAddedPhase.showExplanation) return;
    _setPhase(WordAddedPhase.generatingTranslation);
    try {
      final question =
          await ref.read(aiQuestionServiceProvider).generateTranslationQuestion(
                word: item.word,
                language: item.language,
                definition: item.definition ?? '',
                usage: item.usage ?? '',
                examples: item.examples ?? const [],
                nativeLanguage: await _nativeLanguage(),
              );
      _setPhase(WordAddedPhase.translationInput, () {
        _translationSentence = question.sentence;
        _wordHint = question.wordHint;
      });
    } catch (e, st) {
      AppLogger.error('Practice question failed', error: e, stackTrace: st);
      _setPhase(WordAddedPhase.error, () => _error = e);
    }
  }

  Future<void> _submitTranslation(VocabularyItem item) async {
    final userAnswer = _translationController.text.trim();
    if (userAnswer.isEmpty || _phase != WordAddedPhase.translationInput) {
      return;
    }
    _setPhase(WordAddedPhase.evaluatingTranslation);
    try {
      final evaluation =
          await ref.read(aiEvaluationServiceProvider).evaluateAnswer(
                word: item.word,
                language: item.language,
                definition: item.definition ?? '',
                usage: item.usage ?? '',
                userAnswer: userAnswer,
                answerType: 'text',
                evalType: 'translation',
                questionContext: _translationSentence,
                nativeLanguage: await _nativeLanguage(),
              );
      _setPhase(WordAddedPhase.showResult, () => _evaluation = evaluation);
    } catch (e, st) {
      AppLogger.error('Practice evaluation failed', error: e, stackTrace: st);
      _setPhase(WordAddedPhase.error, () => _error = e);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final itemAsync = ref.watch(vocabularyItemProvider(widget.vocabularyId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wordAddedTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.done,
          onPressed: _close,
        ),
      ),
      body: itemAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorView(l10n, e),
        data: (item) {
          if (item == null) return _buildErrorView(l10n, null);
          return PhaseSwitcher(
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: switch (_phase) {
                WordAddedPhase.showExplanation =>
                  _buildExplanationView(l10n, item),
                WordAddedPhase.generatingTranslation => _buildLoadingView(
                    item.word, l10n.preparingTranslationExercise),
                WordAddedPhase.translationInput =>
                  _buildTranslationInputView(l10n, item),
                WordAddedPhase.evaluatingTranslation =>
                  _buildLoadingView(item.word, l10n.evaluatingYourTranslation),
                WordAddedPhase.showResult => _buildResultView(l10n),
                WordAddedPhase.error => _buildErrorView(l10n, _error),
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingView(String word, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word,
              style: AppTypography.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            const BrandPulse(size: 52),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Scrollable content with the primary actions pinned to the bottom.
  Widget _withActions({
    required List<Widget> children,
    required Widget actions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.md),
            child: actions,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationView(AppLocalizations l10n, VocabularyItem item) {
    final ready = hasAiContent(item);
    final pronunciation = item.displayReading;

    return _withActions(
      children: [
        AppNotice(
          tone: AppTone.success,
          icon: Icons.check_circle_rounded,
          message: l10n.wordAddedSuccess(item.word),
          dense: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: TagPill(item.language, icon: Icons.translate_rounded),
        ),
        const SizedBox(height: 12),
        Text(item.word, style: AppTypography.displayLarge),
        if (pronunciation != null) ...[
          const SizedBox(height: 6),
          Text(pronunciation, style: AppTypography.pronunciation),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (ready)
          _ExplanationCard(item: item)
        else
          AiContentStatusPanel(item: item),
      ],
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _close,
              child: Text(l10n.done),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              // Practice needs the definition for the exercise.
              onPressed: ready ? () => _startTranslationPractice(item) : null,
              child: Text(l10n.practiceNow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationInputView(
    AppLocalizations l10n,
    VocabularyItem item,
  ) {
    final hint = _wordHint;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.lg),
      child: Column(
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
                  _translationSentence ?? '',
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
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _translationController,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.yourTranslationHint(item.language),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitTranslation(item),
          ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _translationController,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().isNotEmpty
                  ? () => _submitTranslation(item)
                  : null,
              child: Text(l10n.submitTranslation),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(AppLocalizations l10n) {
    final evaluation = _evaluation;
    if (evaluation == null) return const SizedBox.shrink();
    final isGood = evaluation.overallScore >= kPassScore;

    return _withActions(
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: ScoreRing(
            value: evaluation.overallScore,
            color: isGood ? AppColors.success : AppColors.warning,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          isGood ? l10n.verdictPass : l10n.verdictFail,
          style: AppTypography.headingMedium.copyWith(
            color: isGood ? AppColors.successText : AppColors.warningText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (evaluation.feedback.isNotEmpty ||
            (evaluation.weakPoint?.isNotEmpty ?? false))
          FeedbackCard(
            feedback: evaluation.feedback,
            weakPoint: evaluation.weakPoint,
          ),
      ],
      actions: FilledButton(onPressed: _close, child: Text(l10n.done)),
    );
  }

  Widget _buildErrorView(AppLocalizations l10n, Object? error) {
    final inPractice = error != null && _phase == WordAddedPhase.error;
    return AppEmptyState(
      icon: error == null
          ? Icons.search_off_rounded
          : Icons.error_outline_rounded,
      tone: error == null ? AppTone.neutral : AppTone.error,
      title:
          error == null ? l10n.wordNotFound : friendlyErrorMessage(l10n, error),
      actions: [
        if (inPractice)
          OutlinedButton(
            onPressed: () => _setPhase(WordAddedPhase.showExplanation),
            child: Text(l10n.back),
          )
        else
          FilledButton(onPressed: _close, child: Text(l10n.back)),
      ],
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.largeBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l10n.definition),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.definition!,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item.explanation?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.wordExplanation),
            const SizedBox(height: AppSpacing.sm),
            Text(item.explanation!, style: AppTypography.bodyMedium),
          ],
          if (item.examples?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.examples),
            const SizedBox(height: AppSpacing.sm),
            QuoteList(items: item.examples!.take(3).toList()),
          ],
          if (item.synonyms?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.synonyms),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: [
                for (final synonym in item.synonyms!.take(5)) TagPill(synonym),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
