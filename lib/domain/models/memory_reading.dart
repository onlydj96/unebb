/// How well a word is remembered, as shown to the learner (ebb → flow).
///
/// Derived by `MemoryService.readingOf`; never decided by the LLM.
enum MemoryLevel {
  /// Reviewed, but never recalled yet: not learnt, so nothing to forget.
  learning(4),

  /// Learnt, but the last answer was wrong or it has most likely been
  /// forgotten since.
  critical(4),

  /// Learnt, overdue and fading.
  weak(3),

  /// Recalled and still remembered; reviewed over a few weeks at most.
  good(2),

  /// Recalled and still remembered after a review interval of 3+ weeks.
  strong(1);

  const MemoryLevel(this.stage);

  /// Value stored in `memory_states.stage` (1 = strong … 4 = critical).
  final int stage;
}

/// A word's memory at one moment: its [level] and [strength] (0.0–1.0).
class MemoryReading {
  const MemoryReading(this.level, this.strength);

  final MemoryLevel level;

  /// 0.0 while the word is [MemoryLevel.learning] or was just missed.
  final double strength;

  @override
  bool operator ==(Object other) =>
      other is MemoryReading &&
      other.level == level &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(level, strength);

  @override
  String toString() => 'MemoryReading($level, $strength)';
}
