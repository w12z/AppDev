import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shelf/shelf.dart' as shelf;
// ignore: unused_import — 实现路由时使用
import 'package:shelf/shelf_io.dart' as io;
// ignore: unused_import — 实现路由时使用
import 'package:shelf_router/shelf_router.dart';
// ignore: unused_import — 实现静态文件时使用
import 'package:shelf_static/shelf_static.dart';

export 'wifi_transfer_feature.dart';

// ============================================================
// 模型
// ============================================================

enum TransferDirection { upload, download }

enum TransferStatus { pending, transferring, completed, failed }

class TransferTask {
  final String id;
  final String fileName;
  final int fileSize;
  final TransferDirection direction;
  TransferStatus status;
  double progress;
  int bytesTransferred;
  int speed;
  String? error;
  final DateTime createdAt;

  TransferTask({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    this.status = TransferStatus.pending,
    this.progress = 0.0,
    this.bytesTransferred = 0,
    this.speed = 0,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedSpeed {
    if (speed < 1024) return '$speed B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedProgress => '${(progress * 100).toStringAsFixed(0)}%';

  String get formattedETA {
    if (speed <= 0 || status != TransferStatus.transferring) return '--';
    final remaining = fileSize - bytesTransferred;
    final seconds = remaining ~/ speed;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}min';
    return '${seconds ~/ 3600}h';
  }
}

// ============================================================
// 服务端骨架
// ============================================================

/// HTTP 服务端，负责启动/停止 shelf 服务、管理传输任务。
///
/// 你需要实现的部分（见各方法内 TODO）：
/// 1. 路由注册 — GET /, POST /upload, GET /files/:name
/// 2. 本机 IP 检测 — 遍历 NetworkInterface
/// 3. 文件接收 — 从 multipart 请求中保存文件
/// 4. 进度回调 — 通知 WifiTransferProvider 更新 UI
class WifiTransferServer {
  HttpServer? _httpServer;
  final int port;
  final String serveDirectory;

  final StreamController<TransferTask> _taskController =
      StreamController<TransferTask>.broadcast();

  Stream<TransferTask> get taskStream => _taskController.stream;

  WifiTransferServer({this.port = 8080, required this.serveDirectory});

  bool get isRunning => _httpServer != null;

  Future<String> get localIP async {
    throw UnimplementedError('localIP not implemented');
  }

  Future<String> get serverUrl async {
    final ip = await localIP;
    return 'http://$ip:$port';
  }

  Future<void> start() async {
    if (isRunning) return;
    throw UnimplementedError('start() not implemented');
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  // ignore: unused_element
  Future<shelf.Response> _handleUpload(shelf.Request request) async {
    throw UnimplementedError('_handleUpload not implemented');
  }

  // ignore: unused_element
  Future<shelf.Response> _handleDownload(shelf.Request request, String name) async {
    throw UnimplementedError('_handleDownload not implemented');
  }

  // ignore: unused_element
  Future<shelf.Response> _handleIndex(shelf.Request request) async {
    throw UnimplementedError('_handleIndex not implemented');
  }

  void addTask(TransferTask task) => _taskController.add(task);
}

// ============================================================
// 状态管理
// ============================================================

class WifiTransferProvider extends ChangeNotifier {
  final WifiTransferServer _server;

  String _serverUrl = '';
  bool _isStarting = false;
  bool _isStopping = false;
  String? _error;
  final List<TransferTask> _transfers = [];

  WifiTransferProvider({required WifiTransferServer server})
      : _server = server {
    _server.taskStream.listen(_onTaskUpdate);
  }

  bool get isRunning => _server.isRunning;
  bool get isStarting => _isStarting;
  bool get isStopping => _isStopping;
  String get serverUrl => _serverUrl;
  String? get error => _error;
  List<TransferTask> get transfers => List.unmodifiable(_transfers);
  int get activeCount =>
      _transfers.where((t) => t.status == TransferStatus.transferring).length;

  Future<void> startServer() async {
    if (isRunning || _isStarting) return;
    _isStarting = true;
    _error = null;
    notifyListeners();
    try {
      await _server.start();
      _serverUrl = await _server.serverUrl;
    } catch (e) {
      _error = e.toString();
    }
    _isStarting = false;
    notifyListeners();
  }

  Future<void> stopServer() async {
    if (!isRunning || _isStopping) return;
    _isStopping = true;
    notifyListeners();
    try {
      await _server.stop();
      _serverUrl = '';
      _transfers.clear();
    } catch (e) {
      _error = e.toString();
    }
    _isStopping = false;
    notifyListeners();
  }

  void _onTaskUpdate(TransferTask task) {
    final index = _transfers.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _transfers[index] = task;
    } else {
      _transfers.insert(0, task);
    }
    notifyListeners();
  }

  void addTask(TransferTask task) {
    _transfers.insert(0, task);
    notifyListeners();
  }

  void cancelTransfer(String taskId) {
    _transfers.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  void clearCompleted() {
    _transfers.removeWhere(
      (t) =>
          t.status == TransferStatus.completed ||
          t.status == TransferStatus.failed,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}

// ============================================================
// UI
// ============================================================

class WifiTransferPage extends StatelessWidget {
  const WifiTransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WifiTransferProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Wi-Fi 传输'),
            actions: [
              if (provider.isRunning)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: '清除已完成',
                  onPressed: () => provider.clearCompleted(),
                ),
            ],
          ),
          body: Column(
            children: [
              _ServerCard(provider: provider),
              const Divider(height: 1),
              Expanded(
                child: provider.transfers.isEmpty
                    ? _EmptyTransferList(isRunning: provider.isRunning)
                    : _TransferList(transfers: provider.transfers),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServerCard extends StatelessWidget {
  final WifiTransferProvider provider;
  const _ServerCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = provider.isRunning;
    final loading = provider.isStarting || provider.isStopping;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: running ? Colors.green : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 8),
                Text(running ? '服务运行中' : '服务已停止',
                    style: theme.textTheme.titleMedium),
                if (provider.activeCount > 0) ...[
                  const SizedBox(width: 8),
                  Text('${provider.activeCount} 个传输中',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (running && provider.serverUrl.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(provider.serverUrl,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: '复制链接',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: provider.serverUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('链接已复制'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('在其他设备的浏览器中打开此链接即可传输文件',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 16),
            ],
            if (provider.error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 20, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(provider.error!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: loading
                    ? null
                    : () => running
                        ? provider.stopServer()
                        : provider.startServer(),
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(running ? Icons.stop : Icons.play_arrow),
                label: Text(loading
                    ? (provider.isStarting ? '启动中...' : '停止中...')
                    : (running ? '停止服务' : '启动服务')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferList extends StatelessWidget {
  final List<TransferTask> transfers;
  const _TransferList({required this.transfers});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transfers.length,
      itemBuilder: (_, i) => _TransferTile(task: transfers[i]),
    );
  }
}

class _TransferTile extends StatelessWidget {
  final TransferTask task;
  const _TransferTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = task.status == TransferStatus.transferring;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.direction == TransferDirection.upload
                      ? Icons.upload_file
                      : Icons.download,
                  size: 20,
                  color: task.direction == TransferDirection.upload
                      ? Colors.blue
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
                _statusIcon(task),
              ],
            ),
            const SizedBox(height: 8),
            if (isActive || task.status == TransferStatus.completed) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Text(task.formattedSize,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                if (isActive) ...[
                  const Text(' · ', style: TextStyle(color: Colors.grey)),
                  Text('${task.formattedSpeed}  ·  剩余 ${task.formattedETA}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
                const Spacer(),
                if (task.status == TransferStatus.failed && task.error != null)
                  Expanded(
                    child: Text(task.error!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
                  ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Text(task.formattedProgress,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(TransferTask task) {
    switch (task.status) {
      case TransferStatus.transferring:
        return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2));
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, size: 20, color: Colors.green);
      case TransferStatus.failed:
        return const Icon(Icons.error, size: 20, color: Colors.red);
      case TransferStatus.pending:
        return const Icon(Icons.schedule, size: 20, color: Colors.grey);
    }
  }
}

class _EmptyTransferList extends StatelessWidget {
  final bool isRunning;
  const _EmptyTransferList({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isRunning ? Icons.cloud_upload_outlined : Icons.wifi_off,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isRunning ? '等待传输' : '服务未启动',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              isRunning
                  ? '在其他设备浏览器中打开上方链接，即可上传或下载文件'
                  : '启动服务后，同一局域网内的设备可通过浏览器传输文件',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
