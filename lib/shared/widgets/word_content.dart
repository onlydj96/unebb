import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';

// Building blocks for a word's AI content, shared by the word detail,
// word added and review screens.

/// Example sentences, each set off by a mint rule.
class QuoteList extends StatelessWidget {
  const QuoteList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            margin: EdgeInsets.only(top: i == 0 ? 0 : 10),
            padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.mint, width: 3),
              ),
            ),
            child: Text(items[i], style: AppTypography.bodyLarge),
          ),
      ],
    );
  }
}

/// Synonyms / collocations as sand pills.
class WordChips extends StatelessWidget {
  const WordChips({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.fullBorder,
            ),
            child: Text(item, style: AppTypography.bodyMedium),
          ),
      ],
    );
  }
}

/// Common mistakes on a crimson tint.
class MistakeList extends StatelessWidget {
  const MistakeList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: AppRadius.mediumBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3, right: 10),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                  Expanded(
                    child: Text(items[i], style: AppTypography.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
