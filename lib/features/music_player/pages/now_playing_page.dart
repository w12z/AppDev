import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../services/audio_player_service.dart';
import 'equalizer_page.dart';
import '../widgets/output_device_sheet.dart';
import '../widgets/playback_controls.dart';
import '../widgets/progress_bar.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  double _dragOffset = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('正在播放'),
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<AudioPlayerService>(
        builder: (context, player, _) {
          final track = player.currentTrack;
          if (track == null) {
            return const Center(child: Text('未选择曲目'));
          }

          final playlists = player.queuePlaylists;
          final hasMulti = playlists.length > 1;

          return SafeArea(
            child: Column(
              children: [
                // Playlist indicator chips (multi only)
                if (hasMulti) _buildPlaylistIndicator(playlists, player.activePlaylistIndex),
                // Card stack or single track view
                Expanded(
                  child: hasMulti
                      ? _buildCardStack(playlists, player, theme)
                      : _buildSingleTrackView(track, player, theme),
                ),
                // Controls (always below)
                _buildControlsSection(player, theme),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Playlist indicator chips ──

  Widget _buildPlaylistIndicator(List<QueuePlaylist> playlists, int activeIndex) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final isActive = index == activeIndex;
          final theme = Theme.of(context);
          return GestureDetector(
            onTap: () {
              if (!isActive && !_isAnimating) {
                _animateToPlaylist(index, playlists.length);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isActive ? theme.colorScheme.primaryContainer : null,
              ),
              child: Text(
                playlists[index].name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Single track view (original layout, no card stack) ──

  Widget _buildSingleTrackView(track, AudioPlayerService player, ThemeData theme) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) {
          player.next();
        } else if (details.primaryVelocity! > 300) {
          player.previous();
        }
      },
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildAlbumArt(track, theme),
          const Spacer(flex: 2),
          _buildTrackInfo(track, theme),
        ],
      ),
    );
  }

  // ── Card stack (multi-playlist) ──

  Widget _buildCardStack(List<QueuePlaylist> playlists, AudioPlayerService player, ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.75;
    final activeIndex = player.activePlaylistIndex;

    return GestureDetector(
      onHorizontalDragStart: (_) {
        if (_isAnimating) return;
        _slideController.stop();
      },
      onHorizontalDragUpdate: (details) {
        if (_isAnimating) return;
        _dragOffset += details.delta.dx;
        setState(() {});
      },
      onHorizontalDragEnd: (details) {
        if (_isAnimating) return;
        final threshold = screenWidth * 0.15;
        final velocity = details.primaryVelocity ?? 0;

        if (_dragOffset < -threshold && activeIndex < playlists.length - 1) {
          _animateToPlaylist(activeIndex + 1, playlists.length);
        } else if (_dragOffset > threshold && activeIndex > 0) {
          _animateToPlaylist(activeIndex - 1, playlists.length);
        } else if (velocity < -300 && activeIndex < playlists.length - 1) {
          _animateToPlaylist(activeIndex + 1, playlists.length);
        } else if (velocity > 300 && activeIndex > 0) {
          _animateToPlaylist(activeIndex - 1, playlists.length);
        } else {
          _snapBack();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final i in _sortedIndices(playlists.length, activeIndex))
            _buildStackCard(playlists[i], i, activeIndex, cardWidth, screenWidth, theme),
        ],
      ),
    );
  }

  Widget _buildStackCard(
    QueuePlaylist qp,
    int index,
    int activeIndex,
    double cardWidth,
    double screenWidth,
    ThemeData theme,
  ) {
    final offset = index - activeIndex;
    if (offset.abs() > 2) return const SizedBox.shrink();

    final isActive = offset == 0;
    final opacity = isActive ? 1.0 : (offset.abs() == 1 ? 0.5 : 0.25);
    final scale = isActive ? 1.0 : (offset.abs() == 1 ? 0.9 : 0.82);
    final baseX = offset * cardWidth * 0.5;
    final xOffset = baseX + _dragOffset;

    return AnimatedPositioned(
      duration: _isAnimating ? const Duration(milliseconds: 300) : Duration.zero,
      curve: Curves.easeOutCubic,
      left: (screenWidth - cardWidth) / 2 + xOffset,
      width: cardWidth,
      top: 0,
      bottom: 0,
      child: AnimatedScale(
        duration: _isAnimating ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: opacity,
          child: Card(
            elevation: isActive ? 8 : 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: isActive
                ? _buildActiveCardContent(qp, theme)
                : _buildPreviewCardContent(qp, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCardContent(QueuePlaylist qp, ThemeData theme) {
    final track = qp.currentTrack;
    if (track == null) {
      return const Center(child: Text('无曲目'));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            qp.name,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(flex: 2),
          Hero(
            tag: 'album_art_${track.path}',
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.music_note,
                size: 60,
                color: theme.colorScheme.primary.withAlpha(80),
              ),
            ),
          ),
          const Spacer(flex: 2),
          _buildTrackInfo(track, theme),
        ],
      ),
    );
  }

  Widget _buildPreviewCardContent(QueuePlaylist qp, ThemeData theme) {
    return Center(
      child: Icon(
        Icons.queue_music,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
      ),
    );
  }

  // ── Shared widgets ──

  Widget _buildAlbumArt(track, ThemeData theme) {
    return Hero(
      tag: 'album_art_${track.path}',
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.secondaryContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.music_note,
          size: 80,
          color: theme.colorScheme.primary.withAlpha(80),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(track, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            track.title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            track.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection(AudioPlayerService player, ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ProgressBar(
            position: player.position,
            duration: player.duration,
            onSeek: (fraction) {
              final seekTo = Duration(
                milliseconds: (fraction * player.duration.inMilliseconds).round(),
              );
              player.seek(seekTo);
            },
          ),
        ),
        const SizedBox(height: 8),
        PlaybackControls(
          isPlaying: player.isPlaying,
          playMode: player.playMode,
          onPrevious: player.previous,
          onPlayPause: player.togglePlayPause,
          onNext: player.next,
          onToggleMode: () {
            const modes = PlayMode.values;
            final next = modes[(player.playMode.index + 1) % modes.length];
            player.setPlayMode(next);
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            children: [
              Icon(
                player.volume > 0.5 ? Icons.volume_up : Icons.volume_down,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: Slider(value: player.volume, onChanged: (v) => player.setVolume(v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.queue_music),
              tooltip: '队列',
              onPressed: () => _showQueue(context),
            ),
            IconButton(
              icon: const Icon(Icons.equalizer),
              tooltip: '均衡器',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EqualizerPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.speaker),
              tooltip: '输出设备',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const OutputDeviceSheet(),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              tooltip: '更多设置',
              onPressed: () => _showSettings(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Helpers ──

  /// Sort indices by distance from active: center (0) on top, then ±1, then ±2 at bottom.
  List<int> _sortedIndices(int count, int active) {
    final indices = List.generate(count, (i) => i);
    indices.sort((a, b) => (b - active).abs().compareTo((a - active).abs()));
    return indices;
  }

  // ── Card stack animation ──

  void _animateToPlaylist(int newIndex, int totalCount) {
    final player = context.read<AudioPlayerService>();
    _isAnimating = true;
    final screenWidth = MediaQuery.of(context).size.width;
    final direction = newIndex < player.activePlaylistIndex ? 1.0 : -1.0;
    final targetX = direction * screenWidth * 0.3;

    final animation = Tween<double>(begin: _dragOffset, end: targetX)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _slideController.reset();
    animation.addListener(() {
      setState(() => _dragOffset = animation.value);
    });
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        player.switchToPlaylist(newIndex);
        _dragOffset = 0;
        _isAnimating = false;
        setState(() {});
      }
    });
    _slideController.forward();
  }

  void _snapBack() {
    _isAnimating = true;
    final animation = Tween<double>(begin: _dragOffset, end: 0)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _slideController.reset();
    animation.addListener(() {
      setState(() => _dragOffset = animation.value);
    });
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dragOffset = 0;
        _isAnimating = false;
        setState(() {});
      }
    });
    _slideController.forward();
  }

  // ── Queue bottom sheet (grouped) ──

  void _showQueue(BuildContext context) {
    final player = context.read<AudioPlayerService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) {
          final playlists = player.queuePlaylists;
          if (playlists.isEmpty) {
            return const Center(child: Text('播放队列为空'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '播放队列 (${playlists.length} 个歌单)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: playlists.length,
                  itemBuilder: (context, plIndex) {
                    final qp = playlists[plIndex];
                    final isActive = plIndex == player.activePlaylistIndex;
                    return _QueuePlaylistSection(
                      queuePlaylist: qp,
                      isActive: isActive,
                      onTapTrack: (trackIndex) {
                        if (!isActive) player.switchToPlaylist(plIndex);
                        player.playAtIndex(trackIndex);
                        Navigator.pop(ctx);
                      },
                      onRemovePlaylist: () {
                        player.removePlaylistFromQueue(plIndex);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final player = context.read<AudioPlayerService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _InterruptModeSheet(player: player),
    );
  }
}

// ── Queue playlist section widget ──

class _QueuePlaylistSection extends StatelessWidget {
  final QueuePlaylist queuePlaylist;
  final bool isActive;
  final void Function(int trackIndex) onTapTrack;
  final VoidCallback onRemovePlaylist;

  const _QueuePlaylistSection({
    required this.queuePlaylist,
    required this.isActive,
    required this.onTapTrack,
    required this.onRemovePlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(
              isActive ? Icons.play_circle : Icons.queue_music,
              color: isActive ? theme.colorScheme.primary : null,
            ),
            title: Text(
              queuePlaylist.name,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : null,
                color: isActive ? theme.colorScheme.primary : null,
              ),
            ),
            subtitle: Text('${queuePlaylist.trackCount} 首'),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemovePlaylist,
            ),
          ),
          ...queuePlaylist.tracks.take(5).toList().asMap().entries.map((entry) {
            final ti = entry.key;
            final track = entry.value;
            final isCurrent = ti == queuePlaylist.currentTrackIndex;
            return ListTile(
              dense: true,
              leading: Icon(
                isCurrent ? Icons.play_arrow : Icons.music_note,
                size: 18,
                color: isCurrent ? theme.colorScheme.primary : null,
              ),
              title: Text(track.title, style: theme.textTheme.bodySmall),
              onTap: () => onTapTrack(ti),
            );
          }),
          if (queuePlaylist.trackCount > 5)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 8),
              child: Text(
                '+ ${queuePlaylist.trackCount - 5} 更多...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Interrupt mode sheet ──

class _InterruptModeSheet extends StatefulWidget {
  final AudioPlayerService player;
  const _InterruptModeSheet({required this.player});

  @override
  State<_InterruptModeSheet> createState() => _InterruptModeSheetState();
}

class _InterruptModeSheetState extends State<_InterruptModeSheet> {
  late AudioInterruptMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.player.interruptMode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('音频打断策略', style: theme.textTheme.titleMedium),
            ),
            RadioListTile<AudioInterruptMode>(
              title: const Text('暂停播放'),
              subtitle: const Text('其他应用发声时暂停'),
              value: AudioInterruptMode.pause,
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selected = v);
                  widget.player.setInterruptMode(v);
                }
              },
            ),
            RadioListTile<AudioInterruptMode>(
              title: const Text('不中断但降低音量'),
              subtitle: const Text('降低至 20% 音量继续播放'),
              value: AudioInterruptMode.duck,
              groupValue: _selected,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selected = v);
                  widget.player.setInterruptMode(v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
