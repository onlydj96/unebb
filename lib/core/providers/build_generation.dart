import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets a keep-alive notifier tell whether async work it started is still
/// relevant.
///
/// User-scoped notifiers rebuild when the account changes; a background sync
/// started for the previous account must not write its result into the new
/// account's state (or into a disposed container).
mixin BuildGeneration {
  Object _generation = Object();

  /// Call at the top of `build()`. Returns the token for this build.
  Object beginGeneration(Ref ref) {
    final token = _generation = Object();
    ref.onDispose(() {
      if (identical(_generation, token)) _generation = Object();
    });
    return token;
  }

  /// Whether [token] still belongs to the live build.
  bool isCurrentGeneration(Object token) => identical(token, _generation);
}
