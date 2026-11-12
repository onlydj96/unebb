import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unebb/l10n/app_localizations.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
import 'package:unebb/core/theme/app_tone.dart';
import 'package:unebb/core/theme/app_typography.dart';
import 'package:unebb/features/review/providers/voice_mode_provider.dart';

/// Toggle button for voice mode in the app bar
class VoiceModeToggle extends ConsumerWidget {
  const VoiceModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      isSelected: voiceState.isEnabled,
      style: IconButton.styleFrom(
        backgroundColor:
            voiceState.isEnabled ? AppColors.mintSoft : Colors.transparent,
      ),
      icon: Icon(
        voiceState.isEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
        color: voiceState.isEnabled
            ? AppColors.successText
            : AppColors.textSecondary,
      ),
      tooltip: l10n.voiceMode,
      onPressed: () async {
        await ref.read(voiceModeProvider.notifier).toggleVoiceMode();

        if (context.mounted) {
          final newState = ref.read(voiceModeProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newState.isEnabled
                    ? l10n.voiceModeEnabled
                    : l10n.voiceModeDisabled,
              ),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );

          if (newState.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.voiceModeInitFailed),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
    );
  }
}

/// Voice indicator showing current voice mode status
class VoiceModeIndicator extends ConsumerWidget {
  const VoiceModeIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = AppLocalizations.of(context)!;

    if (!voiceState.isEnabled) return const SizedBox.shrink();

    String statusText;
    AppTone tone;
    IconData statusIcon;

    switch (voiceState.phase) {
      case VoiceModePhase.speakingWord:
        statusText = l10n.speakingWord;
        tone = AppTone.neutral;
        statusIcon = Icons.volume_up_rounded;
        break;
      case VoiceModePhase.askingKnowledge:
        statusText = l10n.doYouKnowThisWord;
        tone = AppTone.neutral;
        statusIcon = Icons.volume_up_rounded;
        break;
      case VoiceModePhase.speakingFeedback:
      case VoiceModePhase.speakingExample:
      case VoiceModePhase.speakingResult:
        statusText = l10n.speakingWord;
        tone = AppTone.neutral;
        statusIcon = Icons.volume_up_rounded;
        break;
      case VoiceModePhase.listeningKnowledge:
        statusText = l10n.listeningForYesNo;
        tone = AppTone.success;
        statusIcon = Icons.mic_rounded;
        break;
      case VoiceModePhase.listeningMeaning:
        statusText = l10n.listeningForMeaning;
        tone = AppTone.success;
        statusIcon = Icons.mic_rounded;
        break;
      case VoiceModePhase.listeningTranslation:
        statusText = l10n.listeningForTranslation;
        tone = AppTone.success;
        statusIcon = Icons.mic_rounded;
        break;
      case VoiceModePhase.waitingMeaning:
      case VoiceModePhase.waitingTranslation:
        statusText = l10n.tapMicToSpeak;
        tone = AppTone.neutral;
        statusIcon = Icons.mic_none_rounded;
        break;
      case VoiceModePhase.processingMeaning:
      case VoiceModePhase.processingTranslation:
        statusText = l10n.processing;
        tone = AppTone.warning;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case VoiceModePhase.idle:
        return const SizedBox.shrink();
    }
    final statusColor =
        tone == AppTone.neutral ? AppColors.textPrimary : tone.foreground;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tone == AppTone.neutral ? AppColors.surface : tone.soft,
        borderRadius: AppRadius.fullBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedIcon(
              icon: statusIcon,
              color: statusColor,
              isAnimating: voiceState.isSpeaking || voiceState.isListening),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              statusText,
              style: AppTypography.labelMedium.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated icon for speaking/listening states
class _AnimatedIcon extends StatefulWidget {
  const _AnimatedIcon({
    required this.icon,
    required this.color,
    required this.isAnimating,
  });

  final IconData icon;
  final Color color;
  final bool isAnimating;

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnimating) {
      return Icon(widget.icon, color: widget.color, size: 16);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(widget.icon, color: widget.color, size: 16),
        );
      },
    );
  }
}

/// Large microphone button for voice input
class VoiceMicButton extends ConsumerWidget {
  const VoiceMicButton({
    super.key,
    required this.onTap,
    this.size = 80,
  });

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceModeProvider);
    final isListening = voiceState.isListening;

    return Semantics(
      button: true,
      label: AppLocalizations.of(context)!.voiceMode,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isListening ? AppColors.mint : AppColors.cocoa,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isListening
                    ? AppColors.mint.withValues(alpha: 0.35)
                    : AppColors.cocoa.withValues(alpha: 0.0),
                spreadRadius: isListening ? size * 0.14 : 0,
              ),
            ],
          ),
          child: Icon(
            isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: isListening ? AppColors.cocoa : AppColors.paper,
            size: size * 0.42,
          ),
        ),
      ),
    );
  }
}

/// Transcript display showing what was recognized
class VoiceTranscriptDisplay extends ConsumerWidget {
  const VoiceTranscriptDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceModeProvider);

    if (voiceState.currentTranscript.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.largeBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.format_quote_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              voiceState.currentTranscript,
              style: AppTypography.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
