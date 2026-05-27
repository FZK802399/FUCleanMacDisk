# FUCleanMacDisk

A macOS disk cleanup tool (Objective-C / AppKit). It detects large files across the disk, scans for and removes regenerable developer junk/caches, organized around the real-world cleanup workflow of a developer machine. Every deletion requires confirmation.

## Features

The header shows live **Free / Total / Used** disk space with a usage bar. Two tabs:

### 1. Simulator Runtimes
Lists each installed iOS runtime under `/Library/Developer/CoreSimulator` with its on-disk size, and removes them safely via `xcrun simctl runtime delete <id>` (never a manual `rm`, which would corrupt the runtime database).

### 2. Large Files (>500 MB)
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
