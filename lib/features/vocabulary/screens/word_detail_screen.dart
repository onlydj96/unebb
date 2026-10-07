import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

/// Displays full details of a single vocabulary item, including AI content.
class WordDetailScreen extends ConsumerWidget {
  const WordDetailScreen({super.key, required this.wordId});

  final String wordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(vocabularyItemProvider(wordId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Detail'),
        actions: [
          itemAsync.whenOrNull(
                data: (item) => item != null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete word',
                        onPressed: () => _confirmDelete(context, ref, item),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Word not found.'));
          }
          return _WordDetailBody(item: item);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VocabularyItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete word?'),
        content: Text(
          'Remove "${item.word}" from your vocabulary? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(vocabularyNotifierProvider.notifier).deleteWord(item.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _WordDetailBody extends StatelessWidget {
  const _WordDetailBody({required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    final hasAi = item.definition != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word header
          Text(item.word, style: AppTypography.displayMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.language,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (!hasAi) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.mediumBorder,
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'AI explanation is being generated…',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _Section(title: 'Definition', content: item.definition!),
            if (item.explanation != null)
              _Section(title: 'Explanation', content: item.explanation!),
            if (item.usage != null)
              _Section(title: 'Usage', content: item.usage!),
            if (item.examples?.isNotEmpty == true)
              _ListSection(title: 'Examples', items: item.examples!),
            if (item.synonyms?.isNotEmpty == true)
              _ListSection(title: 'Synonyms', items: item.synonyms!),
            if (item.collocations?.isNotEmpty == true)
              _ListSection(title: 'Collocations', items: item.collocations!),
            if (item.commonMistakes?.isNotEmpty == true)
              _ListSection(
                title: 'Common Mistakes',
                items: item.commonMistakes!,
              ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(content, style: AppTypography.bodyLarge),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(item, style: AppTypography.bodyLarge),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
