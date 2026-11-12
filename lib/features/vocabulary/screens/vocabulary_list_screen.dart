import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/review/widgets/review_options_dialog.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/features/vocabulary/widgets/vocabulary_list_view.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';

/// Every word of the user, including words that are not in any deck.
class VocabularyListScreen extends ConsumerWidget {
  const VocabularyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wordsAsync = ref.watch(vocabularyNotifierProvider);
    final hasWords = wordsAsync.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allWords),
        actions: [
          if (hasWords)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.review),
                onPressed: () => showReviewOptions(
                  context,
                  dueCount: ref.read(dueCountProvider(null)),
                ),
              ),
            ),
        ],
      ),
      body: VocabularyListView(
        wordsAsync: wordsAsync,
        empty: AppEmptyState(
          icon: Icons.text_fields_rounded,
          title: l10n.noWordsYet,
          message: l10n.addFirstWord,
          actions: [
            FilledButton.icon(
              onPressed: () => context.push('/add-word'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addWord),
            ),
          ],
        ),
      ),
      floatingActionButton: hasWords
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/add-word'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addWord),
            )
          : null,
    );
  }
}
