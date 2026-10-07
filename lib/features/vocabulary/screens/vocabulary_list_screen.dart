import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/shared/widgets/vocabulary_card.dart';

/// Home screen — displays the user's vocabulary list.
class VocabularyListScreen extends ConsumerWidget {
  const VocabularyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(vocabularyNotifierProvider);
    final memoryMap = ref.watch(memoryStatesMapProvider).valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Words'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'review') context.push('/review');
              if (value == 'signout') await signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'review',
                child: Text('Start review'),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: wordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading words: $e'),
        ),
        data: (words) {
          if (words.isEmpty) {
            return Center(
              child: Text(
                'No words yet.\nAdd your first word to get started.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(vocabularyNotifierProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: words.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = words[index];
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-word'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
