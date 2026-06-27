# ZHub

多模块文件管理应用，采用可插拔架构。支持 iOS 与 Windows 桌面双平台。

## 功能

| 模块 | 类型 | 状态 |
|---|---|---|
| 文件浏览 | 核心（不可卸载） | 已完成 |
| 快速访问 | 核心（不可卸载） | 已完成 |
| Wi-Fi 传输 | 可插拔模块 | 已完成 |
| PDF 预览 | 可插拔模块 | 已完成（`flutter_cached_pdfview`） |
| 音乐播放 | 可插拔模块 | 基本实现（默认关闭） |

## 架构

```
MultiProvider
├── FileBrowserProvider       →  文件浏览（目录导航、增删）
├── QuickAccessProvider       →  快速访问（收藏、持久化）
├── AudioPlayerService        →  音乐播放（ChangeNotifier 单例）
├── MusicLibraryProvider      →  音乐库扫描
└── PlaylistProvider          →  歌单管理

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

lib/features/music_player/
├── music_player_feature.dart     模块入口（AppFeature 实现）
├── services/
│   ├── audio_player_service.dart 播放引擎（ChangeNotifier 单例）
│   ├── audio_routing_service.dart输出设备切换
│   ├── equalizer_service.dart    8段均衡器（全局单例）
│   ├── music_player_settings.dart集中化用户设置
│   ├── music_scanner.dart        音乐文件扫描
│   └── playlist_repository.dart  SQLite 数据仓库
├── models/
│   ├── eq_preset.dart            均衡器预设模型（8个内置预设）
│   └── music_track.dart          曲目模型 + Playlist + QueuePlaylist
├── providers/
│   ├── music_library_provider.dart
│   └── playlist_provider.dart
├── pages/
│   ├── music_library_page.dart   音乐库主页
│   ├── now_playing_page.dart     全屏播放器
│   ├── playlist_detail_page.dart 歌单详情（PageView 滑动切换）
│   └── settings_page.dart        统一设置（播放模式/EQ/输出设备/打断策略）
└── widgets/
    ├── mini_player.dart          底部迷你播放器
    ├── playback_controls.dart    播放控制按钮
    ├── progress_bar.dart         进度条
    ├── track_list_tile.dart      曲目列表项
    ├── add_to_playlist_sheet.dart添加到歌单
    ├── eq_band_slider.dart       EQ 频段滑块
    └── eq_preset_manager.dart    EQ 预设管理
```

## 运行

```bash
# 获取依赖
flutter pub get

# iOS 真机（需配置签名）
flutter run --release -d <device-id>

# iOS 模拟器
flutter run -d <simulator-id>

# Windows 桌面
flutter run -d windows

# 静态分析
flutter analyze
```

## 添加新模块

1. 在 `lib/features/` 下新建目录
2. 实现 `AppFeature` 接口
3. 在 `main.dart` 中 `registry.register()`

---

## 更新日志

### 2026-05-27 — 扫描模式简化 + 启用性能优化

**扫描模式变更**

| # | 改动 | 说明 |
|---|------|------|
| ① | 全盘扫描 → 文件夹扫描 | 删除 `enumerateDrives()`、Isolate、系统目录黑名单，改为 FilePicker 选择文件夹直接扫描 |
| ② | 扫描按钮简化 | PopupMenuButton（增量/全盘）→ IconButton，点击即弹出文件夹选择器 |

**性能优化（启用音乐模块时）**

| # | 优化项 | 改动前 | 改动后 |
|---|--------|--------|--------|
| ① | 并行化初始化 | SoLoud + DB 串行 await | `Future.wait` 并行 |
| ② | 设置批量查询 | 5 次独立 DB 查询 | 单次 `SELECT * FROM settings` |
| ③ | 延迟非关键初始化 | EQ / 音频路由阻塞 init() | `addPostFrameCallback` 延迟到首帧后 |

**文件变更**

| 操作 | 文件 |
|------|------|
| ✏️ 重写 | `music_scanner.dart`（290→30 行，删除 Isolate/全盘扫描/黑名单） |
| ✏️ 修改 | `music_library_provider.dart`（删除 4 个旧扫描方法） |
| ✏️ 修改 | `music_library_page.dart`（PopupMenuButton → FilePicker IconButton） |
| ✏️ 修改 | `add_to_playlist_sheet.dart`（适配新扫描） |
| ✏️ 优化 | `music_player_feature.dart`（并行 init + 延迟 EQ/路由） |
| ✏️ 优化 | `music_player_settings.dart`（批量查询 + 删除冗余 helper） |

**总计：净删除 ~200 行，启用模块时减少 ~50% 等待时间。**

---

### 2026-05-27 — 合并 main + 修复 CMake 构建

**合并 main 分支新增**
- PDF 查看器模块（`pdfx` + `pdf_viewer_body_native/web` + `PdfProvider`）
- `core_hub.dart` / `file_item.dart` 更新
- Web 平台 PDF 渲染（`pdf.min.mjs` + `pdf.worker.mjs`）

**漏洞修复**

| # | 问题 | 修复 |
|---|------|------|
| ① | pdfx 插件 `DownloadProject.cmake` 指定 `cmake_minimum_required(VERSION 2.8.12)`，CMake 4.0 已移除 < 3.5 兼容 | patch 为 `VERSION 3.10`（ephemeral + pub cache 双份） |
| ② | 同上问题导致 pdfium 下载步骤 CMake 配置直接失败 | 项目 `windows/CMakeLists.txt` 新增 `CMAKE_POLICY_VERSION_MINIMUM 3.5` 安全网 |

---

### 2026-05-27 — 统一音乐模块设置界面

将音乐播放器 4 处分散的设置入口合并为一个齿轮图标设置页。

**整合（4→1）**

| 原入口 | 原 UI | 整合后 |
|--------|-------|--------|
| 播放模式按钮 | PlaybackControls 内循环按钮 | → SettingsPage ChoiceChip |
| 均衡器图标 | NowPlayingPage → EqualizerPage 独立页面 | → SettingsPage EQ Section |
| 扬声器图标 | NowPlayingPage → OutputDeviceSheet 底部弹窗 | → SettingsPage 设备列表 Section |
| more_horiz 图标 | NowPlayingPage → _InterruptModeSheet 底部弹窗 | → SettingsPage 打断策略 Section |

**文件变更**

| 操作 | 文件 |
|------|------|
| 🆕 新增 | `pages/settings_page.dart`（440行，4个Section卡片布局） |
| ✏️ 修改 | `pages/now_playing_page.dart`（底部栏 4 图标→2 图标，删除 _InterruptModeSheet） |
| ✏️ 修改 | `widgets/playback_controls.dart`（删除播放模式按钮，精简为 prev/play/next） |
| ❌ 删除 | `pages/equalizer_page.dart` |
| ❌ 删除 | `widgets/output_device_sheet.dart` |
| ✏️ 修改 | `music_player.dart`（导出更新） |

**总计：-2 文件，净减少 ~30 行。**

---

### 2026-05-26 — 全盘扫描 + 多歌单卡片队列 + 文件精简

**新增功能（7项）**

| # | 功能 | 说明 |
|---|------|------|
| ① | 全盘音乐扫描 | Windows 盘符枚举 (A:\~Z:\)，系统目录黑名单，后台 Isolate 异步扫描 |
| ② | SQLite 扫描缓存 | scan_cache 表持久化，重启即加载，增量扫描跳过已缓存文件 |
| ③ | 歌单管理分区布局 | MusicLibraryPage 重构为「所有音频」文件夹 +「我的歌单」分区 |
| ④ | 多歌单叠放卡片队列 | QueuePlaylist 运行时模型，Stack 卡片堆中心+左右各2层，拖拽切换歌单 |
| ⑤ | 歌单循环 / 全部循环 | repeatPlaylist 仅循环当前歌单，repeatAll 推进到下一歌单后回到首个 |
| ⑥ | 曲目重命名联动 | 磁盘文件 → SQLite 缓存 → 歌单引用 → 播放队列 四步同步更新 |
| ⑦ | 批量添加到歌单 + 加入队列 | addToMultiplePlaylists 支持一曲多选歌单；播放详情页「加入队列」按钮 |

**代码简化（4项）**

| # | 优化项 | 改动前 | 改动后 | 收益 |
|---|--------|--------|--------|------|
| ① | 删除孤立页面 | playlist_list_page.dart 独立存在但无导航入口 | 歌单管理已整合进 music_library_page.dart | **-200 行，-1 文件** |
| ② | 合并音频焦点监控 | audio_session_monitor.dart 31行独立文件 | 内联到 audio_player_service.dart | **-31 行，-1 文件** |
| ③ | 合并设置存储 | settings_repository.dart 64行中间层 | 内联到 music_player_settings.dart | **-64 行，-1 文件** |
| ④ | 合并模型文件 | playlist.dart 79行独立模型 | Playlist + QueuePlaylist 并入 music_track.dart | **-79 行，-1 文件** |

**漏洞修复（6项）**

| # | 问题 | 修复 |
|---|------|------|
| ① | 进度条拖到底触发 SoLoud 参数异常崩溃 | seek() 内 clamp 位置至 duration-500ms + try-catch 防护 |
| ② | flutter_soloud 插件 DLL 未构建 | pubspec.yaml 中 win32audio/flutter_soloud 误放入 dependency_overrides → 移回 dependencies |
| ③ | sqlite3 3.x native assets 下载失败导致构建失败 | sqlite3 覆盖为 2.4.0 + sqflite_common_ffi 锁定 2.3.2 |
| ④ | 扫描按钮在「所有音频」视图不可见 | 移除 `if (!_showAllAudio)` 条件限制 |
| ⑤ | 顺序模式播完最后一首显示「未选择曲目」 | _onTrackComplete 保留 _currentIndex 停留在最后一首，添加 `if (!_isPlaying) return` 防重入守卫 |
| ⑥ | 卡片堆右侧卡片覆盖上层左侧卡片 | Stack children 按距中心距离排序，中心顶层 → ±1 → ±2 |

**文件变更**

| 操作 | 文件 |
|------|------|
| ❌ 删除 | `pages/playlist_list_page.dart` |
| ❌ 删除 | `services/audio_session_monitor.dart` |
| ❌ 删除 | `services/settings_repository.dart` |
| ❌ 删除 | `models/playlist.dart` |
| ✏️ 重写 | `music_scanner.dart`（Isolate 全盘扫描 + ScanProgress 内部类 + DriveEnumerator） |
| ✏️ 重写 | `music_library_page.dart`（分区布局 + 歌单列表 + 添加到歌单弹窗 + 扫描进度条） |
| ✏️ 重写 | `now_playing_page.dart`（StatefulWidget + 卡片堆 Stack + 拖拽手势 + 分组队列菜单） |
| ✏️ 重写 | `music_library_provider.dart`（缓存加载 + 扫描编排 + 重命名联动） |
| ✏️ 重写 | `music_player_settings.dart`（内联 SettingsRepository） |
| ✏️ 修改 | `audio_player_service.dart`（_queuePlaylists 多歌单队列 + replaceTrackInQueue + 内联 AudioSessionMonitor + 默认歌单循环 + seek 加固） |
| ✏️ 修改 | `music_track.dart`（+lastModified, copyWith, toJson/fromJson + Playlist + QueuePlaylist） |
| ✏️ 修改 | `playlist_repository.dart`（v3 迁移 + scan_cache 表 + 所有缓存方法 + updateTrackPath） |
| ✏️ 修改 | `playlist_provider.dart`（+addToMultiplePlaylists） |
| ✏️ 修改 | `playlist_detail_page.dart`（+加入队列按钮） |
| ✏️ 修改 | `playback_controls.dart`（+repeatPlaylist 模式） |
| ✏️ 修改 | `pubspec.yaml`（sqlite3 版本覆盖修复构建） |
| 🆕 新增 | `lib/features/music_player/README.md`（模块文档） |

**总计：-4 文件（28→24），新增 7 项功能，修复 6 项漏洞。**

---

### 2026-05-26 — 音乐播放器模块重构

**代码简化（6项）**

| # | 优化项 | 改动前 | 改动后 | 收益 |
|---|--------|--------|--------|------|
| ① | 合并 Provider → Service | `PlayerStateProvider` + `AudioPlayerService` 双层代理 | `AudioPlayerService` 直接继承 `ChangeNotifier`，作为单例 | **-147 行，-1 文件** |
| ② | 合并三个 Timer | 3 个独立 Timer（250ms / 500ms / 2000ms） | 1 个统一 250ms 轮询，通过 `_tickCount` 分级检查 | **-2 Timer** |
| ③ | 修复 N+1 查询 | `getAll()` 每条 playlist 一次独立 DB 查询 | 单次 `LEFT JOIN` 查询 | **-10 查询**（10歌单场景） |
| ④ | 集中 Settings | 3 个文件各自调用 `SettingsRepository` 读写 | 新增 `MusicPlayerSettings` 统一管理所有用户设置 | 消除分散持久化 |
| ⑤ | 去重 EQ 预设 | 内置预设同时定义在代码常量 + DB 插入 | 仅在 `EqPreset.builtInPresets` 定义，DB 只存用户自定义 | 单一真实来源 |
| ⑥ | 简化 iOS 音频焦点 | `AudioFocusHandler` 73 行（`isInterrupted` 标志 + 中断监听） | 28 行（直接使用 `secondaryAudioShouldBeSilencedHint`） | **-45 行（-62%）** |

**文件变更**

| 操作 | 文件 |
|------|------|
| 🆕 新增 | `lib/features/music_player/services/music_player_settings.dart` |
| ❌ 删除 | `lib/features/music_player/providers/player_state_provider.dart` |
| ✏️ 重写 | `audio_player_service.dart`（合并 PlayerStateProvider + 统一 Timer） |
| ✏️ 重写 | `equalizer_service.dart`（改用 MusicPlayerSettings） |
| ✏️ 重写 | `audio_routing_service.dart`（去掉独立 Timer，改用 MusicPlayerSettings） |
| ✏️ 简化 | `audio_session_monitor.dart`（去掉独立 Timer，仅做 MethodChannel 封装） |
| ✏️ 简化 | `ios/Runner/AudioFocusHandler.swift`（73→28 行） |
| ✏️ 修改 | `playlist_repository.dart`（N+1→JOIN，去重 EQ 预设） |
| ✏️ 修改 | `music_player_feature.dart`（启用 MusicPlayerSettings，默认关闭模块） |
| ✏️ 修改 | `main.dart`（用 `AudioPlayerService.instance` 代替 `PlayerStateProvider`） |
| ✏️ 修改 | `mini_player.dart` / `now_playing_page.dart` / `music_library_page.dart` / `playlist_detail_page.dart`（`PlayerStateProvider` → `AudioPlayerService`） |

**总计：-486 行 / +244 行，净减少 242 行，删除 1 个文件，消除 2 个冗余 Timer。**

---

### 2026-06-14 — iOS 适配与功能修复

**Bug 修复**

| # | 问题 | 修复 |
|---|------|------|
| ① | `sqflite_common_ffi` 在 iOS 上导致数据库崩溃 | 仅桌面端启用 FFI，iOS/Android 使用原生 sqflite |
| ② | `homePath` 在 iOS 真机指向错误路径，文件浏览为空 | 通过 `setDocumentsPath()` 注入 App Documents 目录 |
| ③ | Documents 目录可回退到上级，看到系统垃圾文件夹 | `canGoUp` 限制不能退出 Documents 根目录 |
| ④ | WiFi 传输文件改名（时间戳），丢失原始文件名 | 保留原始文件名，重名加「副本」 |
| ⑤ | 快速访问点击文件夹不导航，只弹信息框 | 点击文件夹导航到 FileBrowserPage 并恢复路径 |
| ⑥ | 从快速访问进入文件夹后关闭，文件标签页残留子目录 | dispose 时恢复原始路径 |
| ⑦ | PDF 预览无法加载（pdfx 兼容性问题） | 替换为 `flutter_cached_pdfview`，支持本地 fromPath |
| ⑧ | App 图标为 Flutter 默认图标 | 从 `assets/icons/ico.png` 生成所有尺寸 iOS 图标 |
| ⑨ | AppDelegate 使用不存在的 `FlutterImplicitEngineDelegate` | 简化为标准 `FlutterAppDelegate`，内联 AudioFocusHandler |

**Dart SDK 兼容性**

| # | 改动 | 说明 |
|---|------|------|
| ① | `flutter_soloud` 4.0.6 → 3.5.4 | Dart SDK 3.9.2 不满足 4.x 的 >=3.11.0 要求 |
| ② | `parametricEqFilter` → `equalizerFilter` | 3.5.4 API 不同，8 段均衡器 |
| ③ | `play()` 返回值加 `await` | 3.5.4 返回 `Future<SoundHandle>` |
| ④ | `onReorderItem` → `onReorder` | API 名称变更 |
| ⑤ | `bandCount` 10 → 8 | 匹配 3.5.4 均衡器段数 |

**文件变更**

| 操作 | 文件 |
|------|------|
| ✏️ 修改 | `lib/main.dart`（注入 Documents 路径、创建 transfer/Music 目录） |
| ✏️ 修改 | `lib/core/core_hub.dart`（iOS 路径、canGoUp 限制、QuickAccess 导航、PDF 打开逻辑） |
| ✏️ 修改 | `lib/features/wifi_transfer/wifi_transfer.dart`（保留原始文件名、重复加副本） |
| ✏️ 修改 | `lib/features/wifi_transfer/wifi_transfer_feature.dart`（移除重复 auto-pin） |
| ✏️ 修改 | `lib/features/music_player/music_player_feature.dart`（iOS 跳过 FFI） |
| ✏️ 修改 | `lib/features/music_player/models/eq_preset.dart`（10→8 段，预设截断） |
| ✏️ 修改 | `lib/features/music_player/services/equalizer_service.dart`（适配 3.5.4 API） |
| ✏️ 修改 | `lib/features/music_player/services/audio_player_service.dart`（await play） |
| ✏️ 修改 | `lib/features/music_player/pages/playlist_detail_page.dart`（onReorder） |
| ✏️ 替换 | `lib/features/pdf_viewer/pdf_viewer_page.dart`（pdfx → flutter_cached_pdfview） |
| ✏️ 替换 | `lib/features/pdf_viewer/pdf_viewer_body_native.dart`（pdfx → flutter_cached_pdfview） |
| ✏️ 修改 | `ios/Runner/AppDelegate.swift`（简化，内联 AudioFocusHandler） |
| ✏️ 替换 | `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`（替换为 ico.png） |
| ✏️ 修改 | `ios/Runner.xcodeproj/project.pbxproj`（Bundle ID） |
| ✏️ 修改 | `pubspec.yaml`（降级 flutter_soloud、移除 pdfx、增加 flutter_cached_pdfview） |
| 🆕 新增 | `ios/Podfile`、`ios/Podfile.lock` |
| ✏️ 修改 | `.gitignore`（iOS/windows 生成文件） |

**总计：修复 9 项 Bug，适配 5 项 SDK 兼容性问题，修改 20 个文件。**
