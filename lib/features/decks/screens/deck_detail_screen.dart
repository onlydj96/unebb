import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/decks/widgets/deck_avatar.dart';
import 'package:unebb/features/review/widgets/review_options_dialog.dart';
import 'package:unebb/features/vocabulary/widgets/vocabulary_list_view.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';

/// Screen displaying the contents of a single deck.
class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final deckAsync = ref.watch(deckByIdProvider(deckId));
    final vocabularyAsync = ref.watch(deckVocabularyProvider(deckId));
    final hasWords = vocabularyAsync.valueOrNull?.isNotEmpty ?? false;

    return deckAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.errorLoadingDecks,
        ),
      ),
      data: (deck) {
        if (deck == null) {
          return Scaffold(
            appBar: AppBar(),
            body: AppEmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.deckNotFound,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DeckHeader(
                deck: deck,
                onReview: hasWords
                    ? () => showReviewOptions(
                          context,
                          deckId: deckId,
                          dueCount: ref.read(dueCountProvider(deckId)),
                        )
                    : null,
              ),
              Expanded(
                child: VocabularyListView(
                  wordsAsync: vocabularyAsync,
                  empty: AppEmptyState(
                    icon: Icons.style_outlined,
                    title: l10n.noWordsYet,
                    message: l10n.addFirstWordToDeck,
                    actions: [
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/decks/$deckId/add-word'),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.addWord),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: hasWords
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/decks/$deckId/add-word'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addWord),
                )
              : null,
        );
      },
    );
  }
}

class _DeckHeader extends StatelessWidget {
  const _DeckHeader({required this.deck, required this.onReview});

  final Deck deck;

  /// Null while the deck has no words.
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final description = deck.description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DeckAvatar(language: deck.language, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: AppTypography.headingLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${deck.language} · ${l10n.wordCount(deck.wordCount)}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onReview,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.startReview),
          ),
        ],
      ),
    );
  }
}
