# Android Studio 调试和 APK 构建指南

**日期:** 2026-05-11  
**项目:** AnyNote v2.6.0  
**目标:** 使用 Android Studio 调试并构建 APK

---

## 当前环境状态

### ✅ 已安装

- **Android SDK:** `C:\Users\Pengd\AppData\Local\Android\Sdk`
- **Android Build Tools:** 36.1.0
- **设备:** Samsung Galaxy Note 9 (已连接)

### ❓ 需要确认

- **Android Studio:** 安装位置未知
- **Flutter SDK:** 需要确认安装路径
- **Java JDK:** 需要确认版本

---

## 步骤 1: 定位 Flutter SDK

### 方法 1: 检查常见安装位置

```powershell
# 检查 C:\flutter
Test-Path "C:\flutter\bin\flutter.bat"

# 检查用户目录
Test-Path "$env:LOCALAPPDATA\flutter\bin\flutter.bat"

# 检查 Program Files
Test-Path "C:\Program Files\flutter\bin\flutter.bat"

# 检查 D 盘
Test-Path "D:\flutter\bin\flutter.bat"
```

### 方法 2: 使用 where 命令

```powershell
# 添加 Flutter 到 PATH 后检查
$env:PATH = $env:PATH + ";C:\flutter\bin"
flutter --version
```

### 方法 3: 检查 Android Studio 中的 Flutter 插件

如果 Android Studio 已安装且配置了 Flutter 插件:

1. 打开 Android Studio
2. `File` → `Settings` → `Languages & Frameworks` → `Flutter`
3. 查看 Flutter SDK path

---

## 步骤 2: 安装/配置 Flutter

### 选项 A: 下载 Flutter SDK

1. 访问: https://flutter.dev/docs/get-started/install/windows
2. 下载 Flutter SDK zip 文件
3. 解压到 `C:\flutter` 或 `D:\flutter`

### 选项 B: 使用 Android Studio 安装

1. 下载 Android Studio: https://developer.android.com/studio
2. 安装 Android Studio
3. 在首次启动向导中勾选 "Flutter" 插件
4. Android Studio 会自动下载 Flutter SDK

### 配置 Flutter

```powershell
# 设置 Flutter 环境变量
[System.Environment]::SetEnvironmentVariable('FLUTTER_ROOT', 'C:\flutter', 'User')

# 添加 Flutter 到 PATH
$env:PATH += ';C:\flutter\bin'

# 验证安装
flutter --version
flutter doctor
```

---

## 步骤 3: 在 Android Studio 中打开项目

### 3.1 打开项目

1. 启动 Android Studio
2. 选择 `File` → `Open`
3. 导航到: `D:\javaRepository\anynote`
4. 选择 `frontend` 文件夹
5. 等待 Gradle 同步和索引完成

### 3.2 配置 Flutter SDK

如果提示 Flutter SDK 未配置:

1. `File` → `Settings` → `Languages & Frameworks` → `Flutter`
2. 设置 Flutter SDK path: `C:\flutter` 或已安装的路径
3. 点击 `Apply`

---

## 步骤 4: 运行 Flutter 应用 (调试模式)

### 方法 1: 使用 Android Studio

1. 确保设备已连接: `adb devices`
2. 在 Android Studio 工具栏选择设备
3. 点击绿色 ▶️ 按钮或按 `Shift + F10`
4. 选择要启动的 main.dart 文件
5. 应用会安装到设备并启动调试

### 方法 2: 使用命令行

```powershell
cd D:\javaRepository\anynote\frontend

# 运行调试版本
flutter run

# 指定设备
flutter run -d 26f01ec875217ece

# 热重启 (保持状态)
flutter run --no-sound-null-safety

# 发布版本
flutter run --release
```

### 调试技巧

- **设置断点**: 在代码行号左侧点击
- **查看变量**: `Debug` → `Variables`
- **查看日志**: `Logcat` 标签页
- **热重载**: 按 `Ctrl + \` 或点击 🔥 按钮
- **热重启**: 按 `Ctrl + Shift + \` 或点击 🔄 按钮

---

## 步骤 5: 构建 Release APK

### 方法 1: 使用 Flutter CLI (推荐)

```powershell
cd D:\javaRepository\anynote\frontend

# 构建 release APK
flutter build apk --release

# 输出位置:
# frontend\build\app\outputs\flutter-apk\app-release.apk
```

### 方法 2: 使用 Android Studio

1. `Build` → `Flutter` → `Build APK`
2. 选择 `release` 模式
3. 点击 `Build`
4. 输出位置同上

### 构建选项

```powershell
# 构建 APK (所有架构)
flutter build apk --release

# 构建 APK (仅 arm64, 更小)
flutter build apk --release --target-platform android-arm64

# 构建 App Bundle (用于 Google Play)
flutter build appbundle --release

# 构建特定架构
flutter build apk --release --split-per-abi
```

---

## 步骤 6: 安装 APK 到设备

### 方法 1: 使用 adb

```powershell
# 卸载旧版本 (如果需要)
adb uninstall com.anynote.app

# 安装新版本
adb install frontend\build\app\outputs\flutter-apk\app-release.apk

# 强制安装 (覆盖)
adb install -r frontend\build\app\outputs\flutter-apk\app-release.apk
```

### 方法 2: 从 Android Studio

1. 连接设备
2. 点击 `Run` 按钮
3. Android Studio 会自动构建并安装

---

## 步骤 7: 验证安装

### 7.1 检查 App 版本

```powershell
adb shell dumpsys package com.anynote.app | grep versionCode
adb shell dumpsys package com.anynote.app | grep versionName
```

预期输出:
```
versionCode=4002
versionName=2.6.0
```

### 7.2 启动 App

```powershell
adb shell am start -n com.anynote.app/.MainActivity
```

### 7.3 查看日志

```powershell
# 实时日志
adb logcat | grep -E "anynote|flutter"

# 保存日志到文件
adb logcat > app_log.txt
```

---

## 步骤 8: 调试常见问题

### 8.1 时区修复验证

**预期行为:**
- 不应出现 "Location with the name CST doesn't exist" 错误
- 本地通知应正常初始化

**测试方法:**
```powershell
adb logcat | findstr "notification"
```

### 8.2 检查依赖

```powershell
cd frontend
flutter doctor -v
```

**预期输出:**
- ✅ Flutter SDK
- ✅ Android SDK
- ✅ Android Studio
- ✅ Connected Device

### 8.3 清理构建缓存

```powershell
cd frontend

# 清理 Flutter 缓存
flutter clean

# 删除构建目录
Remove-Item -Recurse -Force build\,.dart_tool

# 重新获取依赖
flutter pub get

# 重新构建
flutter build apk --release
```

---

## 步骤 9: 性能分析

### 9.1 使用 DevTools

1. 运行应用: `flutter run`
2. 打开 DevTools: `flutter pub global activate devtools`
3. 启动 DevTools: `flutter pub global run devtools`
4. 在 Chrome 中打开 DevTools 界面

### 9.2 CPU Profiler

在 Android Studio 中:
1. `View` → `Tool Windows` → `Profiler`
2. 选择设备和应用
3. 点击 CPU 按钮

### 9.3 Memory Profiler

在 Android Studio 中:
1. `View` → `Tool Windows` → `Profiler`
2. 点击 Memory 按钮
3. 捕获堆转储

---

## 故障排除

### 问题: "flutter 命令未找到"

**解决:**
```powershell
# 添加 Flutter 到 PATH (临时)
$env:PATH += ";C:\flutter\bin"

# 或设置环境变量 (永久)
[System.Environment]::SetEnvironmentVariable('Path', $env:PATH + ';C:\flutter\bin', 'Machine')
```

### 问题: Gradle 同步失败

**解决:**
```powershell
cd frontend\android
.\gradlew clean
.\gradlew build
```

### 问题: 设备未授权

**解决:**
```powershell
# 检查设备连接
adb devices

# 授权 USB 调试
# 在设备上: 设置 → 开发者选项 → USB 调试 (开启)

# 允许 USB 调试确认
adb kill-server
adb start-server
adb devices
```

### 问题: 应用安装失败 INSTALL_FAILED_UPDATE_INCOMPATIBLE

**解决:**
```powershell
# 卸载旧版本
adb uninstall com.anynote.app

# 重新安装
adb install frontend\build\app\outputs\flutter-apk\app-release.apk
```

---

## 下一步

1. ✅ 定位并配置 Flutter SDK
2. ✅ 在 Android Studio 中打开项目
3. ✅ 运行调试模式验证功能
4. ✅ 构建 release APK
5. ✅ 安装到设备进行测试
6. ✅ 验证时区修复
7. ✅ 完成 v2.6.0 功能测试

---

**创建时间:** 2026-05-11  
**最后更新:** 2026-05-11
