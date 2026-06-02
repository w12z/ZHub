import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
import 'package:shelf/shelf.dart' as shelf;
// ignore: unused_import — 实现路由时使用
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

import '../../core/feature_registry.dart';
import '../music_player/providers/music_library_provider.dart';

export 'wifi_transfer_feature.dart';

// ============================================================
// 模型
// ============================================================

enum TransferDirection { upload, download }

enum TransferStatus { pending, transferring, completed, failed }

class TransferTask {
  final String id;
  final String fileName;
  int fileSize;
  final TransferDirection direction;
  TransferStatus status;
  double progress;
  int bytesTransferred;
  int speed;
  String? error;
  String? savedPath;
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
    this.savedPath,
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
/// 1. 本机 IP 检测 — 遍历 NetworkInterface
/// 2. HTML 上传页面 — 返回带拖拽区域的表单
/// 3. 文件接收 — 解析 multipart，保存到 serveDirectory
class WifiTransferServer {
  HttpServer? _httpServer;
  final int port;
  final String serveDirectory;

  final StreamController<TransferTask> _taskController =
      StreamController<TransferTask>.broadcast();

  Stream<TransferTask> get taskStream => _taskController.stream;

  WifiTransferServer({this.port = 8686, required this.serveDirectory});

  bool get isRunning => _httpServer != null;

  Future<String> get localIP async {
    final interfaces = await NetworkInterface.list();
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.isLoopback && !addr.isLinkLocal) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  Future<String> get serverUrl async {
    final ip = await localIP;
    return 'http://$ip:$port';
  }

  Future<void> start() async {
    if (isRunning) return;
    final router = shelf_router.Router();
    router.get('/', _handleIndex);
    router.post('/upload', _handleUpload);
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router.call);
    _httpServer = await io.serve(handler, InternetAddress.anyIPv4, port);
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  /// 接收上传文件（POST /upload，multipart/form-data）
  // ignore: unused_element
  Future<shelf.Response> _handleUpload(shelf.Request request) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null) {
        return shelf.Response(400, body: 'Missing Content-Type');
      }

      final boundary = HeaderValue.parse(contentType).parameters['boundary'];
      if (boundary == null) {
        return shelf.Response(400, body: 'Missing boundary');
      }

      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer.bind(request.read()).toList();

      String? savedName;
      int totalBytes = 0;

      for (final part in parts) {
        final disp = part.headers['content-disposition'];
        if (disp == null) continue;

        final fileKey = _extractField(disp, 'filename');
        if (fileKey == null || fileKey.isEmpty) continue;

        final safeName = DateTime.now().millisecondsSinceEpoch.toString();
        final ext = fileKey.contains('.') ? fileKey.substring(fileKey.lastIndexOf('.')) : '';
        savedName = '$safeName$ext';

        final file = File('$serveDirectory${Platform.pathSeparator}$savedName');
        final sink = file.openWrite();

        final task = TransferTask(
          id: safeName,
          fileName: fileKey,
          fileSize: 0,
          direction: TransferDirection.upload,
          savedPath: file.path,
        );
        _taskController.add(task);

        await for (final chunk in part) {
          sink.add(chunk);
          totalBytes += chunk.length;
          task.bytesTransferred = totalBytes;
          task.fileSize = totalBytes > task.fileSize ? totalBytes : task.fileSize;
          _taskController.add(task);
        }

        await sink.close();

        task.status = TransferStatus.completed;
        task.progress = 1.0;
        _taskController.add(task);
        break; // 只处理第一个文件
      }

      if (savedName == null) {
        return shelf.Response(400, body: 'No file uploaded');
      }

      return shelf.Response.ok(
        jsonEncode({'ok': true, 'name': savedName}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response(500, body: jsonEncode({'ok': false, 'error': e.toString()}));
    }
  }

  String? _extractField(String header, String key) {
    final regex = '$key="';
    final start = header.indexOf(regex);
    if (start == -1) return null;
    final begin = start + regex.length;
    final end = header.indexOf('"', begin);
    if (end == -1) return null;
    return header.substring(begin, end);
  }

  /// HTML 上传页面（GET /）
  // ignore: unused_element
  Future<shelf.Response> _handleIndex(shelf.Request request) async {
    const html = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>ZHub 文件传输</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background: #0f172a;
  color: #e2e8f0;
  min-height: 100vh;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  padding: 24px;
}
h1 { font-size: 28px; font-weight: 700; margin-bottom: 4px; }
.sub { font-size: 14px; color: #94a3b8; margin-bottom: 32px; }
.drop-zone {
  width: 100%; max-width: 420px;
  border: 2px dashed #475569;
  border-radius: 16px;
  padding: 48px 24px;
  text-align: center;
  transition: border-color .2s, background .2s;
  cursor: pointer;
}
.drop-zone.drag-over { border-color: #3b82f6; background: rgba(59,130,246,.08); }
.drop-zone .icon { font-size: 48px; margin-bottom: 16px; }
.drop-zone .label { font-size: 18px; font-weight: 600; margin-bottom: 8px; }
.drop-zone .hint { font-size: 13px; color: #64748b; }
input[type="file"] { display: none; }
.status {
  width: 100%; max-width: 420px; margin-top: 24px;
  background: #1e293b; border-radius: 12px; padding: 16px;
  display: none; align-items: center; gap: 12px;
}
.status.show { display: flex; }
.status .file-name { flex: 1; font-size: 14px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.status .file-size { font-size: 12px; color: #64748b; }
.progress-bar {
  width: 100%; max-width: 420px; height: 4px;
  background: #334155; border-radius: 2px; margin-top: 8px;
  overflow: hidden; display: none;
}
.progress-bar.show { display: block; }
.progress-bar .fill {
  height: 100%; width: 0;
  background: linear-gradient(90deg, #3b82f6, #8b5cf6);
  border-radius: 2px; transition: width .2s;
}
.result {
  margin-top: 12px; font-size: 14px; text-align: center; display: none;
}
.result.success { display: block; color: #22c55e; }
.result.error { display: block; color: #ef4444; }
</style>
</head>
<body>
<h1>ZHub</h1>
<p class="sub">Wi-Fi 文件传输</p>

<div class="drop-zone" id="dropZone">
  <div class="icon">&#128229;</div>
  <div class="label">点击或拖拽文件到此处</div>
  <div class="hint">支持任意文件类型</div>
</div>
<input type="file" id="fileInput" multiple>

<div class="status" id="status">
  <span class="file-name" id="fileName"></span>
  <span class="file-size" id="fileSize"></span>
</div>
<div class="progress-bar" id="progressBar">
  <div class="fill" id="progressFill"></div>
</div>
<div class="result" id="result"></div>

<script>
const dz = document.getElementById('dropZone');
const input = document.getElementById('fileInput');
const status = document.getElementById('status');
const progressBar = document.getElementById('progressBar');
const progressFill = document.getElementById('progressFill');

dz.addEventListener('click', () => input.click());

dz.addEventListener('dragover', e => { e.preventDefault(); dz.classList.add('drag-over'); });
dz.addEventListener('dragleave', () => dz.classList.remove('drag-over'));
dz.addEventListener('drop', e => {
  e.preventDefault();
  dz.classList.remove('drag-over');
  handleFiles(e.dataTransfer.files);
});

input.addEventListener('change', () => handleFiles(input.files));

function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / 1048576).toFixed(1) + ' MB';
}

async function handleFiles(files) {
  for (const file of files) {
    document.getElementById('result').className = '';
    status.classList.add('show');
    document.getElementById('fileName').textContent = file.name;
    document.getElementById('fileSize').textContent = formatSize(file.size);

    const form = new FormData();
    form.append('file', file);

    try {
      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload');

      await new Promise((resolve, reject) => {
        xhr.upload.onprogress = e => {
          if (e.lengthComputable) {
            const pct = (e.loaded / e.total) * 100;
            progressBar.classList.add('show');
            progressFill.style.width = pct + '%';
          }
        };
        xhr.onload = () => {
          if (xhr.status === 200) {
            status.classList.remove('show');
            progressBar.classList.remove('show');
            document.getElementById('result').className = 'success';
            document.getElementById('result').textContent = '✓ ' + file.name + ' 上传成功';
            resolve();
          } else {
            reject(new Error(xhr.responseText));
          }
        };
        xhr.onerror = () => reject(new Error('网络错误'));
        xhr.send(form);
      });
    } catch (err) {
      status.classList.remove('show');
      progressBar.classList.remove('show');
      document.getElementById('result').className = 'error';
      document.getElementById('result').textContent = '✗ 上传失败: ' + err.message;
    }
  }
}
</script>
</body>
</html>
''';
    return shelf.Response.ok(html, headers: {'Content-Type': 'text/html; charset=utf-8'});
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

  bool sendToMusicFolder = false;
  String? _musicFolderPath;
  static const _audioExtensions = [
    'mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma', 'opus', 'aiff'
  ];

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
    if (task.status == TransferStatus.completed) {
      _tryCopyToMusicFolder(task);
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

  void setSendToMusicFolder(bool value, String? musicFolderPath) {
    sendToMusicFolder = value;
    _musicFolderPath = musicFolderPath;
    notifyListeners();
  }

  bool _isAudioFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return _audioExtensions.contains(ext);
  }

  void _tryCopyToMusicFolder(TransferTask task) {
    if (!sendToMusicFolder || _musicFolderPath == null || task.savedPath == null) return;
    if (!_isAudioFile(task.fileName)) return;
    try {
      final sourceFile = File(task.savedPath!);
      final destDir = Directory(_musicFolderPath!);
      if (!destDir.existsSync()) destDir.createSync(recursive: true);
      sourceFile.copySync('${destDir.path}${Platform.pathSeparator}${task.fileName}');
    } catch (e) {
      // silently ignore copy failures
    }
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
    final musicEnabled = context.watch<FeatureRegistry>().isEnabled('music_player');

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
            if (musicEnabled) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: provider.sendToMusicFolder,
                      onChanged: running
                          ? (v) {
                              final musicPath = context.read<MusicLibraryProvider>().musicFolderPath;
                              provider.setSendToMusicFolder(v ?? false, musicPath);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: running
                          ? () {
                              final v = !provider.sendToMusicFolder;
                              final musicPath = context.read<MusicLibraryProvider>().musicFolderPath;
                              provider.setSendToMusicFolder(v, musicPath);
                            }
                          : null,
                      child: Text(
                        '直接传输音频到音乐文件夹',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
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
