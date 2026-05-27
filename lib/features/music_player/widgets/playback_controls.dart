import 'package:flutter/material.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filled(
          icon: const Icon(Icons.skip_previous, size: 28),
          onPressed: onPrevious,
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            size: 36,
          ),
          onPressed: onPlayPause,
          style: IconButton.styleFrom(
            minimumSize: const Size(64, 64),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(Icons.skip_next, size: 28),
          onPressed: onNext,
        ),
      ],
    );
  }
}
