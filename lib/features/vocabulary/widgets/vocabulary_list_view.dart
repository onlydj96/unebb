import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/vocabulary/providers/ai_content_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/shared/utils/app_snackbar.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';
import 'package:unebb/shared/widgets/vocabulary_card.dart';

/// Maps the AI content status of [item] to what a card should show.
VocabularyCardAiState aiCardState(
    VocabularyItem item, AiContentStatus? status) {
  if (hasAiContent(item)) return VocabularyCardAiState.ready;
  return status == AiContentStatus.generating
      ? VocabularyCardAiState.generating
      : VocabularyCardAiState.missing;
}

/// Pull-to-refresh list of vocabulary cards (used by the deck screen and the
/// all-words screen).
class VocabularyListView extends ConsumerWidget {
  const VocabularyListView({
    super.key,
    required this.wordsAsync,
    required this.empty,
  });

  final AsyncValue<List<VocabularyItem>> wordsAsync;
  final Widget empty;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await Future.wait([
        ref.read(vocabularyNotifierProvider.notifier).refresh(),
        ref.read(memoryStatesMapNotifierProvider.notifier).refresh(),
      ]);
    } catch (e) {
      AppLogger.warning('Vocabulary refresh failed', details: e);
      if (context.mounted) {
        AppSnackBar.showError(context, context.l10n.refreshFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final memoryMap =
        ref.watch(memoryStatesMapNotifierProvider).valueOrNull ?? const {};
    final aiStatus = ref.watch(aiContentProvider);

    return wordsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState(
        icon: Icons.error_outline_rounded,
        tone: AppTone.error,
        title: l10n.errorLoadingWords,
        actions: [
          FilledButton.icon(
            onPressed: () => ref.invalidate(vocabularyNotifierProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
      data: (items) {
        if (items.isEmpty) return empty;
        return RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, AppSpacing.xs, 20, 112),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return VocabularyCard(
                item: item,
                memoryStrength: memoryMap[item.id]?.memoryStrength,
                aiState: aiCardState(item, aiStatus[item.id]),
                retryTooltip: l10n.generateExplanation,
                onRetryAi: () =>
                    ref.read(aiContentProvider.notifier).ensure(item),
                onTap: () => context.push('/words/${item.id}'),
              );
            },
          ),
        );
      },
    );
  }
}
