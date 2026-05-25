# Wi-Fi 传输模块设计文档

## 概述

局域网文件传输模块，在一台设备上启动 HTTP 服务器，同网络下其他设备通过浏览器访问即可上传 / 下载文件。类似 Readdle Documents 的 Wi-Fi 传输。

## 架构

```
WifiTransferFeature (AppFeature)
  ├── WifiTransferProvider  (ChangeNotifier — 状态管理)
  │     ├── 服务器启停
  │     ├── 传输任务队列
  │     └── 错误状态
  ├── WifiTransferServer    (shelf HTTP 服务 — 网络层)
  │     ├── 路由: GET /  POST /upload  GET /files/<name>
  │     ├── 本机 IP 检测
  │     └── 进度回调 (Stream<TransferTask>)
  └── WifiTransferPage      (UI)
        ├── _ServerCard     — 状态 + URL + 启停按钮
        ├── _TransferList   — 传输任务列表
        └── _EmptyTransferList — 空状态
```

## 文件结构

```
lib/features/wifi_transfer/
├── wifi_transfer.dart              barrel 导出
├── wifi_transfer_feature.dart      AppFeature 实现
├── wifi_transfer_models.dart       TransferTask 等数据模型
├── wifi_transfer_server.dart       shelf HTTP 服务端（骨架，需实现）
├── wifi_transfer_provider.dart     状态管理
└── wifi_transfer_page.dart         UI 页面
```

## UI 设计

### 服务器控制卡片

- 绿色/灰色圆点 + "服务运行中" / "已停止"
- 运行时显示完整 URL，支持一键复制
- 启动/停止按钮（带 loading 状态）

### 传输任务列表

每条传输记录显示：
- 上传/下载图标 + 方向颜色
- 文件名、总大小
- 实时进度条 + 百分比
- 传输速度 + 预计剩余时间
- 状态标记（传输中动画、已完成对勾、失败叉号）

### 空状态

根据服务器状态显示不同文案：
- 未启动："启动服务后，同一局域网内的设备可通过浏览器传输文件"
- 运行中无传输："在其他设备浏览器中打开上方链接，即可上传或下载文件"

## HTTP API 设计

```
GET  /                  →  HTML 上传页面（浏览器端）
POST /upload             →  接收文件（multipart/form-data，字段名 "file"）
GET  /files/<filename>   →  下载指定文件（支持 Range 断点续传）
```

## 待实现列表（你的工作）

### 高优先级

| # | 任务 | 文件 | 难度 |
|---|------|------|------|
| 1 | **本机 IP 检测** — 遍历 NetworkInterface 获取局域网 IPv4 | `wifi_transfer_server.dart` → `localIP` | ⭐ |
| 2 | **路由注册 + 服务器启动** — 注册 GET/POST 路由，`io.serve()` | `wifi_transfer_server.dart` → `start()` | ⭐⭐ |
| 3 | **文件接收逻辑** — 解析 multipart，流式写入磁盘，回调进度 | `wifi_transfer_server.dart` → `_handleUpload()` | ⭐⭐⭐ |
| 4 | **HTML 上传页面** — 带样式表单，支持多文件拖拽 | `wifi_transfer_server.dart` → `_handleIndex()` | ⭐⭐ |
| 5 | **serveDirectory 传入** — 将核心模块的文件目录传给 Server | `wifi_transfer_feature.dart` 构造函数 | ⭐ |

### 中优先级

| # | 任务 | 文件 |
|---|------|------|
| 6 | **文件下载** — 流式返回，支持 Range 断点续传 | `_handleDownload()` |
| 7 | **进度回调完善** — 上传/下载过程中持续更新 TransferTask | `_handleUpload()` / `_handleDownload()` |
| 8 | **多文件同时传输** — 支持并发上传/下载 | Server + Provider |

### 低优先级

| # | 任务 | 备注 |
|---|------|------|
| 9 | **二维码生成** — 在 UI 中显示连接二维码 | 需 `qr_flutter` 包 |
| 10 | **mDNS/Bonjour 发现** | iOS 需付费开发者账号 |
| 11 | **HTTPS 支持** | 自签证书 + 用户手动信任 |

## iOS 注意事项

| 问题 | 影响 | 缓解 |
|------|------|------|
| 后台运行 | App 切入后台后 HTTP 服务器被挂起 | 提示用户保持 App 前台 |
| WiFi 名称获取 | `network_info_plus` 的 `getWifiName()` 需付费 Apple 账号 | 不依赖 WiFi 名称，只显示 IP |
| 本地网络权限 | iOS 14+ 首次访问局域网会弹窗 | `Info.plist` 添加 `NSLocalNetworkUsageDescription` |
| `dart:io` 可用 | shelf 基于 `dart:io HttpServer`，iOS 上可用 | 无需额外处理 |

## 快速开始（Windows 开发）

```powershell
# 编译运行
flutter run -d windows

# 启用 WiFi 传输模块
# 在 main.dart 中将 WifiTransferFeature 的 enabledByDefault 改为 true
# 或通过模块管理页面手动启用
```

## 依赖（已就绪）

```yaml
shelf: ^1.4.2          # HTTP server 框架
shelf_router: ^1.1.4    # 路由
shelf_static: ^1.1.3    # 静态文件服务
network_info_plus: ^6.1.2  # 网络信息
```

## 参考

- [shelf 官方文档](https://pub.dev/packages/shelf)
- [Readdle Documents Wi-Fi 传输介绍](https://readdle.com/documents)
- [LocalSend](https://github.com/localsend/localsend) — 开源局域网传输参考实现
