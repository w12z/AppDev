import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../providers/music_library_provider.dart';
import '../providers/playlist_provider.dart';
import '../services/audio_player_service.dart';
import '../widgets/track_list_tile.dart';
import 'playlist_detail_page.dart';

class MusicLibraryPage extends StatefulWidget {
  const MusicLibraryPage({super.key});

  @override
  State<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends State<MusicLibraryPage> {
  bool _showAllAudio = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<MusicLibraryProvider>();
      if (library.allTracks.isEmpty && !library.isLoading) {
        library.loadFromCache();
      }
      context.read<PlaylistProvider>().loadPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showAllAudio ? '所有音频' : '音乐'),
        leading: _showAllAudio
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showAllAudio = false),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '扫描文件夹',
            onPressed: () => _pickAndScanFolder(),
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<MusicLibraryProvider>(
            builder: (context, library, _) {
              if (!library.isLoading) return const SizedBox.shrink();
              return const LinearProgressIndicator();
            },
          ),
          Expanded(
            child: _showAllAudio ? _buildAllAudioView() : _buildHomeView(),
          ),
        ],
      ),
    );
  }

  // ── Home view ──

  Widget _buildHomeView() {
    return Consumer2<MusicLibraryProvider, PlaylistProvider>(
      builder: (context, library, playlists, _) {
        if (library.isLoading && library.allTracks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // 「所有音频」card
            _buildAllAudioCard(library.allTracks.length),
            const Divider(indent: 16, endIndent: 16),
            // 「我的歌单」section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '我的歌单',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '创建歌单',
                    onPressed: _showCreatePlaylistDialog,
                  ),
                ],
              ),
            ),
            if (playlists.playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.playlist_play, size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text('暂无歌单', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text('点击右上角 + 创建', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              )
            else
              ...playlists.playlists.map((p) => _buildPlaylistTile(p)),
          ],
        );
      },
    );
  }

  Widget _buildAllAudioCard(int trackCount) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.audiotrack,
              color: Theme.of(context).colorScheme.primary),
        ),
        title: const Text('所有音频', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$trackCount 首'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _showAllAudio = true),
      ),
    );
  }

  Widget _buildPlaylistTile(playlist) {
    final updatedAt = playlist.updatedAt;
    final now = DateTime.now();
    String timeStr;
    if (updatedAt.year == now.year &&
        updatedAt.month == now.month &&
        updatedAt.day == now.day) {
      timeStr = '今天';
    } else if (updatedAt.year == now.year &&
        updatedAt.month == now.month &&
        updatedAt.day == now.day - 1) {
      timeStr = '昨天';
    } else {
      timeStr = '${updatedAt.month}/${updatedAt.day}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.queue_music,
              color: Theme.of(context).colorScheme.secondary),
        ),
        title: Text(playlist.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${playlist.trackCount} 首 · $timeStr'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final idx = context.read<PlaylistProvider>().playlists.indexOf(playlist);
          Navigator.push(context, _playlistDetailRoute(idx));
        },
        onLongPress: () => _showRenamePlaylistDialog(playlist),
      ),
    );
  }

  Route _playlistDetailRoute(int startIndex) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          PlaylistDetailPage(initialIndex: startIndex),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  // ── All audio view (track list) ──

  Widget _buildAllAudioView() {
    return Consumer<MusicLibraryProvider>(
      builder: (context, library, _) {
        if (library.error != null && library.allTracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(library.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _pickAndScanFolder(),
                  child: const Text('选择文件夹'),
                ),
              ],
            ),
          );
        }
        if (library.allTracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_off, size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('未发现音乐文件',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('请点击右上角文件夹图标选择音乐文件夹',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }

        final tracks = library.allTracks;
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final player = context.watch<AudioPlayerService>();
            final isPlaying = player.currentTrack == track && player.isPlaying;

            return TrackListTile(
              track: track,
              isPlaying: isPlaying,
              onTap: () {
                context.read<AudioPlayerService>().playQueue(tracks, startIndex: index);
                context.read<MusicLibraryProvider>().addToRecent(track);
              },
              onMore: () => _showTrackMenu(context, track),
            );
          },
        );
      },
    );
  }


  // ── Dialogs ──

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _MusicSearchDelegate(
        tracks: context.read<MusicLibraryProvider>().allTracks,
        onPlay: (track, all) {
          final tracks = all.cast<MusicTrack>().toList();
          final idx = tracks.indexOf(track as MusicTrack);
          context.read<AudioPlayerService>().playQueue(tracks, startIndex: idx);
        },
      ),
    );
  }

  void _showTrackMenu(BuildContext context, track) {
    final player = context.read<AudioPlayerService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('下一首播放'),
              onTap: () {
                player.insertNext(track);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('添加到队列'),
              onTap: () {
                player.addToQueue(track);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('添加到歌单'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistsDialog(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(track);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '歌单名称',
            hintText: '例如：我的最爱',
          ),
          onSubmitted: (name) async {
            if (name.trim().isEmpty) return;
            await context.read<PlaylistProvider>().createPlaylist(name.trim());
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await context.read<PlaylistProvider>().createPlaylist(name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRenamePlaylistDialog(playlist) {
    final controller = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '新名称'),
          onSubmitted: (name) async {
            if (name.trim().isEmpty) return;
            await context.read<PlaylistProvider>().renamePlaylist(playlist.id, name.trim());
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await context.read<PlaylistProvider>().renamePlaylist(playlist.id, name);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistsDialog(track) {
    final provider = context.read<PlaylistProvider>();
    final playlists = provider.playlists;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无歌单，请先创建'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final selected = <int>[];
    // Pre-check playlists that already contain this track
    for (final p in playlists) {
      if (p.trackPaths.contains(track.path)) {
        selected.add(p.id!);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加到歌单'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final p = playlists[index];
                final isSelected = selected.contains(p.id!);
                return CheckboxListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.trackCount} 首'),
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selected.add(p.id!);
                      } else {
                        selected.remove(p.id!);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      await provider.addToMultiplePlaylists(track.path, selected);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已添加到 ${selected.length} 个歌单'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndScanFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择音乐文件夹',
    );
    if (path == null || !mounted) return;

    final library = context.read<MusicLibraryProvider>();
    await library.scanDirectory(path);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(library.error != null
          ? '扫描失败: ${library.error}'
          : '扫描完成，发现 ${library.allTracks.length} 首音乐'),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showRenameDialog(track) {
    final ext = track.path.split('.').last;
    final controller = TextEditingController(text: '${track.title}.$ext');
    bool isRenaming = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '新文件名',
              helperText: '包含扩展名 (例如 .$ext)',
            ),
            onSubmitted: (_) async {
              if (isRenaming) return;
              setDialogState(() => isRenaming = true);
              final success = await context
                  .read<MusicLibraryProvider>()
                  .renameTrack(track, controller.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop(success);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isRenaming
                  ? null
                  : () async {
                      setDialogState(() => isRenaming = true);
                      final success = await context
                          .read<MusicLibraryProvider>()
                          .renameTrack(track, controller.text.trim());
                      if (ctx.mounted) Navigator.of(ctx).pop(success);
                    },
              child: isRenaming
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> tracks;
  final void Function(dynamic track, List<dynamic> all) onPlay;

  _MusicSearchDelegate({required this.tracks, required this.onPlay});

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final results = tracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          (t.artist?.toLowerCase().contains(q) ?? false) ||
          (t.album?.toLowerCase().contains(q) ?? false);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final track = results[index];
        return TrackListTile(
          track: track,
          onTap: () {
            onPlay(track, results);
            close(context, track.title);
          },
        );
      },
    );
  }
}
