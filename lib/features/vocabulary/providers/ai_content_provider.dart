import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/data/repositories/providers.dart';
import 'package:unebb/domain/models/vocabulary_item.dart';
import 'package:unebb/domain/models/word_reading.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/auth/providers/profile_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

/// Lifecycle of the AI-generated content (definition, examples…) of a word.
enum AiContentStatus { generating, failed }

/// True when the AI fields needed for reviews are present.
bool hasAiContent(VocabularyItem item) =>
    item.definition?.trim().isNotEmpty ?? false;

/// True when the AI content is missing or should be regenerated before it is
/// shown (Japanese content without kanji readings).
bool needsAiContentUpdate(VocabularyItem item) =>
    !hasAiContent(item) || item.lacksKanjiReadings;

/// Tracks AI content generation per vocabulary id.
///
/// * Concurrent requests for the same word share one Edge Function call
///   (adding a word, opening it and reviewing it no longer triggers three
///   OpenAI requests).
/// * Failures are recorded as [AiContentStatus.failed] so the UI can offer a
///   retry instead of spinning forever.
/// * Successful results are pushed into the vocabulary list so every screen
///   picks them up.
class AiContentNotifier extends Notifier<Map<String, AiContentStatus>> {
  final Map<String, Future<VocabularyItem?>> _inFlight = {};

  /// Words whose content was already regenerated for kanji readings (or
  /// tried to be): at most one attempt per word, so a model reply without a
  /// kana reading cannot cause a regeneration loop.
  final Set<String> _readingRefreshes = {};

  /// Changes on every rebuild/dispose so work started for a previous user
  /// (or a disposed container) never writes back.
  Object _generation = Object();

  @override
  Map<String, AiContentStatus> build() {
    // Reset when the signed-in user changes.
    ref.watch(currentUserIdProvider);
    final generation = _generation = Object();
    ref.onDispose(() {
      if (identical(_generation, generation)) _generation = Object();
    });
    _inFlight.clear();
    _readingRefreshes.clear();
    return const {};
  }

  AiContentStatus? statusOf(String vocabularyId) => state[vocabularyId];

  /// Returns [item] with AI content, generating it when missing.
  ///
  /// Resolves to `null` when generation fails; never throws.
  /// [force] regenerates even if content already exists (e.g. after editing
  /// the word). A forced request never reuses a pending one — that request
  /// may describe the previous spelling — it runs after it instead.
  Future<VocabularyItem?> ensure(VocabularyItem item, {bool force = false}) {
    if (!force && hasAiContent(item)) return Future.value(item);
    final pending = _inFlight[item.id];
    if (pending != null && !force) return pending;

    final future = pending == null
        ? _generate(item)
        : pending.then((_) => _generate(item));
    _inFlight[item.id] = future;
    unawaited(future.whenComplete(() {
      if (identical(_inFlight[item.id], future)) _inFlight.remove(item.id);
    }));
    return future;
  }

  /// Like [ensure], and also regenerates Japanese content created without
  /// kanji readings (once per word). When that regeneration fails, the
  /// existing content is returned — it is still usable for reviews.
  Future<VocabularyItem?> ensureCurrent(VocabularyItem item) {
    if (!hasAiContent(item) || !item.lacksKanjiReadings) return ensure(item);
    if (!_readingRefreshes.add(item.id)) {
      return (_inFlight[item.id] ?? Future.value(item))
          .then((updated) => updated ?? item);
    }
    return ensure(item, force: true).then((updated) => updated ?? item);
  }

  Future<VocabularyItem?> _generate(VocabularyItem item) async {
    final generation = _generation;
    bool stale() => !identical(generation, _generation);

    _setStatus(item.id, AiContentStatus.generating);
    try {
      final nativeLanguage = await readNativeLanguage(ref);
      if (stale()) return null;
      final updated =
          await ref.read(aiExplanationServiceProvider).generateExplanation(
                vocabularyId: item.id,
                word: item.word,
                language: item.language,
                nativeLanguage: nativeLanguage,
              );
      if (stale()) return null;
      _setStatus(item.id, null);
      if (ref.exists(vocabularyNotifierProvider)) {
        ref
            .read(vocabularyNotifierProvider.notifier)
            .applyServerUpdate(updated);
      }
      AppLogger.debug('AI content generated', data: {'word': item.word});
      return updated;
    } catch (e, st) {
      if (stale()) return null;
      AppLogger.error(
        'AI content generation failed for "${item.word}"',
        error: e,
        stackTrace: st,
      );
      _setStatus(item.id, AiContentStatus.failed);
      return null;
    }
  }

  void _setStatus(String id, AiContentStatus? status) {
    final next = Map<String, AiContentStatus>.from(state);
    if (status == null) {
      next.remove(id);
    } else {
      next[id] = status;
    }
    state = next;
  }
}

final aiContentProvider =
    NotifierProvider<AiContentNotifier, Map<String, AiContentStatus>>(
  AiContentNotifier.new,
);

/// Status of a single word (rebuilds only that word's widgets).
final aiContentStatusProvider =
    Provider.autoDispose.family<AiContentStatus?, String>((ref, vocabularyId) {
  return ref.watch(aiContentProvider.select((s) => s[vocabularyId]));
});
