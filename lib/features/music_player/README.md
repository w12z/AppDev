# 音乐播放器模块

基于 flutter_soloud 音频引擎 (MiniAudio 后端)，支持全盘音乐扫描、SQLite 缓存、多歌单队列、10 段均衡器、输出设备切换。

## 目录结构

```
music_player/
├── models/
│   ├── music_track.dart          # 曲目模型 (含 toJson/fromJson)
│   ├── playlist.dart             # 歌单模型 + QueuePlaylist
│   ├── eq_preset.dart            # 均衡器预设 (9 个内置 + 自定义)
│   └── scan_progress.dart        # 内部类，在 music_scanner.dart 中
├── services/
│   ├── audio_player_service.dart # 播放引擎 (ChangeNotifier 单例)
│   ├── music_scanner.dart        # 全盘扫描 (Isolate + 增量)
│   ├── playlist_repository.dart  # SQLite CRUD + scan_cache
│   ├── settings_repository.dart  # 键值存储
│   ├── music_player_settings.dart# 集中设置 (EQ/打断/输出设备)
│   ├── equalizer_service.dart    # 10 段参数均衡器
│   ├── audio_routing_service.dart# 输出设备管理
│   └── audio_session_monitor.dart# 音频焦点检测 (MethodChannel)
├── providers/
│   ├── music_library_provider.dart # 曲目库 + 扫描编排 + 重命名联动
│   └── playlist_provider.dart      # 歌单 CRUD + EQ 预设
├── pages/
│   ├── music_library_page.dart     # 主页：「所有音频」+「我的歌单」
│   ├── now_playing_page.dart       # 全屏播放器 + 卡片堆队列
│   ├── playlist_detail_page.dart   # 歌单详情 (PageView 滑动)
│   └── equalizer_page.dart         # 均衡器 (10 段滑块 + 曲线)
├── widgets/
│   ├── mini_player.dart            # 底部迷你播放器
│   ├── track_list_tile.dart        # 曲目列表项
│   ├── playback_controls.dart      # 播放/暂停/上下首/模式
│   ├── progress_bar.dart           # 进度条 (可拖拽)
│   ├── add_to_playlist_sheet.dart  # 添加曲目到歌单
│   ├── output_device_sheet.dart    # 输出设备选择
│   ├── eq_band_slider.dart         # 均衡器频段滑块
│   └── eq_preset_manager.dart      # 预设管理
└── music_player_feature.dart       # AppFeature 入口
```

## 核心功能

| 功能 | 说明 |
|---|---|
| 全盘扫描 | Windows 盘符枚举 (A:\~Z:\) + 系统目录黑名单 + 后台 Isolate |
| 缓存增量 | SQLite scan_cache 表，重启即加载，增量扫描跳过已缓存文件 |
| 卡片队列 | 多歌单叠放卡片，拖拽切换，切歌保存/恢复位置 |
| 歌单管理 | 创建/重命名/删除，PageView 滑动，拖拽排序，两方向添加 |
| 均衡器 | 10 段 ±12dB Flat/Rock/Pop/Jazz 等 9 个预设 + 自定义存取 |
| 输出设备 | 切换扬声器/耳机，偏好持久化到 SQLite |
| 音频打断 | 暂停 / 降低至 20% 音量 (300ms 渐变) |
| 播放模式 | 顺序 / 随机 / 单曲循环 / 歌单循环 / 全部循环 |
| 曲目重命名 | 联动磁盘 → 缓存 → 歌单引用 → 队列引用 |

## 数据流

```
扫描: DriveEnumerator → Isolate 遍历 → MusicScanner
      → PlaylistRepository.scan_cache → MusicLibraryProvider → UI

播放: 点击曲目 → AudioPlayerService.playQueue()
      → SoLoud.loadFile() → SoLoud.play() → 250ms 轮询进度

歌单: PlaylistProvider → PlaylistRepository (playlists 表)
      → AudioPlayerService.addPlaylistToQueue() → QueuePlaylist

均衡器: EqualizerService → SoLoud.filters.parametricEqFilter
        → MusicPlayerSettings → SQLite settings 表
```

## 关键依赖

| 包 | 用途 |
|---|---|
| flutter_soloud | 音频解码/播放/EQ/设备切换 |
| sqflite + sqflite_common_ffi | 本地 SQLite |
| provider | 状态管理 (ChangeNotifier) |
| path_provider | 数据库文件路径 |

## 平台原生代码

| 平台 | 文件 | 用途 |
|---|---|---|
| Windows | `windows/runner/audio_session_monitor.cpp` | COM API 检测其他应用音频 |
| iOS | `ios/Runner/AudioFocusHandler.swift` | AVAudioSession 中断通知 |
