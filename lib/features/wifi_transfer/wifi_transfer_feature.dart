import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/feature_interface.dart';
import 'wifi_transfer.dart';

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

  late final WifiTransferProvider _provider;

  WifiTransferFeature() {
    _provider = WifiTransferProvider(
      server: WifiTransferServer(port: 8080, serveDirectory: ''),
    );
  }

  @override
  Widget buildPage(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: const WifiTransferPage(),
    );
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {
    _provider.dispose();
  }
}
