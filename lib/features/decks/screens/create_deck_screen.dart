import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';

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
    'Russian',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createDeck() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final deck = await ref.read(deckNotifierProvider.notifier).createDeck(
            name: _nameController.text.trim(),
            language: _selectedLanguage,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );

      if (mounted) {
        context.pop();
        context.push('/decks/${deck.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating deck: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Deck'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Deck Name',
                hintText: 'e.g., TOEIC Vocabulary',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a deck name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Language',
              ),
              items: _languages
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedLanguage = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What is this deck for?',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isLoading ? null : _createDeck,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Deck'),
            ),
          ],
        ),
      ),
    );
  }
}
