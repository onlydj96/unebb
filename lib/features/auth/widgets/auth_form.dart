import 'package:flutter/material.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/utils/error_messages.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/shared/widgets/app_notice.dart';
import 'package:unebb/shared/widgets/loading_button.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Email + password form shared by sign-in and sign-up.
///
/// Validates input before calling [onSubmit] and turns failures into a
/// friendly message (raw `AuthApiException(...)` strings were shown before).
/// [onSubmit] may return a notice to display instead of an error.
class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String submitLabel;
  final Future<String?> Function(String email, String password) onSubmit;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _messageIsError = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final notice =
          await widget.onSubmit(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted && notice != null) {
        setState(() {
          _message = notice;
          _messageIsError = false;
        });
      }
    } catch (e, st) {
      AppLogger.warning('Authentication failed', details: e);
      AppLogger.debug('Stack trace', data: st);
      if (mounted) {
        setState(() {
          _message = friendlyErrorMessage(context.l10n, e);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailCtrl,
            decoration: InputDecoration(
              hintText: l10n.email,
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '')
                ? null
                : l10n.emailInvalid,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _passwordCtrl,
            decoration: InputDecoration(
              hintText: l10n.password,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
            ),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                (v ?? '').length >= 6 ? null : l10n.passwordTooShort,
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppNotice(
              tone: _messageIsError ? AppTone.error : AppTone.success,
              icon: _messageIsError
                  ? Icons.error_outline_rounded
                  : Icons.mark_email_read_outlined,
              message: _message!,
              dense: true,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          LoadingButton(
            onPressed: _submit,
            label: widget.submitLabel,
            isLoading: _loading,
          ),
        ],
      ),
    );
  }
}
