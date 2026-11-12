import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/widgets/auth_form.dart';
import 'package:unebb/features/auth/widgets/auth_header.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScaffold(
      title: l10n.createAccount,
      subtitle: l10n.tagline,
      showBack: true,
      child: AuthForm(
        submitLabel: l10n.createAccount,
        onSubmit: (email, password) async {
          final hasSession =
              await signUpWithEmail(email: email, password: password);
          if (hasSession) {
            if (context.mounted) context.go('/profile-setup');
            return null;
          }
          return l10n.checkEmailToConfirm;
        },
      ),
    );
  }
}
