import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/shared/widgets/vocabulary_card.dart';

/// Checks if error is related to device clock sync (JWT issued at future).
bool _isClockSyncError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('jwt') && msg.contains('future');
}

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
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isClockSyncError(e) ? Icons.access_time : Icons.error_outline,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _isClockSyncError(e)
                      ? 'Device clock out of sync'
                      : 'Error loading words',
                  style: AppTypography.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isClockSyncError(e)
                      ? 'Please check that your device date & time is set to automatic.'
                      : '$e',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(vocabularyNotifierProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
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
