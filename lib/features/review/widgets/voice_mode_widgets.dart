import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_radius.dart';
import 'package:unebb/core/theme/app_spacing.dart';
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
      icon: Icon(
        voiceState.isEnabled ? Icons.mic : Icons.mic_off,
        color: voiceState.isEnabled ? AppColors.primary : AppColors.textMuted,
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
    Color statusColor;
    IconData statusIcon;

    switch (voiceState.phase) {
      case VoiceModePhase.speakingWord:
        statusText = l10n.speakingWord;
        statusColor = AppColors.primary;
        statusIcon = Icons.volume_up;
        break;
      case VoiceModePhase.askingKnowledge:
        statusText = l10n.doYouKnowThisWord;
        statusColor = AppColors.primary;
        statusIcon = Icons.volume_up;
        break;
      case VoiceModePhase.speakingFeedback:
      case VoiceModePhase.speakingExample:
      case VoiceModePhase.speakingResult:
        statusText = l10n.speakingWord;
        statusColor = AppColors.primary;
        statusIcon = Icons.volume_up;
        break;
      case VoiceModePhase.listeningKnowledge:
        statusText = l10n.listeningForYesNo;
        statusColor = AppColors.success;
        statusIcon = Icons.mic;
        break;
      case VoiceModePhase.listeningMeaning:
        statusText = l10n.listeningForMeaning;
        statusColor = AppColors.success;
        statusIcon = Icons.mic;
        break;
      case VoiceModePhase.listeningTranslation:
        statusText = l10n.listeningForTranslation;
        statusColor = AppColors.success;
        statusIcon = Icons.mic;
        break;
      case VoiceModePhase.waitingMeaning:
      case VoiceModePhase.waitingTranslation:
        statusText = l10n.tapMicToSpeak;
        statusColor = AppColors.secondary;
        statusIcon = Icons.mic_none;
        break;
      case VoiceModePhase.processingMeaning:
      case VoiceModePhase.processingTranslation:
        statusText = l10n.processing;
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_empty;
        break;
      case VoiceModePhase.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(color: statusColor.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedIcon(icon: statusIcon, color: statusColor, isAnimating: voiceState.isSpeaking || voiceState.isListening),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              statusText,
              style: AppTypography.bodySmall.copyWith(color: statusColor),
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isListening
              ? AppColors.success.withAlpha(25)
              : AppColors.primary.withAlpha(25),
          shape: BoxShape.circle,
          border: Border.all(
            color: isListening ? AppColors.success : AppColors.primary,
            width: 3,
          ),
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: AppColors.success.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          color: isListening ? AppColors.success : AppColors.primary,
          size: size * 0.5,
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
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(color: AppColors.textMuted.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_quote, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              voiceState.currentTranscript,
              style: AppTypography.bodyMedium.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Voice mode card for flash card front (voice mode version)
class VoiceFlashCardFront extends ConsumerWidget {
  const VoiceFlashCardFront({
    super.key,
    required this.word,
    required this.language,
    required this.onMicTap,
  });

  final String word;
  final String language;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xLargeBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(word, style: AppTypography.displayMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  language,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                const VoiceModeIndicator(),
                const SizedBox(height: AppSpacing.lg),
                VoiceMicButton(onTap: onMicTap),
                const SizedBox(height: AppSpacing.md),
                Text(
                  voiceState.isListening ? l10n.tapToStopListening : l10n.tapMicToSpeak,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                const VoiceTranscriptDisplay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Voice mode translation input view
class VoiceTranslationView extends ConsumerWidget {
  const VoiceTranslationView({
    super.key,
    required this.sentence,
    required this.wordHint,
    required this.targetLanguage,
    required this.onMicTap,
  });

  final String sentence;
  final String? wordHint;
  final String targetLanguage;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceModeProvider);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.translateInto(targetLanguage),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.largeBorder,
              border: Border.all(color: AppColors.secondary.withAlpha(80)),
            ),
            child: Text(sentence, style: AppTypography.bodyLarge),
          ),
          if (wordHint != null && wordHint!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  l10n.hintUseWord(wordHint!),
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const Center(child: VoiceModeIndicator()),
          const SizedBox(height: AppSpacing.lg),
          Center(child: VoiceMicButton(onTap: onMicTap, size: 100)),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              voiceState.isListening ? l10n.tapToStopListening : l10n.tapMicToSpeak,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const VoiceTranscriptDisplay(),
        ],
      ),
    );
  }
}

/// Waveform animation for listening state
class ListeningWaveform extends StatefulWidget {
  const ListeningWaveform({super.key, this.color = AppColors.success});

  final Color color;

  @override
  State<ListeningWaveform> createState() => _ListeningWaveformState();
}

class _ListeningWaveformState extends State<ListeningWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final delay = index * 0.2;
            final value = (((_controller.value + delay) % 1.0) * 2 - 1).abs();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 8 + (value * 16),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
