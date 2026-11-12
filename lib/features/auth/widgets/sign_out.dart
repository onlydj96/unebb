import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/services/cache_service.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/utils/logger.dart';
import 'package:unebb/features/auth/providers/auth_provider.dart';

/// Asks for confirmation, wipes locally cached user data and signs out.
///
/// Shared by every sign-out entry point so none of them can skip the
/// confirmation or leave the previous account's data on the device.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.signOutConfirmTitle),
      content: Text(l10n.signOutConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l10n.signOut),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(cacheServiceProvider).clearAll();
  } catch (e) {
    AppLogger.warning('Failed to clear cache on sign-out', details: e);
  }
  await signOut();
}
