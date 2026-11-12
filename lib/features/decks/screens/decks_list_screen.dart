import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/decks/widgets/deck_avatar.dart';
import 'package:unebb/shared/utils/app_snackbar.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';
import 'package:unebb/shared/widgets/labels.dart';

/// Screen displaying all decks for the current user.
class DecksListScreen extends ConsumerWidget {
  const DecksListScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(deckNotifierProvider.notifier).refresh();
    } catch (e) {
      AppLogger.warning('Deck refresh failed', details: e);
      if (context.mounted) {
        AppSnackBar.showError(context, context.l10n.refreshFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final decksAsync = ref.watch(deckListProvider);
    final hasDecks = decksAsync.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myDecks)),
      body: decksAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          tone: AppTone.error,
          title: l10n.errorLoadingDecks,
          actions: [
            FilledButton(
              onPressed: () => ref.invalidate(deckNotifierProvider),
              child: Text(l10n.retry),
            ),
          ],
        ),
        data: (decks) {
          if (decks.isEmpty) {
            return AppEmptyState(
              icon: Icons.style_outlined,
              title: l10n.noDecksYet,
              message: l10n.noDecksDescription,
              actions: [
                FilledButton.icon(
                  onPressed: () => context.push('/decks/create'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.createDeck),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(context, ref),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 112),
              itemCount: decks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _DeckCard(deck: decks[index]),
            ),
          );
        },
      ),
      floatingActionButton: hasDecks
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/decks/create'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.createDeck),
            )
          : null,
    );
  }
}

class _DeckCard extends ConsumerWidget {
  const _DeckCard({required this.deck});

  final Deck deck;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDeckTitle),
        content: Text(l10n.deleteDeckMessage(deck.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(deckNotifierProvider.notifier).deleteDeck(deck.id);
    } catch (e, st) {
      AppLogger.error('Deck delete failed', error: e, stackTrace: st);
      if (context.mounted) AppSnackBar.showError(context, l10n.deleteFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final description = deck.description;

    return Card(
      child: InkWell(
        onTap: () => context.push('/decks/${deck.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeckAvatar(language: deck.language, radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: AppTypography.headingSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null && description.isNotEmpty)
                      Text(
                        description,
                        style: AppTypography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TagPill(
                          l10n.wordCount(deck.wordCount),
                          icon: Icons.style_outlined,
                        ),
                        TagPill(deck.language, icon: Icons.translate_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'delete') _delete(context, ref);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.delete,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
