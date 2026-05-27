# FUCleanMacDisk

一个 macOS 磁盘清理工具（Objective-C / AppKit）。全局检测大文件、扫描并清除可再生的垃圾/缓存，按照开发者机器的实际清理流程组织。

## 功能

顶部实时显示磁盘 **可用 / 总量 / 已用** 及占用进度条。三个标签页：

### 1. 垃圾清理
按安全等级（🟢安全 / 🟠可重建 / 🔴谨慎）列出各类可回收项，安全项默认勾选：

| 类别 | 路径 | 等级 |
|------|------|------|
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | 安全 |
| Xcode IB 缓存 | `~/Library/Developer/Xcode/UserData/IB Support` | 安全 |
| Xcode 文档缓存 | `~/Library/Developer/Xcode/DocumentationCache` | 安全 |
| Xcode 设备日志 | `~/Library/Developer/Xcode/iOS Device Logs` | 安全 |
| 用户缓存 | `~/Library/Caches`（自动跳过 SIP 保护项） | 安全 |
| CoreDeviceService 缓存 | `~/Library/Containers/com.apple.CoreDevice.../Caches` | 安全 |
| Gradle / npm / SonarLint 缓存 | `~/.gradle`、`~/.npm`、`~/.sonar` | 安全 |
| 废纸篓 | `~/.Trash` | 安全 |
| iOS 真机调试符号 | `~/Library/Developer/Xcode/iOS DeviceSupport` | 可重建 |
| GoogleUpdater 缓存 | `~/Library/Application Support/Google/GoogleUpdater/crx_cache` | 可重建 |
| 失效的模拟器 | `simctl delete unavailable` | 可重建 |
| Homebrew 旧版本 | `brew cleanup` | 安全 |
| Android 模拟器 | `~/.android/avd` | 谨慎 |
| 鸿蒙/华为模拟器 | `~/.Huawei` | 谨慎 |
| Claude 旧版本 | `~/.local/share/claude/versions`（保留最新） | 可重建 |

### 2. 模拟器运行时
列出 `/Library/Developer/CoreSimulator` 下每个已安装的 iOS 运行时及其体积，通过 `xcrun simctl runtime delete <id>` 安全删除（不手动 `rm`，避免损坏运行时数据库）。

### 3. 大文件（>500MB）
`find` 扫描家目录下的大文件，按大小排序。双击「在 Finder 中显示」。勾选清理时**移动到废纸篓（可恢复）**，因为大文件多为用户数据。

## 安全设计

- 删除前弹出确认对话框，列出每一项与预计释放量。
- 缓存类彻底删除；大文件移到废纸篓可恢复。
- 删除内容时跳过受 SIP 保护的目录，不会失败中断。
- 清理后重新扫描并报告实际释放空间。

## 运行要求

- macOS 26.1+，Xcode 26+
- **已关闭 App Sandbox**：清理工具需访问 `~/Library/Developer`、`/Library/Developer` 并运行 `xcrun`、`brew` 等。
- 首次运行请在 **系统设置 → 隐私与安全性 → 完全磁盘访问权限** 中授权本应用，否则部分目录无法扫描/删除。

## 架构

| 文件 | 职责 |
|------|------|
| `FUShell` | `NSTask` 封装，运行 `du`/`find`/`xcrun`/`brew`，磁盘容量查询 |
| `FUCleanItem` | 数据模型：标题、路径、大小、安全等级、清理方式 |
| `FUScanner` | 扫描三类内容（垃圾分类 / 运行时 / 大文件） |
| `FUCleaner` | 执行删除，返回释放字节数与日志 |
| `ViewController` | 程序化构建 UI（无 Storyboard 布局依赖） |
