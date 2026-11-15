/// Incremental sync of a cached list against the server.
///
/// Instead of downloading every row on each launch, only rows whose server
/// `updated_at` changed since the last sync are fetched (every insert and
/// update moves `updated_at` through the `set_updated_at` triggers), plus a
/// row count to notice deletions made elsewhere.
library;

/// Rows changed shortly before the cursor are fetched again: `updated_at` is
/// the transaction start time, so a transaction that committed after the
/// previous sync can carry a slightly older timestamp.
const Duration kDeltaSyncOverlap = Duration(minutes: 2);

class DeltaSyncResult<T> {
  const DeltaSyncResult({required this.items, required this.newestChange});

  /// The cached rows with every changed row applied and deleted rows removed
  /// (unordered).
  final List<T> items;

  /// Newest `updated_at` among the downloaded rows (null: nothing changed).
  final DateTime? newestChange;
}

/// Reconciles [cached] with the server.
///
/// Returns null when the result cannot be trusted (the server has rows the
/// cache lacks that the delta did not return); the caller then downloads
/// everything.
///
/// Correctness relies on [cached] being complete as of [since]: then the
/// merged set is a superset of the server's rows, and equal row counts mean
/// equal sets.
Future<DeltaSyncResult<T>?> deltaSync<T>({
  required List<T> cached,
  required DateTime since,
  required String Function(T item) keyOf,
  required DateTime Function(T item) updatedAtOf,
  required Future<List<T>> Function(DateTime since) fetchChanged,
  required Future<int> Function() fetchCount,
  required Future<Set<String>> Function() fetchKeys,
  Duration overlap = kDeltaSyncOverlap,
}) async {
  // Future.wait (not a record `.wait`) so the original error is rethrown.
  final results = await Future.wait<Object>([
    fetchChanged(since.subtract(overlap)),
    fetchCount(),
  ]);
  final changed = results[0] as List<T>;
  final serverCount = results[1] as int;

  final merged = <String, T>{for (final item in cached) keyOf(item): item};
  for (final item in changed) {
    merged[keyOf(item)] = item;
  }

  if (merged.length != serverCount) {
    // Rows were deleted elsewhere, or a row changed between the two queries.
    final keys = await fetchKeys();
    merged.removeWhere((key, _) => !keys.contains(key));
    if (merged.length != keys.length) return null;
  }

  DateTime? newest;
  for (final item in changed) {
    final updatedAt = updatedAtOf(item);
    if (newest == null || updatedAt.isAfter(newest)) newest = updatedAt;
  }
  return DeltaSyncResult(items: merged.values.toList(), newestChange: newest);
}
