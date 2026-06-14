/// 跨模块服务接口与轻量服务定位器。
///
/// 模块之间不应直接 import 彼此，而是通过这里定义的抽象接口
/// 由 [ModuleServices] 注册/查询，从而保持模块的可插拔性。
library;

/// 提供"目标文件夹路径"的抽象。例如音乐模块可以将其音乐文件夹
/// 暴露给 Wi-Fi 传输模块作为复制目标。
abstract class TargetFolderProvider {
  /// 模块标识，例如 "music"。
  String get id;

  /// 用户可见名称，例如 "音乐文件夹"。
  String get displayName;

  /// 当前路径，未配置时返回 null。
  String? get path;

  /// 该 provider 关注的文件扩展名（小写、不带点）。空集合表示接收任意类型。
  Set<String> get acceptedExtensions;
}

/// 模块间服务定位器。所有跨模块依赖通过这里注册和获取。
class ModuleServices {
  static final ModuleServices instance = ModuleServices._();
  ModuleServices._();

  final Map<String, TargetFolderProvider> _targetFolders = {};

  void registerTargetFolder(TargetFolderProvider provider) {
    _targetFolders[provider.id] = provider;
  }

  void unregisterTargetFolder(String id) {
    _targetFolders.remove(id);
  }

  TargetFolderProvider? getTargetFolder(String id) => _targetFolders[id];

  List<TargetFolderProvider> get targetFolders =>
      List.unmodifiable(_targetFolders.values);
}
