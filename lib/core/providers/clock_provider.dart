import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time for content that depends on it (due counts, memory
/// strength decay), so it updates while the app stays open.
///
/// Advanced by the app shell ([ClockNotifier.tick] every
/// [ClockNotifier.tickInterval] while the app is visible, and on resume).
/// Event times such as "reviewed at" read `DateTime.now()` directly.
final clockProvider = NotifierProvider<ClockNotifier, DateTime>(
  ClockNotifier.new,
);

class ClockNotifier extends Notifier<DateTime> {
  static const Duration tickInterval = Duration(minutes: 1);

  @override
  DateTime build() => DateTime.now().toUtc();

  void tick() => state = DateTime.now().toUtc();
}
