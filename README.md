# File Hub
多模块文件管理应用，采用可插拔架构。当前在 Windows 桌面开发，目标平台为 iOS。

## 功能

| 模块 | 类型 | 状态 |
|---|---|---|
| 文件浏览 | 核心（不可卸载） | 已完成 |
| 快速访问 | 核心（不可卸载） | 已完成 |
| Wi-Fi 传输 | 可插拔模块 | 待实现 |
| PDF 预览 | 可插拔模块 | 待实现 |
| 音乐播放 | 可插拔模块 | 待实现 |

## 架构

```
MultiProvider
├── FileBrowserProvider   →  文件浏览（目录导航、增删）
└── QuickAccessProvider   →  快速访问（收藏、持久化）

HomePage (IndexedStack + NavigationBar)
├── Tab 0: FileBrowserPage   (文件)
├── Tab 1: QuickAccessPage   (快速访问)
└── Tab N: 启用后动态接入的模块页
```

模块系统基于 `AppFeature` 接口 + `FeatureRegistry` 注册表，类似 VS Code 插件模型。

## 核心文件

```
lib/core/
├── feature_interface.dart    AppFeature 抽象接口
├── feature_registry.dart     全局注册表（单例）
├── file_item.dart            文件/目录模型 + 分类 + 图标
└── core_hub.dart             核心页面 + Provider + Service
```

## 运行

```bash
# Windows 桌面
flutter run -d windows

# Web (Edge)
flutter run -d edge

# 静态分析
flutter analyze
```

## 添加新模块

1. 在 `lib/features/` 下新建目录
2. 实现 `AppFeature` 接口
3. 在 `main.dart` 中 `registry.register()`
