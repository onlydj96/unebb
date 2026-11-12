import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/exceptions/app_exceptions.dart';
import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/features/decks/providers/deck_providers.dart';

/// Explains where the duplicate lives ("already in the TOEIC deck") instead
/// of a generic or raw database message.
String duplicateWordMessage(
  AppLocalizations l10n,
  WidgetRef ref,
  DuplicateWordException error, {
  String? currentDeckId,
}) {
  final existingDeckId = error.existingDeckId;
  if (existingDeckId != null && existingDeckId != currentDeckId) {
    final deckName = ref
        .read(deckListProvider)
        .valueOrNull
        ?.where((d) => d.id == existingDeckId)
        .firstOrNull
        ?.name;
    if (deckName != null) return l10n.duplicateWordInDeck(error.word, deckName);
  }
  if (currentDeckId != null && existingDeckId == currentDeckId) {
    return l10n.duplicateWordError(error.word);
  }
  return l10n.duplicateWordErrorGeneral;
}
