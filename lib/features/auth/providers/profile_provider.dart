import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:unebb/core/constants/languages.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';

/// Lightweight profile model — only fields needed at runtime.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.nativeLanguage,
    required this.learningLanguage,
  });

  final String id;
  final String displayName;
  final String nativeLanguage;
  final String learningLanguage;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      nativeLanguage: json['native_language'] as String? ?? 'Korean',
      learningLanguage: json['learning_language'] as String? ?? 'English',
    );
  }
}

/// The learner's native language for AI prompts.
///
/// Never throws: if the profile cannot be loaded (offline, server error) the
/// default language is used and [profileProvider] is reset so the next call
/// retries. A failed fetch used to stay cached in the keep-alive provider and
/// break every review start and AI request until the app was restarted.
Future<String> readNativeLanguage(Ref ref) async {
  try {
    final profile = await ref.read(profileProvider.future);
    return profile?.nativeLanguage ?? SupportedLanguages.defaultNative;
  } catch (e) {
    AppLogger.warning(
      'Profile unavailable; using the default native language',
      details: e,
    );
    ref.invalidate(profileProvider);
    return SupportedLanguages.defaultNative;
  }
}

/// Fetches the signed-in user's profile row from `profiles`.
/// Uses local cache for instant load, then syncs from network.
final profileProvider = FutureProvider<UserProfile?>((ref) async {
  // Keep this provider alive to avoid refetching on every access; it still
  // rebuilds whenever the signed-in user changes.
  ref.keepAlive();

  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final client = Supabase.instance.client;
  final cacheService = ref.watch(cacheServiceProvider);

  // 1. Try to return cached profile immediately
  final cached = cacheService.getCachedProfile();
  if (cached != null && cached.id == userId) {
    // Background sync: fetch fresh data and update cache (fire-and-forget with logging)
    unawaited(_syncProfileInBackground(client, userId, cacheService));
    return cached;
  }

  // 2. No cache or different user - fetch from network
  final rows = await client.from('profiles').select().eq('id', userId).limit(1);

  if (rows.isEmpty) return null;

  final profile = UserProfile.fromJson(rows.first);

  // Cache the fetched profile
  await cacheService.cacheProfile(profile);

  return profile;
});

/// Background sync helper - updates cache without blocking UI.
Future<void> _syncProfileInBackground(
  SupabaseClient client,
  String userId,
  CacheService cacheService,
) async {
  try {
    final rows =
        await client.from('profiles').select().eq('id', userId).limit(1);

    if (rows.isNotEmpty) {
      final profile = UserProfile.fromJson(rows.first);
      await cacheService.cacheProfile(profile);
      AppLogger.debug('Profile synced in background', data: {'userId': userId});
    }
  } catch (e, st) {
    AppLogger.warning('Background profile sync failed', details: e);
    AppLogger.debug('Stack trace', data: st);
  }
}
