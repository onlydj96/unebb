// AppLifecycleSync: the clock follows the time while the app is visible and
// data is synced when the app returns or the connection comes back.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unebb/core/providers/clock_provider.dart';
import 'package:unebb/core/providers/connectivity_provider.dart';
import 'package:unebb/domain/models/memory_state.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/common/widgets/app_lifecycle_sync.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

import '../helpers/fakes.dart';

class _CountingMemoryNotifier extends MemoryStatesMapNotifier {
  int syncs = 0;

  @override
  Future<Map<String, MemoryState>> build() async => const {};

  @override
  Future<Map<String, MemoryState>> sync() async {
    syncs++;
    return const {};
  }
}

final _online = StateProvider<bool>((_) => true);

class _App {
  _App(this.container, this.memory);

  final ProviderContainer container;
  final _CountingMemoryNotifier memory;
  int ticks = 0;
}

Future<_App> _pump(WidgetTester tester) async {
  final memory = _CountingMemoryNotifier();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(kTestUserId),
      isOnlineProvider.overrideWith((ref) => ref.watch(_online)),
      memoryStatesMapNotifierProvider.overrideWith(() => memory),
    ],
    child: const AppLifecycleSync(child: SizedBox()),
  ));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
  final app = _App(container, memory);
  container.listen(clockProvider, (_, __) => app.ticks++);
  // In use, as on the dashboard.
  await container.read(memoryStatesMapNotifierProvider.future);
  return app;
}

void _lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets('the clock ticks every minute while the app is visible',
      (tester) async {
    final app = await _pump(tester);

    await tester.pump(ClockNotifier.tickInterval);
    expect(app.ticks, 1);
    await tester.pump(ClockNotifier.tickInterval);
    expect(app.ticks, 2);
  });

  testWidgets('hidden: no ticks; back in front: tick and sync at once',
      (tester) async {
    final app = await _pump(tester);

    _lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.hidden]);
    await tester.pump(ClockNotifier.tickInterval * 3);
    expect(app.ticks, 0);
    expect(app.memory.syncs, 0);

    _lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.resumed]);
    await tester.pump();
    expect(app.ticks, 1);
    expect(app.memory.syncs, 1);
  });

  testWidgets('data is synced when the connection comes back', (tester) async {
    final app = await _pump(tester);

    app.container.read(_online.notifier).state = false;
    await tester.pump();
    expect(app.memory.syncs, 0);

    app.container.read(_online.notifier).state = true;
    await tester.pump();
    expect(app.memory.syncs, 1);
  });
}
