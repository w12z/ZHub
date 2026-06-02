import 'package:flutter/material.dart';

/// 所有模块的统一接口。
/// 每个 feature 模块都必须实现此接口，才能被 FeatureRegistry 管理。
abstract class AppFeature {
  /// 模块唯一标识，如 "wifi_transfer"、"pdf_viewer"
  String get id;

  /// 模块显示名称，如 "Wi-Fi 传输"
  String get name;

  /// 模块描述
  String get description;

  /// 模块图标
  String get iconAsset;

  /// 模块导航栏图标
  IconData get icon;

  /// 是否默认启用（首次安装时）
  bool get enabledByDefault;

  /// 模块的主页面 Widget
  Widget buildPage(BuildContext context);

  /// 模块初始化（应用启动时调用）
  Future<void> init();

  /// 模块销毁（卸载时调用）
  Future<void> dispose();
}
