import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';

/// Manages the full vocabulary list for the current user.
class VocabularyNotifier extends AsyncNotifier<List<VocabularyItem>> {
  @override
  Future<List<VocabularyItem>> build() {
    return ref.read(vocabularyRepositoryProvider).getAll();
  }

  Future<void> addWord({
    required String word,
    required String language,
    String? deckId,
  }) async {
    // 1. Create the vocabulary item row.
    final item = await ref.read(vocabularyRepositoryProvider).create(
          word: word,
          language: language,
          deckId: deckId,
        );

    // 2. Create the initial memory state so it enters the review queue.
    await ref.read(memoryStateRepositoryProvider).create(vocabularyId: item.id);

    // 3. Get user's native language for AI explanations.
    final profile = await ref.read(profileProvider.future);
    final nativeLanguage = profile?.nativeLanguage ?? 'Korean';

    // 4. Trigger AI explanation generation in the background.
    //    Fire-and-forget: the list tile shows a loading indicator until
    //    the user refreshes and the definition is populated.
    ref
        .read(aiExplanationServiceProvider)
        .generateExplanation(
          vocabularyId: item.id,
          word: item.word,
          language: item.language,
          nativeLanguage: nativeLanguage,
        )
        .ignore();

    ref.invalidateSelf();
  }

  Future<void> updateWord(VocabularyItem item) async {
    await ref.read(vocabularyRepositoryProvider).update(item);
    ref.invalidateSelf();
  }

  Future<void> deleteWord(String id) async {
    await ref.read(vocabularyRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final vocabularyNotifierProvider =
    AsyncNotifierProvider<VocabularyNotifier, List<VocabularyItem>>(
  VocabularyNotifier.new,
);

/// Fetches a single vocabulary item by [id].
final vocabularyItemProvider =
    FutureProvider.family<VocabularyItem?, String>((ref, id) {
  return ref.read(vocabularyRepositoryProvider).getById(id);
});

/// 현재 사용자의 모든 메모리 상태를 vocabularyId → MemoryState 맵으로 반환.
/// VocabularyListScreen 에서 각 단어의 메모리 강도를 표시할 때 사용합니다.
final memoryStatesMapProvider =
    FutureProvider<Map<String, MemoryState>>((ref) async {
  final states = await ref.read(memoryStateRepositoryProvider).getAll();
  return {for (final s in states) s.vocabularyId: s};
});
