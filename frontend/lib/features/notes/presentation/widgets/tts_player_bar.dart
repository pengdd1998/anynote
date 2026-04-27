import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/tts/speech_service.dart';
import '../../../../l10n/app_localizations.dart';

/// Compact bottom bar for controlling text-to-speech playback.
///
/// Shows play/pause, stop, speed controls, and progress indicator.
class TtsPlayerBar extends ConsumerStatefulWidget {
  const TtsPlayerBar({super.key});

  @override
  ConsumerState<TtsPlayerBar> createState() => _TtsPlayerBarState();
}

class _TtsPlayerBarState extends ConsumerState<TtsPlayerBar> {
  double _speechRate = 1.0;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    final service = ref.read(speechServiceProvider);
    service.progressStream.listen((progress) {
      if (mounted) setState(() => _progress = progress);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final service = ref.read(speechServiceProvider);
    final stateAsync = ref.watch(speechStateProvider);
    final state = stateAsync.valueOrNull ?? SpeechState.stopped;

    if (state == SpeechState.stopped) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              // Controls row
              Row(
                children: [
                  // Stop button
                  IconButton(
                    icon: const Icon(Icons.stop),
                    iconSize: 20,
                    tooltip: l10n.stopReading,
                    onPressed: () {
                      service.stop();
                    },
                  ),
                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      state == SpeechState.playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                    ),
                    iconSize: 32,
                    tooltip: state == SpeechState.playing
                        ? l10n.pauseReading
                        : l10n.resumeReading,
                    onPressed: () {
                      if (state == SpeechState.playing) {
                        service.pause();
                      } else {
                        service.resume();
                      }
                    },
                  ),
                  // Speed selector
                  _buildSpeedChip(theme, l10n),
                  const Spacer(),
                  // Rate display
                  Text(
                    '${_speechRate}x',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedChip(ThemeData theme, AppLocalizations l10n) {
    final service = ref.read(speechServiceProvider);
    return PopupMenuButton<double>(
      offset: const Offset(0, -100),
      tooltip: l10n.readingSpeed,
      child: Chip(
        label: Text(
          '${_speechRate}x',
          style: theme.textTheme.labelSmall,
        ),
        avatar: const Icon(Icons.speed, size: 14),
        visualDensity: VisualDensity.compact,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0.5, child: Text('0.5x')),
        const PopupMenuItem(value: 0.75, child: Text('0.75x')),
        const PopupMenuItem(value: 1.0, child: Text('1.0x')),
        const PopupMenuItem(value: 1.25, child: Text('1.25x')),
        const PopupMenuItem(value: 1.5, child: Text('1.5x')),
        const PopupMenuItem(value: 2.0, child: Text('2.0x')),
      ],
      onSelected: (rate) {
        setState(() => _speechRate = rate);
        service.setRate(rate);
      },
    );
  }
}
