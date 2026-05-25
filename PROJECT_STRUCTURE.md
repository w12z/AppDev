# File Hub 项目文件结构

```
file_hub/
├── pubspec.yaml                  # 项目配置：名称、依赖包、SDK版本
├── pubspec.lock                  # 依赖精确版本锁定
├── analysis_options.yaml         # Dart 静态分析规则
├── README.md
├── PROJECT_STRUCTURE.md
│
├── lib/
│   ├── main.dart                 # App 入口：Provider 注入 → 注册模块 → runApp
│   │
│   ├── core/                     # 核心框架（不可卸载）
│   │   ├── core.dart             #   barrel 导出
│   │   ├── feature_interface.dart  #   AppFeature 抽象接口
│   │   ├── feature_registry.dart   #   全局注册表：注册/启用/禁用/卸载
│   │   ├── file_item.dart          #   文件/目录模型 + 分类 + 图标
│   │   └── core_hub.dart           #   核心逻辑：Provider + UI + Service
│   │
│   └── features/                 # 可插拔功能模块
│       ├── wifi_transfer/
│       │   ├── wifi_transfer.dart          # barrel 导出
│       │   └── wifi_transfer_feature.dart  # AppFeature 实现
│       ├── pdf_viewer/
│       │   ├── pdf_viewer.dart             # barrel 导出
│       │   └── pdf_viewer_feature.dart     # AppFeature 实现
│       └── music_player/
│           ├── music_player.dart           # barrel 导出
│           └── music_player_feature.dart   # AppFeature 实现
│
├── test/
│   └── widget_test.dart
│
├── ios/                          # iOS 原生工程
├── windows/                      # Windows 桌面原生工程
├── web/                          # Web 入口
└── android/                      # Android（未启用）
```

## 架构：可插拔模块系统

所有功能除核心外均为可插拔模块，启用/禁用/卸载由 `FeatureRegistry` 统一管理。

### AppFeature 接口

| 成员 | 类型 | 说明 |
|---|---|---|
| id | String | 唯一标识 |
| name | String | 显示名称 |
| description | String | 功能描述 |
| iconAsset | String | 图标路径 |
| enabledByDefault | bool | 首次安装是否启用 |
| buildPage(context) | Widget | 模块主页 |
| init() | Future<void> | 初始化（应用启动时调用） |
| dispose() | Future<void> | 销毁（卸载时调用） |

### FeatureRegistry

- `register(feature)` → 注册模块
- `enable(id)` → 启用模块（显示在导航栏，调用 init()）
- `disable(id)` → 禁用模块（隐藏 UI，调用 dispose()）
- `uninstall(id)` → 卸载模块（移除注册）
- `enabledFeatures` → 获取已启用模块列表

### 启动流程

1. `WidgetsFlutterBinding.ensureInitialized()`
2. 注册所有模块到 `FeatureRegistry`
3. 对默认启用的模块调用 `init()`
4. `MultiProvider` 注入 `FileBrowserProvider` + `QuickAccessProvider`
5. `runApp()` → `HomePage` 根据已启用模块动态生成导航栏

## 运行

```bash
flutter run -d windows   # Windows 桌面
flutter run -d edge      # Web
flutter analyze          # 静态分析
```
