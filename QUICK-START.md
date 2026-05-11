# 快速开始：Android Studio 调试和 APK 构建

**日期:** 2026-05-11

---

## 📋 前置条件检查

### 1. 检查设备连接

```bash
adb devices
```

预期输出:
```
List of devices attached
26f01ec875217ece    device
```

### 2. 检查 Android SDK

```powershell
ls "C:\Users\Pengd\AppData\Local\Android\Sdk\build-tools"
```

预期: 包含 `36.1.0` 或更高版本

---

## 🚀 方法 1: 使用脚本构建 (最快)

### Windows 批处理

1. 双击运行 `build-apk.bat`
2. 脚本会自动:
   - 检查 Flutter
   - 获取依赖
   - 清理构建
   - 构建 APK
   - 提供安装选项

### PowerShell

1. 右键点击 `Build-APK.ps1`
2. 选择 "使用 PowerShell 运行"
3. 如果提示执行策略错误，运行:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

## 🎯 方法 2: 手动构建 (完整控制)

### 步骤 1: 添加 Flutter 到 PATH

#### 临时添加 (当前会话):

```powershell
$env:PATH += ";C:\flutter\bin"
```

#### 永久添加:

1. 右键 "此电脑" → "属性"
2. "高级系统设置" → "环境变量"
3. 在 "用户变量" 中编辑 `Path`
4. 添加: `C:\flutter\bin` (或你的 Flutter 安装路径)

### 步骤 2: 验证 Flutter 安装

```powershell
flutter --version
flutter doctor
```

预期输出类似:
```
Flutter 3.24.0 • channel stable
```

### 步骤 3: 构建调试版本 (用于开发)

```powershell
cd D:\javaRepository\anynote\frontend

# 构建调试版本
flutter build apk --debug

# 输出: build\app\outputs\flutter-apk\app-debug.apk
```

### 步骤 4: 构建发布版本 (用于测试)

```powershell
# 构建发布版本
flutter build apk --release

# 输出: build\app\outputs\flutter-apk\app-release.apk
```

### 步骤 5: 安装到设备

```powershell
# 卸载旧版本
adb uninstall com.anynote.app

# 安装新版本
adb install frontend\build\app\outputs\flutter-apk\app-release.apk

# 启动应用
adb shell am start -n com.anynote.app/.MainActivity
```

---

## 🐛 方法 3: 使用 Android Studio 调试

### 步骤 1: 安装 Android Studio

如果未安装:

1. 下载: https://developer.android.com/studio
2. 运行安装程序
3. 安装向导中选择:
   - ✅ Android SDK
   - ✅ Android Virtual Device (可选)
   - ✅ Flutter 插件

### 步骤 2: 打开项目

1. 启动 Android Studio
2. `File` → `Open`
3. 选择: `D:\javaRepository\anynote\frontend`
4. 等待 Gradle 同步 (首次可能需要几分钟)

### 步骤 3: 配置 Flutter SDK

1. `File` → `Settings` (或 `Ctrl + Alt + S`)
2. `Languages & Frameworks` → `Flutter`
3. 设置 Flutter SDK 路径
4. `Apply` → `OK`

### 步骤 4: 运行应用 (调试模式)

1. 确保设备已连接
2. 在工具栏选择设备: `26f01ec875217ece`
3. 点击绿色 ▶️ 按钮 (或 `Shift + F10`)
4. 应用会自动:
   - 构建调试版本
   - 安装到设备
   - 启动应用
   - 附加调试器

### 步骤 5: 使用调试功能

#### 设置断点

- 在代码行号左侧点击
- 断点显示为红色圆点 ○

#### 查看变量

- `Debug` 窗口 → `Variables` 标签
- 查看当前作用域的所有变量

#### 查看日志

- 底部 `Logcat` 标签
- 或 `Run` → `Logcat`

#### 热重载

- 点击 🔥 图标
- 或按 `Ctrl + \`
- 保留应用状态

#### 热重启

- 点击 🔄 图标
- 或按 `Ctrl + Shift + \`
- 重启应用

---

## 📊 验证构建结果

### 检查 APK 文件

```powershell
dir frontend\build\app\outputs\flutter-apk\
```

预期文件:
- `app-debug.apk` - 调试版本
- `app-release.apk` - 发布版本

### 检查安装版本

```powershell
adb shell dumpsys package com.anynote.app | findstr version
```

预期输出:
```
versionCode=4002
versionName=2.6.0
```

### 查看 App 日志

```powershell
# 实时日志
adb logcat | findstr "anynote"

# 保存到文件
adb logcat > app_logs.txt
```

---

## 🔧 常见问题解决

### 问题: "flutter 不是内部或外部命令"

**解决:**
```powershell
# 添加 Flutter 到 PATH (临时)
$env:PATH += ";C:\flutter\bin"

# 验证
flutter --version
```

### 问题: Gradle 构建失败

**解决:**
```powershell
cd frontend\android
.\gradlew clean
.\gradlew build
```

### 问题: 设备未显示

**解决:**
```powershell
# 重启 ADB 服务
adb kill-server
adb start-server

# 检查设备
adb devices

# 确保设备上开启了 USB 调试
```

### 问题: 安装失败 INSTALL_FAILED_UPDATE_INCOMPATIBLE

**解决:**
```powershell
# 卸载旧版本
adb uninstall com.anynote.app

# 重新安装
adb install frontend\build\app\outputs\flutter-apk\app-release.apk
```

---

## 📝 测试检查清单

APK 安装后,验证以下功能:

- [ ] App 启动成功
- [ ] 暗色模式颜色温暖 (30°)
- [ ] 注册/登录界面
- [ ] FAB 按钮可见
- [ ] 笔记列表显示
- [ ] 设置菜单可访问
- [ ] 无明显崩溃

---

**创建时间:** 2026-05-11  
**版本:** 1.0
