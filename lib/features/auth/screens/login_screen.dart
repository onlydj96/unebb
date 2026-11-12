import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/widgets/auth_form.dart';
import 'package:unebb/features/auth/widgets/auth_header.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScaffold(
      brandHero: true,
      subtitle: l10n.tagline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.signIn, style: AppTypography.headingMedium),
          const SizedBox(height: AppSpacing.md),
          AuthForm(
            submitLabel: l10n.signIn,
            onSubmit: (email, password) async {
              // GoRouter's redirect navigates once the session exists.
              await signInWithEmail(email: email, password: password);
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => context.push('/signup'),
              child: Text(l10n.noAccountSignUp),
            ),
          ),
        ],
      ),
    );
  }
}
