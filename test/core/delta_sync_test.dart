import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/core/services/delta_sync.dart';

typedef _Row = ({String id, String value, DateTime updatedAt});

_Row _row(String id, {String value = 'v', DateTime? updatedAt}) =>
    (id: id, value: value, updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1));

class _Server {
  _Server(this.rows);

  final List<_Row> rows;
  DateTime? askedSince;
  int keyFetches = 0;

  Future<DeltaSyncResult<_Row>?> sync(List<_Row> cached, DateTime since) =>
      deltaSync<_Row>(
        cached: cached,
        since: since,
        keyOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        fetchChanged: (since) async {
          askedSince = since;
          return [
            for (final r in rows)
              if (!r.updatedAt.isBefore(since)) r,
          ];
        },
        fetchCount: () async => rows.length,
        fetchKeys: () async {
          keyFetches++;
          return {for (final r in rows) r.id};
        },
      );
}

void main() {
  final cursor = DateTime.utc(2026, 1, 15);
  final later = DateTime.utc(2026, 2, 1);

  test('applies rows changed since the cursor and keeps the rest', () async {
    final server = _Server([
      _row('a', value: 'edited', updatedAt: later),
      _row('b'),
      _row('c', updatedAt: later),
    ]);

    final result = await server.sync([_row('a'), _row('b')], cursor);

    expect(
      {for (final r in result!.items) r.id: r.value},
      {'a': 'edited', 'b': 'v', 'c': 'v'},
    );
    expect(result.newestChange, later);
    // Row counts match: no need to list the server's IDs.
    expect(server.keyFetches, 0);
  });

  test('re-reads a short window before the cursor', () async {
    final server = _Server([_row('a')]);

    await server.sync([_row('a')], cursor);

    expect(server.askedSince, cursor.subtract(kDeltaSyncOverlap));
  });

  test('notices rows deleted elsewhere through the row count', () async {
    final server = _Server([_row('a')]);

    final result = await server.sync([_row('a'), _row('b')], cursor);

    expect(result!.items.map((r) => r.id), ['a']);
    expect(result.newestChange, isNull);
    expect(server.keyFetches, 1);
  });

  test('gives up when the server has rows the delta did not return', () async {
    // 'c' predates the cursor but is missing from the cache: the cache was
    // not complete, so only a full download can be trusted.
    final server = _Server([_row('a'), _row('b'), _row('c')]);

    expect(await server.sync([_row('a'), _row('b')], cursor), isNull);
  });
}
