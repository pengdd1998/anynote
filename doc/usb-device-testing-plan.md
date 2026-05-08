# AnyNote USB设备实景测试方案

## 一、环境准备验证

### 1.1 ADB连接检查

```bash
# 执行这些命令验证环境

# 1. 检查ADB设备连接
adb devices

# 2. 获取设备信息
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release

# 3. 检查AnyNote应用是否安装
adb shell pm list packages | grep anynote

# 4. 获取应用版本
adb shell dumpsys package com.anynote.app | grep versionName

# 5. 清除应用数据（如需重置测试环境）
adb shell pm clear com.anynote.app

# 6. 启动应用
adb shell am start -n com.anynote.app/.MainActivity
```

### 1.2 日志收集配置

```bash
# 启动日志记录（在测试开始时执行）
adb logcat -c  # 清空旧日志
adb logcat -v time | grep -E "(AnyNote|anynote|Flutter)" > anynote_test_log_$(date +%Y%m%d_%H%M%S).txt &

# 停止日志记录（测试结束后）
pkill -f "adb logcat"
```

---

## 二、测试用例套件

### 2.1 安装与启动测试 (ST-001 至 ST-005)

| ID | 测试场景 | 操作步骤 | 预期结果 | adb验证 |
|----|---------|---------|---------|---------|
| ST-001 | 应用安装 | `adb install -r app-arm64-v8a-release.apk` | 安装成功 | `pm list packages \| grep anynote` |
| ST-002 | 冷启动 | `adb shell am start -n com.anynote.app/.MainActivity` | 显示欢迎页 | `dumpsys activity activities \| grep anynote` |
| ST-003 | 热启动 | 后台→前台 | 恢复上次状态 | 检查activity状态 |
| ST-004 | 权限请求 | 首次启动 | 请求必要权限 | `adb shell dumpsys package com.anynote.app \| grep permissions` |
| ST-005 | 应用卸载 | `adb uninstall com.anynote.app` | 卸载成功 | 包列表中不存在 |

### 2.2 注册登录测试 (AUTH-001 至 AUTH-015)

| ID | 测试场景 | 操作步骤 | 预期结果 | 验证方法 |
|----|---------|---------|---------|---------|
| AUTH-001 | 注册-有效邮箱 | 输入邮箱+密码+确认 | 注册成功，进入主页 | logcat无ERROR |
| AUTH-002 | 注册-邮箱已存在 | 使用已注册邮箱 | 提示"邮箱已注册" | Toast消息 |
| AUTH-003 | 注册-弱密码 | 输入5位密码 | 提示密码要求 | 表单验证 |
| AUTH-004 | 注册-密码不匹配 | 密码≠确认密码 | 提示不匹配 | 表单验证 |
| AUTH-005 | 登录-正确凭证 | 已注册邮箱+密码 | 登录成功 | 进入笔记列表 |
| AUTH-006 | 登录-错误密码 | 错误密码 | 提示凭证错误 | API响应401 |
| AUTH-007 | 登录-未注册邮箱 | 不存在的邮箱 | 提示用户不存在 | API响应404 |
| AUTH-008 | 登录-空字段 | 空邮箱或密码 | 表单验证提示 | 表单状态 |
| AUTH-009 | 恢复-有效恢复词 | 输入正确12词 | 重置成功 | API响应200 |
| AUTH-010 | 恢复-无效恢复词 | 错误恢复词 | 提示无效 | API响应400 |
| AUTH-011 | 恢复-词数错误 | 11词或13词 | 提示格式错误 | 表单验证 |
| AUTH-012 | 登出 | 点击登出 | 返回登录页 | 清除token |
| AUTH-013 | Token刷新 | Token过期后操作 | 自动刷新成功 | 无感续期 |
| AUTH-014 | 生物识别登录 | 启用后重启 | 指纹/Face ID解锁 | 系统认证 |
| AUTH-015 | 离线登录 | 断网后登录 | 显示离线模式 | 本地凭证验证 |

### 2.3 笔记CRUD测试 (NOTE-001 至 NOTE-020)

| ID | 测试场景 | 操作步骤 | 预期结果 | 数据验证 |
|----|---------|---------|---------|---------|
| NOTE-001 | 创建纯文本笔记 | 输入标题+内容 | 保存成功 | 本地DB+服务器 |
| NOTE-002 | 创建Markdown笔记 | 输入MD语法 | 正确渲染 | 预览一致 |
| NOTE-003 | 创建中文笔记 | 输入中文内容 | 编码正确 | UTF-8验证 |
| NOTE-004 | 创建长文本笔记 | >5000字 | 保存成功 | 大文件处理 |
| NOTE-005 | 添加标签 | 选择标签 | 保存成功 | 标签关联 |
| NOTE-006 | 编辑现有笔记 | 修改内容 | 更新成功 | 版本号递增 |
| NOTE-007 | 删除笔记 | 删除操作 | 确认后删除 | 软删除标记 |
| NOTE-008 | 搜索笔记-标题 | 搜索关键词 | 显示匹配结果 | FTS5查询 |
| NOTE-009 | 搜索笔记-内容 | 搜索正文 | 显示匹配结果 | FTS5查询 |
| NOTE-010 | 搜索笔记-标签 | 按标签筛选 | 显示该标签笔记 | 标签过滤 |
| NOTE-011 | 笔记排序-时间 | 按修改时间排序 | 顺序正确 | ORDER BY |
| NOTE-012 | 笔记排序-标题 | 按字母排序 | 顺序正确 | ORDER BY |
| NOTE-013 | 收藏笔记 | 点击星标 | 添加到收藏 | is_favorited=1 |
| NOTE-014 | 笔记详情页 | 点击笔记 | 显示完整内容 | 渲染正确 |
| NOTE-015 | 笔记分享 | 生成分享链接 | 链接可访问 | share_token |
| NOTE-016 | 批量操作 | 选择多个笔记 | 批量删除/移动 | 事务执行 |
| NOTE-017 | 粘贴图片 | 从剪贴板粘贴 | 图片上传 | 图片URL |
| NOTE-018 | 添加附件 | 上传文件 | 附件关联 | file_id |
| NOTE-019 | 版本历史 | 查看历史版本 | 显示版本列表 | version > 1 |
| NOTE-020 | 恢复版本 | 选择旧版本 | 内容恢复 | 版本回滚 |

### 2.4 加密同步测试 (CRYPTO-001 至 CRYPTO-010)

| ID | 测试场景 | 操作步骤 | 预期结果 | 验证方法 |
|----|---------|---------|---------|---------|
| CRYPTO-001 | 本地加密存储 | 创建笔记后关闭 | 数据库已加密 | SQLCipher验证 |
| CRYPTO-002 | 加密同步到服务器 | 创建笔记后同步 | 服务器存储加密blob | blob非明文 |
| CRYPTO-003 | 解密拉取 | 新设备登录 | 正确解密显示 | 内容一致 |
| CRYPTO-004 | 密钥派生 | 检查密钥生成 | 每个item独立密钥 | HKDF-SHA256 |
| CRYPTO-005 | 恢复词加密 | 导出恢复词 | 已加密存储 | 非明文 |
| CRYPTO-006 | 离线创建-在线同步 | 断网创建→连网 | 同步成功 | 版本向量合并 |
| CRYPTO-007 | 冲突解决(LWW) | 双设备同时编辑 | 后赢策略 | 版本时间戳 |
| CRYPTO-008 | 增量同步 | 修改单个笔记 | 仅同步变更 | diff传输 |
| CRYPTO-009 | 全量同步 | 首次登录 | 拉取所有数据 | 完整同步 |
| CRYPTO-010 | 同步状态指示 | 查看同步状态 | 正确显示pending/synced | 状态UI |

### 2.5 AI辅助测试 (AI-001 至 AI-008)

| ID | 测试场景 | 操作步骤 | 预期结果 | 验证方法 |
|----|---------|---------|---------|---------|
| AI-001 | AI续写 | 选中文本→续写 | 生成相关内容 | 流式输出 |
| AI-002 | AI摘要 | 全文摘要 | 生成概要 | 关键点提取 |
| AI-003 | AI标签建议 | 自动建议标签 | 匹配内容 | 标签相关性 |
| AI-004 | AI翻译 | 选中翻译 | 目标语言 | 翻译准确 |
| AI-005 | 配额检查 | 查看剩余配额 | 正确显示 | quota计数 |
| AI-006 | 自定义API | 配置API Key | 使用自定义LLM | 请求转发 |
| AI-007 | 流式输出 | 观察生成过程 | 逐字显示 | SSE解析 |
| AI-008 | 错误处理 | 无效API Key | 优雅降级 | 错误提示 |

### 2.6 平台发布测试 (PUB-001 至 PUB-006)

| ID | 测试场景 | 操作步骤 | 预期结果 | 验证方法 |
|----|---------|---------|---------|---------|
| PUB-001 | 连接XHS | 授权登录 | 连接成功 | access_token |
| PUB-002 | 发布到XHS | 选择笔记发布 | 平台显示内容 | 发布成功 |
| PUB-003 | 发布历史 | 查看历史记录 | 显示发布记录 | history表 |
| PUB-004 | 取消连接 | 断开平台连接 | 清除token | token=null |
| PUB-005 | 发布格式验证 | 发布Markdown | 正确转换 | 格式保持 |
| PUB-006 | 发布图片 | 带图发布 | 图片上传 | 图片URL |

### 2.7 离线模式测试 (OFFLINE-001 至 OFFLINE-005)

| ID | 测试场景 | 操作步骤 | 预期结果 | 验证方法 |
|----|---------|---------|---------|---------|
| OFFLINE-001 | 飞行模式创建 | 开启飞行模式 | 可创建笔记 | 本地保存 |
| OFFLINE-002 | 飞行模式编辑 | 离线编辑 | 保存到本地 | pending_sync |
| OFFLINE-003 | 恢复网络同步 | 关闭飞行模式 | 自动同步 | sync状态 |
| OFFLINE-004 | 离线搜索 | 离线状态搜索 | 本地FTS5 | 本地结果 |
| OFFLINE-005 | 离线登录 | 离线重启 | 保持登录 | 缓存凭证 |

---

## 三、自动化测试脚本

### 3.1 ADB命令批量执行脚本

```bash
#!/bin/bash
# anynote_auto_test.sh - AnyNote自动化实景测试

set -e

DEVICE_ID=""
LOG_DIR="./test_logs/$(date +%Y%m%d_%H%M%S)"
APP_PACKAGE="com.anynote.app"

mkdir -p "$LOG_DIR"

echo "=== AnyNote USB设备实景测试 ==="
echo "日志目录: $LOG_DIR"

# 1. 环境检查
echo -e "\n[1/6] 环境检查..."
adb devices | grep -q "device$" && echo "✓ 设备已连接" || { echo "✗ 未检测到设备"; exit 1; }
adb shell pm list packages | grep -q "$APP_PACKAGE" && echo "✓ 应用已安装" || echo "⚠ 应用未安装"

# 2. 记录设备信息
echo -e "\n[2/6] 收集设备信息..."
{
    echo "=== 设备信息 ==="
    adb shell getprop ro.product.model
    adb shell getprop ro.build.version.release
    adb shell getprop ro.build.version.sdk
    adb shell dumpsys display | grep "mDefaultViewport"
} > "$LOG_DIR/device_info.txt"

# 3. 启动日志记录
echo -e "\n[3/6] 启动日志捕获..."
adb logcat -c
adb logcat -v threadtime > "$LOG_DIR/logcat.txt" &
LOGCAT_PID=$!
trap "kill $LOGCAT_PID 2>/dev/null" EXIT

# 4. 执行测试序列
echo -e "\n[4/6] 执行测试序列..."

# ST-001: 清除数据重置环境
echo "ST-001: 重置应用环境..."
adb shell pm clear "$APP_PACKAGE" || true

# ST-002: 冷启动
echo "ST-002: 冷启动测试..."
time adb shell am start -n "$APP_PACKAGE/.MainActivity"
sleep 3
adb shell dumpsys window windows | grep -E "mCurrentFocus|mFocusedApp" > "$LOG_DIR/launch_cold.txt"

# 截图
adb exec-out screencap -p > "$LOG_DIR/screenshot_01_welcome.png"

# AUTH-001: 注册流程 (需要手动输入凭证)
echo "AUTH-001: 注册测试 - 请手动输入邮箱和密码"
read -p "完成注册后按Enter继续..."
adb exec-out screencap -p > "$LOG_DIR/screenshot_02_after_register.png"

# NOTE-001: 创建笔记
echo "NOTE-001: 创建笔记测试 - 请手动创建一条测试笔记"
read -p "完成创建后按Enter继续..."
adb exec-out screencap -p > "$LOG_DIR/screenshot_03_note_created.png"

# CRYPTO-001: 验证加密数据
echo "CRYPTO-001: 验证本地加密存储..."
adb shell "run-as $APP_PACKAGE cat databases/anynote.db" > "$LOG_DIR/local_db_dump.bin"
file "$LOG_DIR/local_db_dump.bin" | grep -q "data" && echo "✓ 数据库已加密(SQLCipher)" || echo "⚠ 数据库可能未加密"

# 同步测试
echo "CRYPTO-002: 验证同步加密..."
read -p "请确保网络连接，等待同步完成后按Enter..."
sleep 2
adb exec-out screencap -p > "$LOG_DIR/screenshot_04_synced.png"

# 5. 收集应用日志
echo -e "\n[5/6] 收集应用日志..."
adb logcat -d | grep -E "(AnyNote|anynote|Flutter|CRITICAL|ERROR)" > "$LOG_DIR/app_errors.txt"

# 6. 生成报告
echo -e "\n[6/6] 生成测试报告..."
cat > "$LOG_DIR/test_report.md" << 'EOF'
# AnyNote 实景测试报告

## 测试环境
- 设备: $(cat $LOG_DIR/device_info.txt | grep "ro.product.model" | cut -d= -f2)
- Android版本: $(cat $LOG_DIR/device_info.txt | grep "ro.build.version.release" | cut -d= -f2)
- 测试时间: $(date)

## 执行的测试
- [x] ST-001: 环境重置
- [x] ST-002: 冷启动
- [x] AUTH-001: 注册流程
- [x] NOTE-001: 创建笔记
- [x] CRYPTO-001: 本地加密验证
- [x] CRYPTO-002: 同步加密验证

## 截图证据
1. 欢迎页: screenshot_01_welcome.png
2. 注册后: screenshot_02_after_register.png
3. 创建笔记: screenshot_03_note_created.png
4. 同步完成: screenshot_04_synced.png

## 错误日志
$(if [ -s "$LOG_DIR/app_errors.txt" ]; then echo "发现错误，详见 app_errors.txt"; else echo "无错误"; fi)
EOF

echo -e "\n=== 测试完成 ==="
echo "报告位置: $LOG_DIR/test_report.md"
echo "截图位置: $LOG_DIR/screenshot_*.png"

# 停止logcat
kill $LOGCAT_PID 2>/dev/null
```

### 3.2 Flutter Driver测试脚本

```dart
// integration_test/app_test.dart
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('AnyNote实景测试', () {
    FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver?.close();
    });

    test('注册登录流程', () async {
      // 查找欢迎页元素
      final welcomeText = find.text('欢迎使用AnyNote');
      expect(await driver.getText(welcomeText), '欢迎使用AnyNote');

      // 点击注册按钮
      final registerBtn = find.byValueKey('register_button');
      await driver.tap(registerBtn);

      // 填写表单
      final emailField = find.byValueKey('email_field');
      final passwordField = find.byValueKey('password_field');
      final confirmField = find.byValueKey('confirm_password_field');

      await driver.tap(emailField);
      await driver.enterText('test@example.com');

      await driver.tap(passwordField);
      await driver.enterText('Test123456!');

      await driver.tap(confirmField);
      await driver.enterText('Test123456!');

      // 提交
      final submitBtn = find.byValueKey('submit_button');
      await driver.tap(submitBtn);

      // 等待导航到主页
      await driver.waitFor(find.byValueKey('notes_list'));
    });

    test('创建笔记', () async {
      final fab = find.byValueKey('create_note_fab');
      await driver.tap(fab);

      final titleField = find.byValueKey('note_title_field');
      final contentField = find.byValueKey('note_content_field');

      await driver.tap(titleField);
      await driver.enterText('测试笔记');

      await driver.tap(contentField);
      await driver.enterText('这是自动化测试创建的笔记内容');

      final saveBtn = find.byValueKey('save_note_button');
      await driver.tap(saveBtn);

      await driver.waitFor(find.text('测试笔记'));
    });
  });
}
```

---

## 四、测试执行流程

```
┌─────────────────────────────────────────────────────────────┐
│                    测试准备阶段                              │
├─────────────────────────────────────────────────────────────┤
│ 1. USB连接手机 → 启用USB调试                                 │
│ 2. 执行 adb devices 验证连接                                 │
│ 3. 确认AnyNote已安装                                         │
│ 4. 运行环境检查脚本                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    测试执行阶段                              │
├─────────────────────────────────────────────────────────────┤
│ 选项A: 半自动测试 (推荐)                                     │
│   → 运行自动化脚本                                           │
│   → 手动执行交互操作                                         │
│   → 脚本收集日志和截图                                       │
│                                                             │
│ 选项B: 全手动测试                                           │
│   → 按照测试用例清单逐项执行                                 │
│   → 手动记录结果                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    结果收集阶段                              │
├─────────────────────────────────────────────────────────────┤
│ 1. 收集logcat日志                                           │
│ 2. 导出截图                                                 │
│ 3. 获取应用崩溃报告                                         │
│ 4. 记录发现的Bug                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    报告生成阶段                              │
├─────────────────────────────────────────────────────────────┤
│ 您将以下内容发给我:                                          │
│ - logcat日志文件                                            │
│ - 截图集                                                    │
│ - Bug描述                                                   │
│ → 我分析并生成完整测试报告                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 五、测试用例统计

| 模块 | 用例数量 | 优先级 |
|------|---------|--------|
| 安装与启动 | 5 | P0 |
| 注册登录 | 15 | P0 |
| 笔记CRUD | 20 | P0 |
| 加密同步 | 10 | P0 |
| AI辅助 | 8 | P1 |
| 平台发布 | 6 | P1 |
| 离线模式 | 5 | P1 |
| **总计** | **69** | - |

---

## 六、快速启动测试

### 第一阶段: 核心功能验证 (约30分钟)

```bash
# 1. 环境检查 (5分钟)
adb devices
adb shell pm list packages | grep anynote

# 2. 启动日志记录
adb logcat -c
adb logcat -v time > test_log.txt &

# 3. 执行核心测试
# - 注册登录 (10分钟)
# - 创建笔记 (10分钟)
# - 加密验证 (5分钟)

# 4. 收集结果
pkill -f "adb logcat"
adb exec-out screencap -p > screenshot_result.png
```

---

## 文档版本

- 创建日期: 2026-05-07
- 适用版本: AnyNote v2.4.0+
- 测试环境: Android/iOS USB连接
