import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';

/// Screen displaying all decks for the current user.
class DecksListScreen extends ConsumerWidget {
  const DecksListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(deckNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Decks'),
      ),
      body: decksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Error loading decks: $e'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.invalidate(deckNotifierProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (decks) {
          if (decks.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(deckNotifierProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: decks.length,
              itemBuilder: (context, index) {
                final deck = decks[index];
                return _DeckCard(deck: deck);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/decks/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 80,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No decks yet',
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create your first deck to start organizing your vocabulary.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => context.push('/decks/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Deck'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckCard extends ConsumerWidget {
  const _DeckCard({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push('/decks/${deck.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                radius: 24,
                child: Text(
                  deck.language.substring(0, 2).toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.name,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (deck.description != null &&
                        deck.description!.isNotEmpty)
                      Text(
                        deck.description!,
                        style: AppTypography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.style,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${deck.wordCount} words',
                          style: AppTypography.labelMedium,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Icon(
                          Icons.language,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          deck.language,
                          style: AppTypography.labelMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Deck?'),
                        content: Text(
                          'This will delete "${deck.name}" and all its words. This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(deckNotifierProvider.notifier)
                          .deleteDeck(deck.id);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
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
