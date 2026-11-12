import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/shared/widgets/labels.dart';

/// Opens the review options sheet and, on confirm, the review screen.
///
/// [dueCount] is the number of due words (null while unknown). When nothing
/// is due the sheet preselects "all words" instead of leading the learner
/// into an empty session.
Future<void> showReviewOptions(
  BuildContext context, {
  String? deckId,
  int? dueCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ReviewOptionsSheet(deckId: deckId, dueCount: dueCount),
  );
}

/// Builds the review route for the chosen options.
String reviewLocation(
    {required String mode, required int limit, String? deckId}) {
  return Uri(path: '/review', queryParameters: {
    'mode': mode,
    'limit': '$limit',
    if (deckId != null) 'deckId': deckId,
  }).toString();
}

class ReviewOptionsSheet extends StatefulWidget {
  const ReviewOptionsSheet({super.key, this.deckId, this.dueCount});

  final String? deckId;
  final int? dueCount;

  @override
  State<ReviewOptionsSheet> createState() => _ReviewOptionsSheetState();
}

class _ReviewOptionsSheetState extends State<ReviewOptionsSheet> {
  static const _quickCounts = [5, 10, 20, 30];

  late String _mode = widget.dueCount == 0 ? 'all' : 'due';
  int _limit = 10;

  void _start() {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(reviewLocation(
      mode: _mode,
      limit: _limit,
      deckId: widget.deckId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dueCount = widget.dueCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.deckId == null
                ? l10n.reviewOptionsTitle
                : l10n.deckReviewTitle,
            style: AppTypography.headingLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.reviewWhichWords,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ModeOption(
            selected: _mode == 'due',
            title: l10n.reviewDueOnly,
            trailing: dueCount == null ? null : l10n.wordCount(dueCount),
            onTap: () => setState(() => _mode = 'due'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModeOption(
            selected: _mode == 'all',
            title: l10n.reviewAllWords,
            subtitle: l10n.reviewAllWordsSubtitle,
            onTap: () => setState(() => _mode = 'all'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(
            l10n.reviewHowMany,
            trailing: Text('$_limit', style: AppTypography.numeral),
          ),
          Slider(
            value: _limit.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: l10n.wordCount(_limit),
            onChanged: (value) => setState(() => _limit = value.round()),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final count in _quickCounts)
                ChoiceChip(
                  label: Text('$count'),
                  selected: _limit == count,
                  onSelected: (_) => setState(() => _limit = count),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.start),
          ),
        ],
      ),
    );
  }
}

/// A selectable card with a radio-style indicator.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? AppColors.surface : AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.largeBorder,
          side: BorderSide(
            color: selected ? AppColors.cocoa : AppColors.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? AppColors.cocoa : AppColors.outlineStrong,
                      width: selected ? 7 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.headingSmall),
                      if (subtitle != null)
                        Text(subtitle!, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null)
                  Text(trailing!, style: AppTypography.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
