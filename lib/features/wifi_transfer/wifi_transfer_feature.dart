import 'package:flutter/material.dart';
import '../../core/feature_interface.dart';

/// Wi-Fi 局域网文件传输模块
class WifiTransferFeature extends AppFeature {
  @override
  String get id => 'wifi_transfer';

  @override
  String get name => 'Wi-Fi 传输';

  @override
  String get description => '通过局域网 HTTP 服务传输文件';

  @override
  String get iconAsset => 'assets/icons/wifi.svg';

  @override
  bool get enabledByDefault => false;

  @override
  Widget buildPage(BuildContext context) {
    return const Center(child: Text('Wi-Fi 传输 - 待实现'));
  }

  @override
  Future<void> init() async {
    // TODO: 启动 HTTP 服务器
  }

  @override
  Future<void> dispose() async {
    // TODO: 停止 HTTP 服务器
  }
}
