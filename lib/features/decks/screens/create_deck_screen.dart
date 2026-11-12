import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/constants/languages.dart';
import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/utils/error_messages.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/shared/utils/app_snackbar.dart';
import 'package:unebb/shared/widgets/language_dropdown.dart';
import 'package:unebb/shared/widgets/loading_button.dart';

/// Screen for creating a new deck.
class CreateDeckScreen extends ConsumerStatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  ConsumerState<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends ConsumerState<CreateDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedLanguage = SupportedLanguages.defaultLearning;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createDeck() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final description = _descriptionController.text.trim();
      final deck = await ref.read(deckNotifierProvider.notifier).createDeck(
            name: _nameController.text.trim(),
            language: _selectedLanguage,
            description: description.isEmpty ? null : description,
          );
      if (mounted) context.pushReplacement('/decks/${deck.id}');
    } catch (e, st) {
      AppLogger.error('Deck creation failed', error: e, stackTrace: st);
      if (mounted) {
        AppSnackBar.showError(context, friendlyErrorMessage(context.l10n, e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createDeck)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.lg),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.deckName,
                hintText: l10n.deckNameHint,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofocus: true,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.deckNameRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            LearningLanguageDropdown(
              value: _selectedLanguage,
              label: l10n.learningLanguage,
              onChanged: (value) {
                if (value != null) setState(() => _selectedLanguage = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.deckDescription,
                hintText: l10n.deckDescriptionHint,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            LoadingButton(
              onPressed: _createDeck,
              label: l10n.createDeck,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
