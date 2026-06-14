# ZHub - 环境搭建指南

## 1. 准备工具

| 工具 | 下载地址 | 备注 |
|------|---------|------|
| Git | https://git-scm.com | 已有可跳过 |
| Flutter SDK | https://flutter.dev | 解压到 C:\flutter |
| VS 生成工具 2022 | https://visualstudio.microsoft.com/zh-hans/downloads/#build-tools-for-visual-studio-2022 | 安装时勾选「使用 C++ 的桌面开发」，不需要装完整 VS |
| NuGet | https://www.nuget.org/downloads | 下载 nuget.exe 手动放到 %LOCALAPPDATA%\Pub\Cache\bin\ |

## 2. 配置步骤

```powershell
# 1. 添加 Flutter 到 PATH
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\flutter\bin", "User")

# 2. 重启终端，或刷新当前会话
$env:Path = "C:\flutter\bin;$env:Path"

# 3. 开启 Windows 开发者模式（必须，否则桌面编译失败）
start ms-settings:developers
# -> 在弹出的窗口中将「开发人员模式」开关打开

# 4. 配置 Flutter（关闭 Android，开启 Windows 桌面和 Web）
flutter config --no-enable-android
flutter config --enable-windows-desktop
flutter config --enable-web

# 5. 检查环境
flutter doctor
# 确保 Flutter 和 Visual Studio 两项打 勾
```

## 3. 克隆并运行项目

```powershell
cd 你的工作目录
git clone <仓库地址> zhub
cd zhub
flutter pub get

# Edge 浏览器运行（最快，推荐验证用）
$env:CHROME_EXECUTABLE = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
flutter run -d edge

# Windows 桌面运行
flutter run -d windows

# 开发中热重载：按 r  退出：按 q
```

## 4. 常见问题

| 问题 | 解决 |
|------|------|
| flutter 命令找不到 | 重启终端，或手动 $env:Path = "C:\flutter\bin;$env:Path" |
| Building with plugins requires symlink support | 开启 Windows 开发者模式 |
| Nuget.exe not found | 手动下载 nuget.exe 放到 %LOCALAPPDATA%\Pub\Cache\bin\ |
| Edge 浏览器没反应 | 设置 $env:CHROME_EXECUTABLE 指向 msedge.exe |
