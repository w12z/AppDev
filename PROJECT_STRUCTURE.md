# File Hub 项目文件结构

```
file_hub/
├── pubspec.yaml              # 项目配置：名称、依赖包、SDK版本
├── pubspec.lock              # 依赖精确版本锁定（自动生成）
├── analysis_options.yaml     # Dart 静态分析规则
├── README.md                 # 项目说明
├── PROJECT_STRUCTURE.md      # 本文件
│
├── lib/
│   ├── main.dart             # App 入口：注册模块、启动应用
│   │
│   ├── core/                 # 核心框架（始终存在，不可卸载）
│   │   ├── core.dart         #   核心库导出文件
│   │   ├── feature_interface.dart  #   所有模块的统一接口 AppFeature
│   │   ├── feature_registry.dart   #   模块注册表：注册/启用/禁用/卸载
│   │   └── core_module.dart        #   核心功能：文件分类 + 快速访问
│   │
│   └── features/             # 可插拔功能模块
│       ├── wifi_transfer/    # Wi-Fi 局域网文件传输模块
│       │   ├── wifi_transfer.dart          #   模块库文件
│       │   └── wifi_transfer_feature.dart  #   实现 AppFeature 接口
│       ├── pdf_viewer/       # PDF 预览模块
│       │   ├── pdf_viewer.dart             #   模块库文件
│       │   └── pdf_viewer_feature.dart     #   实现 AppFeature 接口
│       └── music_player/     # 音乐播放模块
│           ├── music_player.dart           #   模块库文件
│           └── music_player_feature.dart   #   实现 AppFeature 接口
│
├── test/
│   └── widget_test.dart      # Widget 冒烟测试
│
├── ios/                      # iOS 原生工程（Mac 上用 Xcode 打开）
├── windows/                  # Windows 桌面原生工程（备用）
├── web/                      # Web 入口（Edge 浏览器验证用）
└── android/                  # Android 原生工程（本项目已禁用）
```

## 架构：模块化即插件

本项目模拟 VS Code 插件系统，所有功能除核心外都是可插拔模块。

### AppFeature 接口（core/feature_interface.dart）

每个模块必须实现：

| 成员 | 类型 | 说明 |
|------|------|------|
| id | String | 唯一标识，如 "wifi_transfer" |
| name | String | 显示名称，如 "Wi-Fi 传输" |
| description | String | 功能描述 |
| iconAsset | String | 图标资源路径 |
| enabledByDefault | bool | 是否默认启用（首次安装） |
| buildPage(context) | Widget | 该模块的主页面 |
| init() | Future<void> | 模块初始化 |
| dispose() | Future<void> | 模块销毁 |

### FeatureRegistry（core/feature_registry.dart）

全局模块注册表，管理生命周期：

- register(feature) → 注册模块到 Registry
- enable(id) → 启用模块（显示在导航栏，调用 init()）
- disable(id) → 禁用模块（隐藏 UI，保留数据，调用 dispose()）
- uninstall(id) → 卸载模块（销毁数据，从注册表移除）
- isEnabled(id) → 查询是否启用
- enabledFeatures → 获取所有已启用的模块列表

### main.dart 流程

1. register(所有模块)
2. 对 enabledFeatures 调用 init()
3. runApp()
4. HomePage 根据 enabledFeatures 动态生成底部导航

### 添加新模块（3 步）

1. 在 `lib/features/` 下新建目录 `new_module/`
2. 创建 `new_module_feature.dart`，实现 `AppFeature` 接口
3. 在 `main.dart` 中 `registry.register(NewModuleFeature())`

### 各模块一览

| 模块 | 默认启用 | 位置 |
|------|:---:|------|
| core_module | 始终 | lib/core/ |
| wifi_transfer | 否 | lib/features/wifi_transfer/ |
| pdf_viewer | 否 | lib/features/pdf_viewer/ |
| music_player | 否 | lib/features/music_player/ |

## 开发与运行

```
# Edge 浏览器验证（Windows 开发首选）
flutter run -d edge

# Windows 桌面应用（需要启用开发者模式）
flutter run -d windows

# 静态分析
flutter analyze
```
