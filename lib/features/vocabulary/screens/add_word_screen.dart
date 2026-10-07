import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

/// Screen for adding a new vocabulary word.
class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({super.key});

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  String _selectedLanguage = 'English';
  bool _isLoading = false;

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

  Future<void> _addWord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(vocabularyNotifierProvider.notifier).addWord(
            word: _wordController.text.trim(),
            language: _selectedLanguage,
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Word')),
      body: Padding(
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
                onPressed: _isLoading ? null : _addWord,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Word'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
