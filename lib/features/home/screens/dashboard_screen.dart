import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/domain/models/deck.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/auth/widgets/sign_out.dart';
import 'package:unebb/features/common/widgets/offline_banner.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/decks/widgets/deck_avatar.dart';
import 'package:unebb/features/review/widgets/review_options_dialog.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/shared/utils/app_snackbar.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';
import 'package:unebb/shared/widgets/brand_mark.dart';
import 'package:unebb/shared/widgets/labels.dart';
import 'package:unebb/shared/widgets/memory_indicator.dart';

/// Dashboard: start a review, see progress and recent decks.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await Future.wait([
        ref.read(deckNotifierProvider.notifier).refresh(),
        ref.read(vocabularyNotifierProvider.notifier).refresh(),
        ref.read(memoryStatesMapNotifierProvider.notifier).refresh(),
      ]);
    } catch (e) {
      AppLogger.warning('Dashboard refresh failed', details: e);
      if (context.mounted) {
        AppSnackBar.showError(context, context.l10n.refreshFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final decksAsync = ref.watch(deckListProvider);
    final memoryMap = ref.watch(memoryStatesMapNotifierProvider).valueOrNull;
    final wordCount = ref.watch(vocabularyNotifierProvider).valueOrNull?.length;
    final dueCount = ref.watch(dueCountProvider(null));
    final name = ref.watch(profileProvider).valueOrNull?.displayName.trim();
    final reviewed = memoryMap?.values.where((s) => s.reviewCount > 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const BrandWordmark(fontSize: 22, showMark: false),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: l10n.signOut,
            onPressed: () => confirmAndSignOut(context, ref),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context, ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, 40),
          children: [
            const OfflineBanner(),
            Text(
              name != null && name.isNotEmpty
                  ? l10n.greetingName(name)
                  : l10n.dashboardGreeting,
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.dashboardSubtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ReviewHero(
              dueCount: dueCount,
              onStart: () => showReviewOptions(context, dueCount: dueCount),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionLabel(l10n.yourProgress),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.style_outlined,
                      value: decksAsync.valueOrNull?.length,
                      label: l10n.statDecks,
                      onTap: () =>
                          StatefulNavigationShell.of(context).goBranch(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.text_fields_rounded,
                      value: wordCount,
                      label: l10n.statWords,
                      onTap: () => context.push('/words'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.workspace_premium_outlined,
                      iconColor: AppColors.successText,
                      value: memoryMap?.values
                          .where((s) => s.memoryStrength >= 0.8)
                          .length,
                      label: l10n.statMastered,
                    ),
                  ),
                ],
              ),
            ),
            if (reviewed != null && reviewed.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MemoryHealthCard(states: reviewed),
            ],
            const SizedBox(height: AppSpacing.xl),
            _RecentDecks(decksAsync: decksAsync),
          ],
        ),
      ),
    );
  }
}

/// Cocoa hero card: how many words are waiting, and the way in.
class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.dueCount, required this.onStart});

  final int? dueCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = dueCount;
    final onDark = AppTypography.bodyMedium.copyWith(
      color: AppColors.textOnDarkMuted,
    );

    return Material(
      color: AppColors.cocoa,
      borderRadius: AppRadius.xLargeBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        splashColor: AppColors.paper.withValues(alpha: 0.08),
        highlightColor: AppColors.paper.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(l10n.review, color: AppColors.mint),
              const SizedBox(height: AppSpacing.md),
              if (due == null)
                Text(
                  '–',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                )
              else if (due > 0)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$due',
                      style: AppTypography.displayLarge.copyWith(
                        color: AppColors.textOnDark,
                        fontSize: 56,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(l10n.dueNowLabel(due), style: onDark),
                    ),
                  ],
                )
              else
                Text(
                  l10n.nothingDue,
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.paper,
                  foregroundColor: AppColors.cocoa,
                  iconColor: AppColors.cocoa,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.startReview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.textSecondary,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;

  /// Null while loading.
  final int? value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(height: 14),
              Text(value?.toString() ?? '–', style: AppTypography.numeral),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reviewed words split by memory stage, ordered ebb → flow.
class _MemoryHealthCard extends StatelessWidget {
  const _MemoryHealthCard({required this.states});

  final List<MemoryState> states;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Representative strengths for each stage, critical → strong.
    const stageSamples = [0.0, 0.3, 0.6, 0.8];
    final counts = List.filled(stageSamples.length, 0);
    for (final s in states) {
      final strength = s.memoryStrength;
      final index = strength >= 0.8
          ? 3
          : strength >= 0.6
              ? 2
              : strength >= 0.3
                  ? 1
                  : 0;
      counts[index]++;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.memoryHealth,
                    style: AppTypography.labelLarge.copyWith(fontSize: 15),
                  ),
                ),
                Text(
                  l10n.wordCount(states.length),
                  style: AppTypography.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: AppRadius.fullBorder,
              child: SizedBox(
                height: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < counts.length; i++)
                      if (counts[i] > 0) ...[
                        if (counts.take(i).any((c) => c > 0))
                          const SizedBox(width: 2),
                        Expanded(
                          flex: counts[i],
                          child: ColoredBox(
                            color: MemoryIndicator.colorFor(stageSamples[i]),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                for (var i = 0; i < counts.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StageDot(
                        color: MemoryIndicator.colorFor(stageSamples[i]),
                        size: 8,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${MemoryIndicator.stageName(l10n, stageSamples[i])}'
                        ' ${counts[i]}',
                        style: AppTypography.labelMedium,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentDecks extends StatelessWidget {
  const _RecentDecks({required this.decksAsync});

  final AsyncValue<List<Deck>> decksAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l10n.recentDecks,
          trailing: TextButton(
            onPressed: () => StatefulNavigationShell.of(context).goBranch(1),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: Text(l10n.seeAll),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        decksAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            l10n.errorLoadingDecks,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          data: (decks) {
            if (decks.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const ToneBadge(
                          Icons.library_add_outlined, AppTone.neutral,
                          size: 56),
                      const SizedBox(height: AppSpacing.md),
                      Text(l10n.noDecksYet, style: AppTypography.headingSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.createFirstDeck,
                        style: AppTypography.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => context.push('/decks/create'),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.createDeck),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final deck in decks.take(3)) ...[
                  _DeckRow(deck: deck),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/decks/${deck.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              DeckAvatar(language: deck.language),
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
                    Text(
                      context.l10n.wordCount(deck.wordCount),
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
