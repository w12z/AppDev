# ZHub

多模块文件管理应用，采用可插拔架构。当前在 Windows 桌面开发，目标平台为 iOS。

## 功能

| 模块 | 类型 | 状态 |
|---|---|---|
| 文件浏览 | 核心（不可卸载） | 已完成 |
| 快速访问 | 核心（不可卸载） | 已完成 |
| Wi-Fi 传输 | 可插拔模块 | 基本实现 |
| PDF 预览 | 可插拔模块 | 待实现 |
| 音乐播放 | 可插拔模块 | 基本实现（默认关闭） |

## 架构

```
MultiProvider
├── FileBrowserProvider       →  文件浏览（目录导航、增删）
├── QuickAccessProvider       →  快速访问（收藏、持久化）
├── AudioPlayerService        →  音乐播放（ChangeNotifier 单例）
├── MusicLibraryProvider      →  音乐库扫描
└── PlaylistProvider          →  歌单管理

HomePage (IndexedStack + NavigationBar)
├── Tab 0: FileBrowserPage   (文件)
├── Tab 1: QuickAccessPage   (快速访问)
└── Tab N: 启用后动态接入的模块页
```

模块系统基于 `AppFeature` 接口 + `FeatureRegistry` 注册表，类似 VS Code 插件模型。

## 核心文件

```
lib/core/
├── feature_interface.dart    AppFeature 抽象接口
├── feature_registry.dart     全局注册表（单例）
├── file_item.dart            文件/目录模型 + 分类 + 图标
└── core_hub.dart             核心页面 + Provider + Service

lib/features/music_player/
├── music_player_feature.dart     模块入口（AppFeature 实现）
├── services/
│   ├── audio_player_service.dart 播放引擎（ChangeNotifier 单例）
│   ├── audio_routing_service.dart输出设备切换
│   ├── audio_session_monitor.dart跨平台音频焦点（MethodChannel）
│   ├── equalizer_service.dart    10段均衡器（全局单例）
│   ├── music_player_settings.dart集中化用户设置
│   ├── music_scanner.dart        音乐文件扫描
│   ├── playlist_repository.dart  SQLite 数据仓库
│   └── settings_repository.dart  KV 设置存储
├── models/
│   ├── eq_preset.dart            均衡器预设模型（9个内置预设）
│   ├── music_track.dart          曲目模型
│   └── playlist.dart             歌单模型
├── providers/
│   ├── music_library_provider.dart
│   └── playlist_provider.dart
├── pages/
│   ├── equalizer_page.dart       均衡器设置页
│   ├── music_library_page.dart   音乐库主页
│   ├── now_playing_page.dart     全屏播放器
│   ├── playlist_detail_page.dart 歌单详情（PageView 滑动切换）
│   └── playlist_list_page.dart   歌单列表
└── widgets/
    ├── mini_player.dart          底部迷你播放器
    ├── playback_controls.dart    播放控制按钮
    ├── progress_bar.dart         进度条
    ├── track_list_tile.dart      曲目列表项
    ├── add_to_playlist_sheet.dart添加到歌单
    ├── output_device_sheet.dart  输出设备选择
    ├── eq_band_slider.dart       EQ 频段滑块
    └── eq_preset_manager.dart    EQ 预设管理
```

## 运行

```bash
# Windows 桌面
flutter run -d windows

# 静态分析
flutter analyze
```

## 添加新模块

1. 在 `lib/features/` 下新建目录
2. 实现 `AppFeature` 接口
3. 在 `main.dart` 中 `registry.register()`

---

## 更新日志

### 2026-05-26 — 音乐播放器模块重构

**代码简化（6项）**

| # | 优化项 | 改动前 | 改动后 | 收益 |
|---|--------|--------|--------|------|
| ① | 合并 Provider → Service | `PlayerStateProvider` + `AudioPlayerService` 双层代理 | `AudioPlayerService` 直接继承 `ChangeNotifier`，作为单例 | **-147 行，-1 文件** |
| ② | 合并三个 Timer | 3 个独立 Timer（250ms / 500ms / 2000ms） | 1 个统一 250ms 轮询，通过 `_tickCount` 分级检查 | **-2 Timer** |
| ③ | 修复 N+1 查询 | `getAll()` 每条 playlist 一次独立 DB 查询 | 单次 `LEFT JOIN` 查询 | **-10 查询**（10歌单场景） |
| ④ | 集中 Settings | 3 个文件各自调用 `SettingsRepository` 读写 | 新增 `MusicPlayerSettings` 统一管理所有用户设置 | 消除分散持久化 |
| ⑤ | 去重 EQ 预设 | 内置预设同时定义在代码常量 + DB 插入 | 仅在 `EqPreset.builtInPresets` 定义，DB 只存用户自定义 | 单一真实来源 |
| ⑥ | 简化 iOS 音频焦点 | `AudioFocusHandler` 73 行（`isInterrupted` 标志 + 中断监听） | 28 行（直接使用 `secondaryAudioShouldBeSilencedHint`） | **-45 行（-62%）** |

**文件变更**

| 操作 | 文件 |
|------|------|
| 🆕 新增 | `lib/features/music_player/services/music_player_settings.dart` |
| ❌ 删除 | `lib/features/music_player/providers/player_state_provider.dart` |
| ✏️ 重写 | `audio_player_service.dart`（合并 PlayerStateProvider + 统一 Timer） |
| ✏️ 重写 | `equalizer_service.dart`（改用 MusicPlayerSettings） |
| ✏️ 重写 | `audio_routing_service.dart`（去掉独立 Timer，改用 MusicPlayerSettings） |
| ✏️ 简化 | `audio_session_monitor.dart`（去掉独立 Timer，仅做 MethodChannel 封装） |
| ✏️ 简化 | `ios/Runner/AudioFocusHandler.swift`（73→28 行） |
| ✏️ 修改 | `playlist_repository.dart`（N+1→JOIN，去重 EQ 预设） |
| ✏️ 修改 | `music_player_feature.dart`（启用 MusicPlayerSettings，默认关闭模块） |
| ✏️ 修改 | `main.dart`（用 `AudioPlayerService.instance` 代替 `PlayerStateProvider`） |
| ✏️ 修改 | `mini_player.dart` / `now_playing_page.dart` / `music_library_page.dart` / `playlist_detail_page.dart`（`PlayerStateProvider` → `AudioPlayerService`） |

**总计：-486 行 / +244 行，净减少 242 行，删除 1 个文件，消除 2 个冗余 Timer。**
