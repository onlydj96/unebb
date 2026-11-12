import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/core/utils/error_messages.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';
import 'package:unebb/features/vocabulary/utils/duplicate_word_message.dart';
import 'package:unebb/shared/utils/app_snackbar.dart';
import 'package:unebb/shared/widgets/app_empty_state.dart';
import 'package:unebb/shared/widgets/language_dropdown.dart';
import 'package:unebb/shared/widgets/loading_button.dart';

/// Screen for editing an existing vocabulary word.
class EditWordScreen extends ConsumerStatefulWidget {
  const EditWordScreen({super.key, required this.wordId});

  final String wordId;

  @override
  ConsumerState<EditWordScreen> createState() => _EditWordScreenState();
}

class _EditWordScreenState extends ConsumerState<EditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  String? _selectedLanguage;
  bool _isLoading = false;
  VocabularyItem? _original;

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  void _initFrom(VocabularyItem item) {
    if (_original != null) return;
    _original = item;
    _wordController.text = item.word;
    _selectedLanguage = item.language;
  }

  Future<void> _updateWord() async {
    final original = _original;
    if (_isLoading || original == null || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(vocabularyNotifierProvider.notifier).updateWord(
            original.copyWith(
              word: _wordController.text.trim(),
              language: _selectedLanguage ?? original.language,
            ),
          );
      if (mounted) context.pop();
    } on DuplicateWordException catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          duplicateWordMessage(context.l10n, ref, e,
              currentDeckId: original.deckId),
        );
      }
    } catch (e, st) {
      AppLogger.error('Updating word failed', error: e, stackTrace: st);
      if (mounted) {
        AppSnackBar.showError(context, friendlyErrorMessage(context.l10n, e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWord() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWordTitle),
        content: Text(
          l10n.deleteWordMessage(_original?.word ?? _wordController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(vocabularyNotifierProvider.notifier)
          .deleteWord(widget.wordId);
      // Report the deletion so the detail screen underneath closes too.
      // (`go('/decks/<id>')` left a lone page outside the tab shell with no
      // way back.)
      if (mounted) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/');
        }
      }
    } catch (e, st) {
      AppLogger.error('Deleting word failed', error: e, stackTrace: st);
      if (mounted) AppSnackBar.showError(context, l10n.deleteFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final itemAsync = ref.watch(vocabularyItemProvider(widget.wordId));
    // Initialise before building the app bar: its delete button is enabled
    // only once the word is known (initialising later in this build left it
    // disabled until some other rebuild).
    final loaded = itemAsync.valueOrNull;
    if (loaded != null) _initFrom(loaded);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editWord),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            tooltip: l10n.delete,
            onPressed: _isLoading || _original == null ? null : _deleteWord,
          ),
        ],
      ),
      body: itemAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.errorLoadingWords,
        ),
        data: (item) {
          if (item == null && _original == null) {
            return AppEmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.wordNotFound,
            );
          }
          if (item != null) _initFrom(item);

          return SingleChildScrollView(
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
                    onFieldSubmitted: (_) => _updateWord(),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l10n.wordRequired
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LearningLanguageDropdown(
                    value: _selectedLanguage ?? _original!.language,
                    label: l10n.language,
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLanguage = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LoadingButton(
                    onPressed: _updateWord,
                    label: l10n.saveChanges,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
