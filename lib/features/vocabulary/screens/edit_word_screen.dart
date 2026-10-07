import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

/// Screen for editing an existing vocabulary word.
class EditWordScreen extends ConsumerStatefulWidget {
  const EditWordScreen({
    super.key,
    required this.wordId,
  });

  final String wordId;

  @override
  ConsumerState<EditWordScreen> createState() => _EditWordScreenState();
}

class _EditWordScreenState extends ConsumerState<EditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  String _selectedLanguage = 'English';
  bool _isLoading = false;
  VocabularyItem? _currentItem;

  static const _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Japanese',
    'Chinese',
    'Korean',
    'Italian',
    'Portuguese',
  ];

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _updateWord() async {
    if (!_formKey.currentState!.validate() || _currentItem == null) return;
    setState(() => _isLoading = true);
    try {
      final updatedItem = _currentItem!.copyWith(
        word: _wordController.text.trim(),
        language: _selectedLanguage,
      );
      await ref.read(vocabularyNotifierProvider.notifier).updateWord(updatedItem);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete word'),
        content: const Text('Are you sure you want to delete this word? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(vocabularyNotifierProvider.notifier).deleteWord(widget.wordId);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(vocabularyItemProvider(widget.wordId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Word'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _deleteWord,
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading word: $e'),
        ),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Word not found'));
          }

          // Initialize form with current values
          if (_currentItem == null) {
            _currentItem = item;
            _wordController.text = item.word;
            _selectedLanguage = item.language;
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _wordController,
                    decoration: const InputDecoration(
                      labelText: 'Word or phrase',
                      hintText: 'e.g. ephemeral',
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a word';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(labelText: 'Language'),
                    items: _languages.map((lang) {
                      return DropdownMenuItem(value: lang, child: Text(lang));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLanguage = v);
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _updateWord,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Word'),
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
