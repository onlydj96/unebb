import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/domain/services/memory_service.dart';
import 'package:unebb/domain/services/review_queue_builder.dart';

import '../../helpers/fakes.dart';

/// Deterministic Random: shuffles keep order, the dice always rolls 0.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

void main() {
  const sut = ReviewQueueBuilder();
  final now = DateTime.utc(2026, 11, 9, 12);

  test('"due" mode leaves out recalled words whose review time has not come',
      () {
    MemoryState recalled(String id, DateTime nextReviewAt) =>
        memory(id, reviewCount: 1, repetitions: 1, nextReviewAt: nextReviewAt);
    final states = [
      recalled('due', now.subtract(const Duration(hours: 1))),
      recalled('exact', now),
      recalled('later', now.add(const Duration(days: 1))),
    ];

    final queue = sut.build(states, mode: 'due', now: now);

    expect(queue.map((s) => s.vocabularyId), unorderedEquals(['due', 'exact']));
  });

  test('"due" mode takes words being learnt or just missed at once', () {
    final tomorrow = now.add(const Duration(days: 1));
    final states = [
      // Missed this morning, never recalled: scheduled for tomorrow.
      memory('learning',
          reviewCount: 2, incorrectCount: 2, nextReviewAt: tomorrow),
      // Recalled before, missed this morning.
      memory('lapsed',
          reviewCount: 3,
          correctCount: 2,
          incorrectCount: 1,
          consecutiveCorrect: 0,
          nextReviewAt: tomorrow),
      memory('recalled',
          reviewCount: 1, repetitions: 1, nextReviewAt: tomorrow),
    ];

    final queue = sut.build(states, mode: 'due', now: now);

    expect(queue.map((s) => s.vocabularyId),
        unorderedEquals(['learning', 'lapsed']));
  });

  test('"all" mode includes every word exactly once', () {
    final states = [
      for (var i = 0; i < 20; i++)
        memory(
          'w$i',
          reviewCount: i % 3,
          strength: (i % 5) / 5,
          incorrectCount: i % 2,
          nextReviewAt: now.add(Duration(days: i - 10)),
        ),
    ];

    final queue = sut.build(states, mode: 'all', now: now, random: Random(7));

    expect(queue, hasLength(20));
    expect(queue.map((s) => s.vocabularyId).toSet(), hasLength(20));
  });

  test('never-reviewed words come before reviewed ones', () {
    final states = [
      memory('old1', reviewCount: 3, strength: 0.1),
      memory('new1'),
      memory('old2', reviewCount: 1, strength: 0.9),
      memory('new2'),
    ];

    final queue = sut.build(states, mode: 'all', now: now, random: Random(1));

    expect(
      queue.take(2).map((s) => s.vocabularyId),
      unorderedEquals(['new1', 'new2']),
    );
  });

  test('struggling words are prioritised over well-known ones', () {
    // Recalled once, then missed three times.
    final weak = memory('weak',
        reviewCount: 4, correctCount: 1, incorrectCount: 3, repetitions: 0);
    final strong = memory('strong',
        reviewCount: 4,
        repetitions: 4,
        interval: 45,
        nextReviewAt: now.add(const Duration(days: 20)));

    expect(
        sut.priorityScore(weak, now), lessThan(sut.priorityScore(strong, now)));

    final queue = sut.order([strong, weak], now: now, random: _ZeroRandom());
    expect(queue.first.vocabularyId, 'weak');
  });

  test('priority follows the strength the learner sees, not the stored one',
      () {
    // Stored strengths are stale on purpose: the first word was just missed,
    // the second just recalled.
    final missed = memory('missed',
        reviewCount: 3,
        strength: 0.85,
        correctCount: 2,
        incorrectCount: 1,
        consecutiveCorrect: 0,
        nextReviewAt: now.add(const Duration(days: 1)));
    final recalled = memory('recalled',
        reviewCount: 1,
        repetitions: 1,
        nextReviewAt: now.add(const Duration(days: 1)));

    expect(sut.priorityScore(missed, now),
        lessThan(sut.priorityScore(recalled, now)));
  });

  test('a word fading past its due day moves up', () {
    final onTime = memory('on-time',
        reviewCount: 4,
        repetitions: 4,
        interval: 45,
        nextReviewAt: now.add(const Duration(days: 5)));
    final fading = memory('fading',
        reviewCount: 4,
        repetitions: 4,
        interval: 45,
        nextReviewAt: now.subtract(const Duration(days: 60)));

    expect(sut.priorityScore(fading, now),
        lessThan(sut.priorityScore(onTime, now)));
  });

  group('a limited session', () {
    const ms = MemoryService();
    final yesterday = now.subtract(const Duration(days: 1));
    MemoryState missed(String id) =>
        ms.applySmTwo(memory(id, nextReviewAt: yesterday), 0, now: yesterday);
    MemoryState recalled(String id) =>
        ms.applySmTwo(memory(id, nextReviewAt: yesterday), 1, now: yesterday);
    bool struggling(MemoryState s) => s.consecutiveCorrect == 0;

    test('is filled with words being learnt before remembered ones', () {
      final states = [
        for (var i = 0; i < 40; i++) recalled('known$i'),
        for (var i = 0; i < 12; i++) missed('learning$i'),
      ];

      for (var seed = 0; seed < 50; seed++) {
        final queue =
            sut.build(states, mode: 'all', now: now, random: Random(seed));
        expect(queue.take(10).every(struggling), isTrue, reason: 'seed $seed');
      }
    });

    test('takes every word being learnt before any remembered one', () {
      final states = [
        for (var i = 0; i < 40; i++) recalled('known$i'),
        for (var i = 0; i < 4; i++) missed('learning$i'),
      ];

      for (var seed = 0; seed < 50; seed++) {
        final queue =
            sut.build(states, mode: 'due', now: now, random: Random(seed));
        expect(queue.take(4).every(struggling), isTrue, reason: 'seed $seed');
      }
    });

    test('shows remembered words weakest first', () {
      final fresh = recalled('fresh');
      final mature = memory('mature',
          reviewCount: 5,
          repetitions: 5,
          interval: 60,
          nextReviewAt: now.add(const Duration(days: 30)));
      final fading = recalled('fading')
          .copyWith(nextReviewAt: now.subtract(const Duration(days: 4)));

      final queue =
          sut.order([mature, fresh, fading], now: now, random: Random(3));

      expect(queue.map((s) => s.vocabularyId), ['fading', 'fresh', 'mature']);
    });

    test('varies the order of equally urgent words', () {
      final states = [for (var i = 0; i < 10; i++) missed('learning$i')];
      final orders = {
        for (var seed = 0; seed < 5; seed++)
          sut
              .order(states, now: now, random: Random(seed))
              .map((s) => s.vocabularyId)
              .join(','),
      };
      expect(orders.length, greaterThan(1));
    });
  });

  test('empty input yields an empty queue', () {
    expect(sut.build(const [], mode: 'all'), isEmpty);
  });
}
