import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  IconData get icon => Icons.wifi;

  @override
  bool get enabledByDefault => false;

  late WifiTransferProvider _provider;

  @override
  Widget buildPage(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: const WifiTransferPage(),
    );
  }

  @override
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final transferDir = Directory('${dir.path}${Platform.pathSeparator}transfer');
    if (!await transferDir.exists()) {
      await transferDir.create(recursive: true);
    }

    _provider = WifiTransferProvider(
      server: WifiTransferServer(port: 8686, serveDirectory: transferDir.path),
    );
  }

  @override
  Future<void> dispose() async {
    _provider.dispose();
  }
}
