# FUCleanMacDisk

A macOS disk cleanup tool (Objective-C / AppKit). It detects large files across the disk, scans for and removes regenerable developer junk/caches, organized around the real-world cleanup workflow of a developer machine. Every deletion requires confirmation.

## Features

The header shows live **Free / Total / Used** disk space with a usage bar. Three tabs:

### 1. Junk Cleanup
Lists reclaimable items grouped by safety level (🟢 Safe / 🟠 Regenerable / 🔴 Caution). Safe items are pre-checked.

| Category | Path | Level |
|----------|------|-------|
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Safe |
| Xcode IB caches | `~/Library/Developer/Xcode/UserData/IB Support` | Safe |
| Xcode documentation cache | `~/Library/Developer/Xcode/DocumentationCache` | Safe |
| Xcode device logs | `~/Library/Developer/Xcode/iOS Device Logs` | Safe |
| User caches | `~/Library/Caches` (SIP-protected entries skipped) | Safe |
| CoreDeviceService cache | `~/Library/Containers/com.apple.CoreDevice.../Caches` | Safe |
| Gradle / npm / SonarLint caches | `~/.gradle`, `~/.npm`, `~/.sonar` | Safe |
| Trash | `~/.Trash` | Safe |
| iOS device support symbols | `~/Library/Developer/Xcode/iOS DeviceSupport` | Regenerable |
| GoogleUpdater cache | `~/Library/Application Support/Google/GoogleUpdater/crx_cache` | Regenerable |
| Unavailable simulators | `simctl delete unavailable` | Regenerable |
| Homebrew old versions | `brew cleanup` | Safe |
| Android emulators | `~/.android/avd` | Caution |
| HarmonyOS / Huawei emulator | `~/.Huawei` | Caution |
| Old Claude versions | `~/.local/share/claude/versions` (keeps latest) | Regenerable |

### 2. Simulator Runtimes
Lists each installed iOS runtime under `/Library/Developer/CoreSimulator` with its on-disk size, and removes them safely via `xcrun simctl runtime delete <id>` (never a manual `rm`, which would corrupt the runtime database).

### 3. Large Files (>500 MB)
Uses `find` to scan the home directory for large files, sorted by size. Double-click to reveal in Finder. When cleaned, files are **moved to the Trash (recoverable)**, since large files are usually user data.

## Safety Design

- A confirmation dialog before deletion lists every item and the estimated space freed.
- Caches are permanently deleted; large files go to the Trash and can be restored.
- When clearing directory contents, SIP-protected entries are skipped instead of aborting.
- After cleanup, the app re-scans and reports the space actually freed.

## Requirements

- macOS 26.1+, Xcode 26+
- **App Sandbox is disabled**: a cleanup tool needs access to `~/Library/Developer`, `/Library/Developer`, and must run `xcrun`, `brew`, etc.
- On first run, grant the app **Full Disk Access** under **System Settings → Privacy & Security → Full Disk Access**, otherwise some directories cannot be scanned or deleted.

## Architecture

| File | Responsibility |
|------|----------------|
| `FUShell` | `NSTask` wrapper for `du` / `find` / `xcrun` / `brew`, plus disk capacity queries |
| `FUCleanItem` | Data model: title, paths, size, safety level, cleanup method |
| `FUScanner` | Scans the three categories (junk / runtimes / large files) |
| `FUCleaner` | Performs deletions, returns bytes freed and a log |
| `ViewController` | Builds the UI programmatically (no Storyboard layout dependency) |
