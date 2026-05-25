import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/feature_interface.dart';
import 'pages/music_library_page.dart';
import 'widgets/mini_player.dart';

class MusicPlayerFeature extends AppFeature {
  @override
  String get id => 'music_player';

  @override
  String get name => '音乐';

  @override
  String get description => '管理播放列表和播放音乐文件';

  @override
  String get iconAsset => 'assets/icons/music.svg';

  @override
  bool get enabledByDefault => true;

  @override
  Widget buildPage(BuildContext context) {
    return Stack(
      children: [
        const MusicLibraryPage(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: const MiniPlayer(),
        ),
      ],
    );
  }

  @override
  Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  @override
  Future<void> dispose() async {
    // Resources are disposed by Providers
  }
}
