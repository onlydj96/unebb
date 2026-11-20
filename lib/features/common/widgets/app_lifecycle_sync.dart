import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/providers/clock_provider.dart';
import 'package:unebb/core/providers/connectivity_provider.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';
import 'package:unebb/features/vocabulary/providers/vocabulary_providers.dart';

/// Keeps app-wide data current while the app runs:
///
/// - advances [clockProvider] every [ClockNotifier.tickInterval] while the
///   app is visible, and right away when it returns to the foreground, so
///   due counts and memory decay follow the time;
/// - on returning to the foreground or coming back online, syncs the word
///   list and memory states. That picks up reviews made on other devices
///   and saves reviews whose save failed.
class AppLifecycleSync extends ConsumerStatefulWidget {
  const AppLifecycleSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleSync> createState() => _AppLifecycleSyncState();
}

class _AppLifecycleSyncState extends ConsumerState<AppLifecycleSync> {
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(clockProvider.notifier).tick();
        _startTicker();
        unawaited(_resync());
      },
      onHide: _stopTicker,
    );
    // No tick here: providers must not change while the tree builds, and the
    // clock starts at the current time anyway.
    _startTicker();
  }

  @override
  void dispose() {
    _stopTicker();
    _lifecycle.dispose();
    super.dispose();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(
      ClockNotifier.tickInterval,
      (_) => ref.read(clockProvider.notifier).tick(),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Syncs only lists already in use; `sync` skips the server when it
  /// synced moments ago.
  Future<void> _resync() async {
    if (ref.read(currentUserIdProvider) == null) return;
    try {
      await Future.wait([
        if (ref.exists(vocabularyNotifierProvider))
          ref.read(vocabularyNotifierProvider.notifier).sync(),
        if (ref.exists(memoryStatesMapNotifierProvider))
          ref.read(memoryStatesMapNotifierProvider.notifier).sync(),
      ]);
    } catch (e) {
      AppLogger.warning('Resync failed', details: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (wasOnline, online) {
      if (wasOnline == false && online) unawaited(_resync());
    });
    return widget.child;
  }
}
