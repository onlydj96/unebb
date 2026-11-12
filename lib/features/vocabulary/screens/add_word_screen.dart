import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/constants/languages.dart';
import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/core/utils/error_messages.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/features/vocabulary/utils/duplicate_word_message.dart';
import 'package:unebb/shared/utils/app_snackbar.dart';
import 'package:unebb/shared/widgets/app_notice.dart';
import 'package:unebb/shared/widgets/language_dropdown.dart';
import 'package:unebb/shared/widgets/loading_button.dart';

/// Screen for adding a new vocabulary word.
class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({super.key, this.deckId});

  /// If provided, the word will be added to this deck.
  final String? deckId;

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  late String _selectedLanguage = _initialLanguage();
  bool _isLoading = false;

  /// Words added to a deck default to the deck's language (previously always
  /// English, which produced explanations in the wrong language).
  String _initialLanguage() {
    final deckId = widget.deckId;
    if (deckId == null) return SupportedLanguages.defaultLearning;
    return ref.read(deckByIdProvider(deckId)).valueOrNull?.language ??
        SupportedLanguages.defaultLearning;
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _addWord() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final vocabularyId =
          await ref.read(vocabularyNotifierProvider.notifier).addWord(
                word: _wordController.text.trim(),
                language: _selectedLanguage,
                deckId: widget.deckId,
              );
      if (mounted) context.pushReplacement('/word-added/$vocabularyId');
    } on DuplicateWordException catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          duplicateWordMessage(context.l10n, ref, e,
              currentDeckId: widget.deckId),
        );
      }
    } catch (e, st) {
      AppLogger.error('Adding word failed', error: e, stackTrace: st);
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
      appBar: AppBar(title: Text(l10n.addWord)),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _wordController,
                style: AppTypography.displaySmall,
                decoration: InputDecoration(
                  labelText: l10n.wordOrPhrase,
                  hintText: l10n.wordHintExample,
                  hintStyle: AppTypography.displaySmall
                      .copyWith(color: AppColors.textMuted),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _addWord(),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.wordRequired : null,
              ),
              const SizedBox(height: AppSpacing.md),
              LearningLanguageDropdown(
                value: _selectedLanguage,
                label: l10n.language,
                onChanged: (v) {
                  if (v != null) setState(() => _selectedLanguage = v);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppNotice(
                icon: Icons.auto_awesome_outlined,
                message: l10n.addWordHelper,
                dense: true,
              ),
              const SizedBox(height: AppSpacing.xl),
              LoadingButton(
                onPressed: _addWord,
                label: l10n.addWord,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
