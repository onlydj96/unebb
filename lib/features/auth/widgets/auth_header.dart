import 'package:flutter/material.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/shared/widgets/brand_mark.dart';

/// Page frame for the signed-out and first-run screens.
///
/// With [brandHero] (sign-in) the stacked logo leads the page; otherwise a
/// small mark sits above [title].
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.showBack = false,
    this.brandHero = false,
  }) : assert(brandHero || title != null, 'title is required without hero');

  final String? title;
  final String? subtitle;
  final Widget child;

  /// Shows a back button (pushed routes such as sign-up).
  final bool showBack;

  /// Leads with the full logo lockup instead of a title.
  final bool brandHero;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle =
        AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary);

    final header = brandHero
        ? Column(
            children: [
              const BrandLockup(markSize: 84),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  style: subtitleStyle,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandMark(size: 44),
              const SizedBox(height: 20),
              Text(
                title!,
                style: AppTypography.headingLarge.copyWith(fontSize: 28),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle!, style: subtitleStyle),
              ],
            ],
          );

    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            showBack ? AppSpacing.sm : AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 40),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
