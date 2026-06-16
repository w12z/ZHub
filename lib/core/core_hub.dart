import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'file_item.dart';
import 'feature_registry.dart';
import '../features/pdf_viewer/pdf_viewer_feature.dart';

// ============================================================
// Services
// ============================================================

/// Must be set by main() before FileBrowserProvider is created.
String? _iosDocumentsPath;

void setDocumentsPath(String path) {
  _iosDocumentsPath = path;
}

class FileService {
  Future<List<FileItem>> listDirectory(String path) async {
    if (kIsWeb) return [];
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return [];
      final entities = await dir.list().toList();
      final items = <FileItem>[];
      for (final entity in entities) {
        try {
          items.add(FileItem.fromFileSystem(entity));
        } catch (_) {}
      }
      items.sort(_compare);
      return items;
    } catch (_) {
      return [];
    }
  }

  int _compare(FileItem a, FileItem b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.compareTo(b.name);
  }

  Future<bool> delete(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(path).delete();
      } else {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> renameItem(String path, String newName) async {
    try {
      final parent = Directory(path).parent.path;
      final newPath = '$parent${Platform.pathSeparator}$newName';
      await File(path).rename(newPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openFile(String path) async {
    if (kIsWeb) return false;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  List<DirectoryEntry> getCommonDirectories() {
    if (kIsWeb) return [];
    final home = _homePath;
    final sep = Platform.pathSeparator;
    final entries = <DirectoryEntry>[];
    for (final path in _candidatePaths(home, sep)) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        final name = path.split(sep).last;
        entries.add(DirectoryEntry(
            path: path, name: name.isEmpty ? home : name));
      }
    }
    return entries;
  }

  List<String> _candidatePaths(String home, String sep) => [
        home,
        '$home${sep}Documents',
        '$home${sep}Downloads',
        '$home${sep}Desktop',
        '$home${sep}Pictures',
        '$home${sep}Music',
        '$home${sep}Videos',
      ];

  String get _homePath {
    if (kIsWeb) return '/';
    if (Platform.isIOS && _iosDocumentsPath != null) return _iosDocumentsPath!;
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '/';
    return home;
  }

  String get homePath => _homePath;
}

class DirectoryEntry {
  final String path;
  final String name;
  const DirectoryEntry({required this.path, required this.name});
}

class QuickAccessService extends ChangeNotifier {
  static QuickAccessService? _instance;
  factory QuickAccessService() => _instance ??= QuickAccessService._();
  QuickAccessService._();

  final List<String> _paths = [];

  Future<void> _ensureLoaded() async {
    if (_paths.isNotEmpty) return;
    try {
      final file = await _configFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> json = jsonDecode(content);
        _paths.addAll(json.cast<String>());
      }
    } catch (_) {}
  }

  File? _file;
  Future<File> get _configFile async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}quick_access.json');
    return _file!;
  }

  Future<List<String>> getPaths() async {
    await _ensureLoaded();
    return List.unmodifiable(_paths);
  }

  Future<void> add(String path) async {
    if (kIsWeb) return;
    await _ensureLoaded();
    if (!_paths.contains(path)) {
      _paths.insert(0, path);
      await _save();
      notifyListeners();
    }
  }

  Future<void> remove(String path) async {
    if (kIsWeb) return;
    await _ensureLoaded();
    if (_paths.remove(path)) {
      await _save();
      notifyListeners();
    }
  }

  Future<bool> contains(String path) async {
    if (kIsWeb) return false;
    await _ensureLoaded();
    return _paths.contains(path);
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    final file = await _configFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_paths));
  }
}

// ============================================================
// Providers
// ============================================================

class FileBrowserProvider extends ChangeNotifier {
  final FileService _service = FileService();

  String _currentPath = '';
  List<FileItem> _items = [];
  bool _loading = false;
  String? _error;
  List<DirectoryEntry> _commonDirs = [];

  String get currentPath => _currentPath;
  List<FileItem> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  List<DirectoryEntry> get commonDirs => _commonDirs;
  bool get canGoUp => !kIsWeb && _currentPath != _service.homePath && Directory(_currentPath).parent.path != _currentPath;
  String get currentName => _currentPath.isEmpty
      ? 'ZHub'
      : FileItem.nameFromPath(_currentPath);

  FileBrowserProvider() {
    _commonDirs = _service.getCommonDirectories();
    _currentPath = _service.homePath;
    if (!kIsWeb) refresh();
  }

  Future<void> refresh() async {
    if (_currentPath.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _service.listDirectory(_currentPath);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> navigateTo(String path) async {
    _currentPath = path;
    await refresh();
  }

  Future<void> navigateUp() async {
    if (canGoUp) {
      _currentPath = Directory(_currentPath).parent.path;
      await refresh();
    }
  }

  Future<bool> deleteItem(FileItem item) async {
    final success = await _service.delete(item.path);
    if (success) {
      _items.removeWhere((i) => i.path == item.path);
      notifyListeners();
    }
    return success;
  }

  Future<bool> renameItem(FileItem item, String newName) async {
    final success = await _service.renameItem(item.path, newName);
    if (success) await refresh();
    return success;
  }
}

class QuickAccessProvider extends ChangeNotifier {
  final QuickAccessService _service = QuickAccessService();

  List<String> _paths = [];
  List<FileItem> _items = [];
  bool _loading = true;

  List<FileItem> get items => _items;
  bool get loading => _loading;

  QuickAccessProvider() {
    load();
    _service.addListener(() => load());
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _paths = await _service.getPaths();
    _items = _buildItems(_paths);
    _loading = false;
    notifyListeners();
  }

  List<FileItem> _buildItems(List<String> paths) {
    if (kIsWeb) return [];
    final items = <FileItem>[];
    for (final path in paths) {
      try {
        final type = FileSystemEntity.typeSync(path, followLinks: false);
        if (type != FileSystemEntityType.notFound) {
          items.add(FileItem(
            path: path,
            name: FileItem.nameFromPath(path),
            isDirectory: type == FileSystemEntityType.directory,
            size: 0,
            modified: DateTime.now(),
            category: FileCategory.others,
          ));
        }
      } catch (_) {}
    }
    return items;
  }

  Future<void> pin(String path) async {
    await _service.add(path);
    await load();
  }

  Future<void> unpin(String path) async {
    await _service.remove(path);
    await load();
  }

  bool isPinned(String path) => _paths.contains(path);
}

// ============================================================
// UI Pages
// ============================================================

class FileBrowserPage extends StatefulWidget {
  final String? initialPath;
  const FileBrowserPage({super.key, this.initialPath});

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  FileBrowserProvider? _provider;
  String? _originalPath;

  @override
  void initState() {
    super.initState();
    _provider = context.read<FileBrowserProvider>();
    if (widget.initialPath != null) {
      _originalPath = _provider!.currentPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _provider?.navigateTo(widget.initialPath!);
      });
    }
  }

  @override
  void dispose() {
    if (_originalPath != null) {
      _provider?.navigateTo(_originalPath!);
    }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileBrowserProvider>();
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        title: Text(provider.currentName),
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : provider.canGoUp
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => provider.navigateUp(),
                  )
                : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refresh(),
          ),
        ],
      ),
      body: _buildBody(provider),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickNav(context, provider),
        child: const Icon(Icons.folder_open),
      ),
    );
  }

  Widget _buildBody(FileBrowserProvider provider) {
    if (provider.loading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(provider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (provider.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('此目录为空', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        itemCount: provider.items.length,
        itemBuilder: (context, index) {
          final item = provider.items[index];
          final qa = context.watch<QuickAccessProvider>();
          return _FileListTile(
            item: item,
            isPinned: qa.isPinned(item.path),
            onTap: () {
              if (item.isDirectory) {
                provider.navigateTo(item.path);
              } else {
                _openFile(context, item);
              }
            },
            onLongPress: () => _showContextMenu(context, item),
          );
        },
      ),
    );
  }

  void _openFile(BuildContext context, FileItem item) {
    final ext = item.name.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      PdfViewerFeature.openPdf(context, item.path, item.name);
    } else {
      FileService().openFile(item.path);
    }
  }

  void _showContextMenu(BuildContext context, FileItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final qa = context.read<QuickAccessProvider>();
        final pinned = qa.isPinned(item.path);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(item.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('文件信息'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFileInfo(context, item);
                },
              ),
              ListTile(
                leading: Icon(pinned ? Icons.star : Icons.star_border),
                title: Text(pinned ? '取消收藏' : '添加到快速访问'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (pinned) {
                    context.read<QuickAccessProvider>().unpin(item.path);
                  } else {
                    context.read<QuickAccessProvider>().pin(item.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, item);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showFileInfo(BuildContext context, FileItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('文件信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('名称', item.name),
            _infoRow('类型', item.isDirectory ? '文件夹' : _categoryLabel(item.category)),
            _infoRow('大小', item.isDirectory ? '--' : item.formattedSize),
            _infoRow('修改时间', item.formattedDate),
            _infoRow('路径', item.path, maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  String _categoryLabel(FileCategory cat) {
    switch (cat) {
      case FileCategory.documents: return '文档';
      case FileCategory.images: return '图片';
      case FileCategory.videos: return '视频';
      case FileCategory.audio: return '音频';
      case FileCategory.archives: return '压缩包';
      case FileCategory.code: return '代码';
      case FileCategory.others: return '其他';
    }
  }

  Widget _infoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text('$label：', style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, maxLines: maxLines, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FileItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${item.name}" 吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FileBrowserProvider>().deleteItem(item);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showQuickNav(BuildContext context, FileBrowserProvider provider) {
    final items = provider.commonDirs;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('常用目录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(items[i].name),
                    subtitle: Text(items[i].path,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      Navigator.pop(ctx);
                      provider.navigateTo(items[i].path);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  final FileItem item;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileListTile({
    required this.item,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(item.icon, color: item.iconColor, size: 32),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          if (item.formattedSize.isNotEmpty) ...[
            Text(item.formattedSize,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Text(' · ',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          Text(item.formattedDate,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: isPinned
          ? const Icon(Icons.star, size: 20, color: Colors.amber)
          : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class QuickAccessPage extends StatelessWidget {
  const QuickAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuickAccessProvider>();

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('暂无收藏',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('长按文件可将它添加到快速访问',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.builder(
        itemCount: provider.items.length,
        itemBuilder: (context, index) {
          final item = provider.items[index];
          return Dismissible(
            key: Key(item.path),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.star_border, color: Colors.white),
            ),
            onDismissed: (_) => provider.unpin(item.path),
            child: ListTile(
              leading: Icon(item.icon, color: item.iconColor, size: 32),
              title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(item.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => provider.unpin(item.path),
              ),
              onTap: () {
                if (item.isDirectory) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FileBrowserPage(initialPath: item.path),
                    ),
                  );
                } else {
                  final ext = item.name.split('.').last.toLowerCase();
                  if (ext == 'pdf') {
                    PdfViewerFeature.openPdf(context, item.path, item.name);
                  } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                    FileService().openFile(item.path);
                  } else {
                    _showItemInfo(context, item);
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }

  void _showItemInfo(BuildContext context, FileItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('类型', item.isDirectory ? '文件夹' : '文件'),
            _infoRow('路径', item.path, maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<QuickAccessProvider>().unpin(item.path);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('取消收藏'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text('$label：', style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, maxLines: maxLines, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 模块管理页面
// ============================================================

class ModuleManagerPage extends StatelessWidget {
  const ModuleManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<FeatureRegistry>();
    final features = registry.allFeatures;

    return Scaffold(
      appBar: AppBar(title: const Text('模块管理')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final f = features[index];
          final enabled = registry.isEnabled(f.id);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    enabled ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200,
                child: Icon(
                  enabled ? Icons.extension : Icons.extension_off,
                  size: 20,
                  color: enabled
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Colors.grey,
                ),
              ),
              title: Text(f.name),
              subtitle: Text(f.description, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Switch(
                value: enabled,
                onChanged: (v) async {
                  if (v) {
                    await registry.enable(f.id);
                  } else {
                    await registry.disable(f.id);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Core Module
// ============================================================

class CoreModule {
  static const String version = '1.0.0';
}
