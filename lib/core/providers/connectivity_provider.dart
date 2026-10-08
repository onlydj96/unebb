import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that streams connectivity status changes
final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider that checks if device is currently online
final isOnlineProvider = Provider<bool>((ref) {
  final connectivityAsyncValue = ref.watch(connectivityStreamProvider);

  return connectivityAsyncValue.maybeWhen(
    data: (results) => !results.contains(ConnectivityResult.none),
    orElse: () => true, // Assume online if unknown
  );
});

/// Provider for one-time connectivity check
final connectivityCheckProvider = FutureProvider<List<ConnectivityResult>>(
  (ref) async {
    return await Connectivity().checkConnectivity();
  },
);
