import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

/// Dashboard screen with review start button and stats.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(deckListProvider);
    final memoryMapAsync = ref.watch(memoryStatesMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UnEbb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(deckListProvider);
          ref.invalidate(memoryStatesMapProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Welcome section
            Text(
              'Ready to learn?',
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Review your vocabulary to strengthen your memory.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Start Review Card
            _buildReviewCard(context, ref, memoryMapAsync),
            const SizedBox(height: AppSpacing.lg),

            // Quick Stats
            _buildStatsSection(decksAsync, memoryMapAsync),
            const SizedBox(height: AppSpacing.lg),

            // Recent Decks
            _buildRecentDecksSection(context, decksAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, MemoryState>> memoryMapAsync,
  ) {
    final dueCount = memoryMapAsync.whenOrNull(
      data: (map) {
        final now = DateTime.now();
        return map.values.where((state) {
          return state.nextReviewAt.isBefore(now);
        }).length;
      },
    );

    return Card(
      elevation: 0,
      color: AppColors.primary,
      child: InkWell(
        onTap: () => _showReviewOptions(context, dueCount ?? 0),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Review',
                      style: AppTypography.headingMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      dueCount != null && dueCount > 0
                          ? '$dueCount words due for review'
                          : 'Keep your streak going!',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    AsyncValue<List<Deck>> decksAsync,
    AsyncValue<Map<String, MemoryState>> memoryMapAsync,
  ) {
    final deckCount = decksAsync.whenOrNull(data: (d) => d.length) ?? 0;
    final wordCount = memoryMapAsync.whenOrNull(data: (m) => m.length) ?? 0;
    final masteredCount = memoryMapAsync.whenOrNull(
          data: (m) => m.values.where((s) => s.memoryStrength >= 0.8).length,
        ) ??
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Progress', style: AppTypography.headingSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.library_books,
                value: '$deckCount',
                label: 'Decks',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                icon: Icons.abc,
                value: '$wordCount',
                label: 'Words',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                icon: Icons.star,
                value: '$masteredCount',
                label: 'Mastered',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentDecksSection(
    BuildContext context,
    AsyncValue<List<Deck>> decksAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Decks', style: AppTypography.headingSmall),
            TextButton(
              onPressed: () {
                // Navigate to decks tab (index 1)
                final shell = StatefulNavigationShell.of(context);
                shell.goBranch(1);
              },
              child: const Text('See all'),
            ),
          ],
        ),
        decksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (decks) {
            if (decks.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.library_add,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No decks yet',
                        style: AppTypography.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Create your first deck to start learning!',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
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

            final recentDecks = decks.take(3).toList();
            return Column(
              children: recentDecks.map((deck) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      deck.language.substring(0, 2).toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(deck.name),
                  subtitle: Text('${deck.wordCount} words'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/decks/${deck.id}'),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showReviewOptions(BuildContext context, int dueCount) {
    showDialog(
      context: context,
      builder: (context) => _ReviewOptionsDialog(dueCount: dueCount),
    );
  }
}

class _ReviewOptionsDialog extends StatefulWidget {
  const _ReviewOptionsDialog({required this.dueCount});

  final int dueCount;

  @override
  State<_ReviewOptionsDialog> createState() => _ReviewOptionsDialogState();
}

class _ReviewOptionsDialogState extends State<_ReviewOptionsDialog> {
  String _mode = 'due';
  int _limit = 10;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('복습 시작'),
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
            subtitle: Text('${widget.dueCount}개 단어'),
            secondary: Icon(Icons.schedule, color: AppColors.primary),
          ),
          RadioListTile<String>(
            value: 'all',
            groupValue: _mode,
            onChanged: (value) => setState(() => _mode = value!),
            title: const Text('모든 단어 복습'),
            subtitle: const Text('우선순위 순으로 정렬됨'),
            secondary: Icon(Icons.all_inclusive, color: AppColors.secondary),
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '몇 개의 단어를 복습하시겠어요?',
            style: AppTypography.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
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
            context.push('/review?mode=$_mode&limit=$_limit');
          },
          child: const Text('시작'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.headingMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
