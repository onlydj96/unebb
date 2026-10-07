import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/shared/widgets/vocabulary_card.dart';

/// Provider for vocabulary items in a specific deck.
final deckVocabularyProvider =
    FutureProvider.family<List<VocabularyItem>, String>((ref, deckId) async {
  final allItems = await ref.watch(vocabularyNotifierProvider.future);
  return allItems.where((item) => item.deckId == deckId).toList();
});

/// Screen displaying the contents of a single deck.
class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({
    super.key,
    required this.deckId,
  });

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckAsync = ref.watch(deckByIdProvider(deckId));
    final vocabularyAsync = ref.watch(deckVocabularyProvider(deckId));
    final memoryMap = ref.watch(memoryStatesMapProvider).valueOrNull ?? {};

    return deckAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (deck) {
        if (deck == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Deck not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(deck.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Start Review',
                onPressed: () => _showDeckReviewOptions(context, deckId),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deck info header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.surfaceElevated,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            deck.language.substring(0, 2).toUpperCase(),
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deck.language,
                                style: AppTypography.labelMedium,
                              ),
                              Text(
                                '${deck.wordCount} words',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (deck.description != null &&
                        deck.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        deck.description!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Vocabulary list
              Expanded(
                child: vocabularyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) {
                    if (items.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(deckVocabularyProvider(deckId));
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return VocabularyCard(
                            item: item,
                            memoryStrength: memoryMap[item.id]?.memoryStrength,
                            onTap: () => context.push('/words/${item.id}'),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/decks/$deckId/add-word'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        );
      },
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
              Icons.style_outlined,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No words yet',
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add your first word to this deck.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => context.push('/decks/$deckId/add-word'),
              icon: const Icon(Icons.add),
              label: const Text('Add Word'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeckReviewOptions(BuildContext context, String deckId) {
    showDialog(
      context: context,
      builder: (context) => _DeckReviewOptionsDialog(deckId: deckId),
    );
  }
}

class _DeckReviewOptionsDialog extends StatefulWidget {
  const _DeckReviewOptionsDialog({required this.deckId});

  final String deckId;

  @override
  State<_DeckReviewOptionsDialog> createState() =>
      _DeckReviewOptionsDialogState();
}

class _DeckReviewOptionsDialogState extends State<_DeckReviewOptionsDialog> {
  String _mode = 'due';
  int _limit = 10;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('덱 복습'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '어떤 단어를 복습하시겠어요?',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          RadioListTile<String>(
            value: 'due',
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value!),
            title: const Text('복습 시간된 단어만'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          RadioListTile<String>(
            value: 'all',
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value!),
            title: const Text('모든 단어 복습'),
            subtitle: const Text('우선순위 순으로 정렬됨'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '몇 개의 단어를 복습하시겠어요?',
            style: AppTypography.labelLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _limit.toDouble(),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '$_limit개',
                  onChanged: (value) => setState(() => _limit = value.toInt()),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 60,
                child: Text(
                  '$_limit개',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '빠른 선택:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final count in [5, 10, 20, 30])
                OutlinedButton(
                  onPressed: () => setState(() => _limit = count),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('$count'),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            context.push('/review?mode=$_mode&deckId=${widget.deckId}&limit=$_limit');
          },
          child: const Text('시작'),
        ),
      ],
    );
  }
}
