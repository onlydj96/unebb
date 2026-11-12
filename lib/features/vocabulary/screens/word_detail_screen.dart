import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/vocabulary/providers/ai_content_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/shared/utils/app_snackbar.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';
import 'package:unebb/shared/widgets/app_notice.dart';
import 'package:unebb/shared/widgets/labels.dart';
import 'package:unebb/shared/widgets/memory_indicator.dart';
import 'package:unebb/shared/widgets/word_content.dart';

/// Displays full details of a single vocabulary item, including AI content.
class WordDetailScreen extends ConsumerWidget {
  const WordDetailScreen({super.key, required this.wordId});

  final String wordId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VocabularyItem item,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWordTitle),
        content: Text(l10n.deleteWordMessage(item.word)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(vocabularyNotifierProvider.notifier).deleteWord(item.id);
      if (context.mounted) context.pop();
    } catch (e, st) {
      AppLogger.error('Deleting word failed', error: e, stackTrace: st);
      if (context.mounted) AppSnackBar.showError(context, l10n.deleteFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final itemAsync = ref.watch(vocabularyItemProvider(wordId));
    final item = itemAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (item != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editWord,
              onPressed: () async {
                final deleted =
                    await context.push<bool>('/words/${item.id}/edit');
                // The word was deleted from the edit screen: leave as well.
                if (deleted == true && context.mounted) context.pop();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.delete,
              onPressed: () => _confirmDelete(context, ref, item),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
      body: itemAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          tone: AppTone.error,
          title: l10n.errorLoadingWords,
        ),
        data: (item) => item == null
            ? AppEmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.wordNotFound,
              )
            : _WordDetailBody(item: item),
      ),
    );
  }
}

class _WordDetailBody extends ConsumerWidget {
  const _WordDetailBody({required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final memory =
        ref.watch(memoryStatesMapNotifierProvider).valueOrNull?[item.id];
    final pronunciation = item.pronunciation;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TagPill(item.language, icon: Icons.translate_rounded),
          const SizedBox(height: 14),
          Text(item.word, style: AppTypography.displayLarge),
          if (pronunciation != null && pronunciation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(pronunciation, style: AppTypography.pronunciation),
          ],
          if (memory != null && memory.reviewCount > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: MemoryIndicator(
                  strength: memory.memoryStrength,
                  showLabel: true,
                  height: 6,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (!hasAiContent(item))
            AiContentStatusPanel(item: item)
          else ...[
            _Section(
              title: l10n.definition,
              child: Text(
                item.definition!,
                style: AppTypography.bodyLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (item.explanation?.isNotEmpty ?? false)
              _Section(
                title: l10n.explanation,
                child: Text(item.explanation!, style: AppTypography.bodyLarge),
              ),
            if (item.usage?.isNotEmpty ?? false)
              _Section(
                title: l10n.usage,
                child: Text(item.usage!, style: AppTypography.bodyLarge),
              ),
            if (item.examples?.isNotEmpty ?? false)
              _Section(
                title: l10n.examples,
                child: QuoteList(items: item.examples!),
              ),
            if (item.synonyms?.isNotEmpty ?? false)
              _Section(
                title: l10n.synonyms,
                child: WordChips(items: item.synonyms!),
              ),
            if (item.collocations?.isNotEmpty ?? false)
              _Section(
                title: l10n.collocations,
                child: WordChips(items: item.collocations!),
              ),
            if (item.commonMistakes?.isNotEmpty ?? false)
              _Section(
                title: l10n.commonMistakes,
                color: AppColors.error,
                child: MistakeList(items: item.commonMistakes!),
              ),
          ],
        ],
      ),
    );
  }
}

/// Shown while a word has no AI content: a progress note while generating,
/// otherwise the reason plus a button to (re)generate it.
class AiContentStatusPanel extends ConsumerWidget {
  const AiContentStatusPanel({super.key, required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(aiContentStatusProvider(item.id));
    final generating = status == AiContentStatus.generating;
    final failed = status == AiContentStatus.failed;

    return AppNotice(
      tone: failed ? AppTone.error : AppTone.neutral,
      leading: generating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      icon: failed ? Icons.error_outline_rounded : Icons.auto_awesome_outlined,
      message: switch (status) {
        AiContentStatus.generating => l10n.aiGenerating,
        AiContentStatus.failed => l10n.aiFailed,
        null => l10n.aiMissing,
      },
      action: generating
          ? null
          : OutlinedButton.icon(
              onPressed: () =>
                  ref.read(aiContentProvider.notifier).ensure(item),
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.generateExplanation),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.color = AppColors.textSecondary,
  });

  final String title;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title, color: color),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
