import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/providers/connectivity_provider.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/shared/widgets/app_notice.dart';

/// Inline notice shown while the device is offline (cached data is shown).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOnlineProvider)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppNotice(
        tone: AppTone.warning,
        icon: Icons.cloud_off_rounded,
        message: context.l10n.offlineBanner,
        dense: true,
      ),
    );
  }
}
