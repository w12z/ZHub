# ZHub 项目文件结构

```
zhub/
├── pubspec.yaml                  # 项目配置：名称、依赖包、SDK版本
├── pubspec.lock                  # 依赖精确版本锁定
├── analysis_options.yaml         # Dart 静态分析规则
├── README.md
├── PROJECT_STRUCTURE.md
├── SETUP_GUIDE.md
│
├── assets/
│   └── icons/
│       └── ico.png               # 应用图标源文件
│
├── lib/
│   ├── main.dart                 # App 入口：Documents 路径注入 → 创建目录 → 注册模块 → runApp
│   │
│   ├── core/                     # 核心框架（不可卸载）
│   │   ├── feature_interface.dart  # AppFeature 抽象接口
│   │   ├── feature_registry.dart   # 全局注册表：注册/启用/禁用/卸载
│   │   ├── file_item.dart          # 文件/目录模型 + 分类 + 图标
│   │   ├── core_hub.dart           # 核心逻辑：Provider + UI + Service + setDocumentsPath()
│   │   ├── module_services.dart    # 模块间服务定位（TargetFolderProvider）
│   │   └── key_value_store.dart    # 键值持久化（模块启用状态）
│   │
│   └── features/                 # 可插拔功能模块
│       ├── wifi_transfer/
│       │   ├── wifi_transfer.dart          # 实现：Server + Provider + UI + HTML 上传页
│       │   └── wifi_transfer_feature.dart  # AppFeature 实现
│       ├── pdf_viewer/
│       │   ├── pdf_viewer_feature.dart     # AppFeature 实现 + openPdf / pickAndOpenPdf
│       │   ├── pdf_viewer_page.dart        # PDF 查看页面
│       │   ├── pdf_viewer_body_native.dart # 原生渲染（flutter_cached_pdfview）
│       │   ├── pdf_viewer_body_web.dart    # Web 渲染（pdf.js）
│       │   └── pdf_provider.dart           # 最近打开记录
│       └── music_player/
│           ├── music_player_feature.dart   # AppFeature 实现
│           ├── models/
│           │   ├── music_track.dart        # 曲目模型 + Playlist + QueuePlaylist
│           │   └── eq_preset.dart          # 均衡器预设 (8内置 + 自定义)
│           ├── services/
│           │   ├── audio_player_service.dart # 播放引擎 (ChangeNotifier 单例)
│           │   ├── audio_routing_service.dart# 输出设备管理
│           │   ├── equalizer_service.dart    # 8段均衡器
│           │   ├── music_player_settings.dart# 集中化用户设置
│           │   ├── music_scanner.dart        # 文件夹扫描
│           │   └── playlist_repository.dart  # SQLite CRUD + scan_cache
│           ├── providers/
│           │   ├── music_library_provider.dart # 曲目库 + 扫描编排 + 重命名联动
│           │   └── playlist_provider.dart      # 歌单 CRUD + EQ 预设
│           ├── pages/
│           │   ├── music_library_page.dart   # 「所有音频」+「我的歌单」
│           │   ├── now_playing_page.dart     # 全屏播放器 + 卡片堆队列
│           │   ├── playlist_detail_page.dart # 歌单详情 (PageView 滑动)
│           │   └── settings_page.dart        # 统一设置 (播放模式/EQ/输出设备/打断)
│           └── widgets/
│               ├── mini_player.dart          # 底部迷你播放器
│               ├── playback_controls.dart    # 播放/暂停/上下首
│               ├── progress_bar.dart         # 进度条 (可拖拽)
│               ├── track_list_tile.dart      # 曲目列表项
│               ├── add_to_playlist_sheet.dart# 添加曲目到歌单
│               ├── eq_band_slider.dart       # EQ 频段滑块
│               └── eq_preset_manager.dart    # EQ 预设管理
│
├── test/
│   └── widget_test.dart
│
├── ios/                          # iOS 原生工程（含 Podfile、AppDelegate、AppIcon）
├── windows/                      # Windows 桌面原生工程
├── web/                          # Web 入口（pdf.js worker）
└── android/                      # Android（未启用）
```

## 架构：可插拔模块系统

所有功能除核心外均为可插拔模块，启用/禁用/卸载由 `FeatureRegistry` 统一管理。

### AppFeature 接口

| 成员 | 类型 | 说明 |
|---|---|---|
| id | String | 唯一标识 |
| name | String | 显示名称 |
| description | String | 功能描述 |
| iconAsset | String | 图标路径 |
| enabledByDefault | bool | 首次安装是否启用 |
| buildPage(context) | Widget | 模块主页 |
| init() | Future<void> | 初始化（应用启动时调用） |
| dispose() | Future<void> | 销毁（卸载时调用） |

### FeatureRegistry

- `register(feature)` → 注册模块
- `enable(id)` → 启用模块（显示在导航栏，调用 init()）
- `disable(id)` → 禁用模块（隐藏 UI，调用 dispose()）
- `uninstall(id)` → 卸载模块（移除注册）
- `enabledFeatures` → 获取已启用模块列表

### 启动流程

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `getApplicationDocumentsDirectory()` → `setDocumentsPath()` 注入 Documents 路径
3. 创建 `transfer/` 和 `Music/` 用户目录
4. 注册所有模块到 `FeatureRegistry`
5. 对已启用的模块调用 `init()`
6. `MultiProvider` 注入全局 Provider
7. `runApp()` → `HomePage` 根据已启用模块动态生成导航栏

### iOS 目录结构

App 启动后在 Documents 目录下自动创建：

```
Documents/              ← 文件浏览根目录（不可回退到上级）
├── transfer/           ← WiFi 传输接收目录
└── Music/              ← 音乐文件目录
```

## 运行

```bash
flutter pub get
flutter run --release -d <ios-device-id>   # iOS 真机
flutter run -d <simulator-id>              # iOS 模拟器
flutter run -d windows                     # Windows 桌面
flutter analyze                            # 静态分析
```
