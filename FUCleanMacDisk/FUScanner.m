//
//  FUScanner.m
//  FUCleanMacDisk
//

#import "FUScanner.h"
#import "FUShell.h"

@implementation FUScanner

#pragma mark - Helpers

- (NSString *)home {
    return NSHomeDirectory();
}

- (NSString *)home:(NSString *)relative {
    return [[self home] stringByAppendingPathComponent:relative];
}

/// Total size of the given paths that actually exist.
- (long long)sizeOfPaths:(NSArray<NSString *> *)paths existing:(NSMutableArray<NSString *> *)existing {
    long long total = 0;
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in paths) {
        if ([fm fileExistsAtPath:p]) {
            long long s = [FUShell sizeOfPathInBytes:p];
            if (s > 0) {
                total += s;
                [existing addObject:p];
            }
        }
    }
    return total;
}

/// Builds an item only if its paths occupy space; returns nil otherwise.
- (FUCleanItem *)itemWithTitle:(NSString *)title
                        detail:(NSString *)detail
                     candidate:(NSArray<NSString *> *)candidatePaths
                        safety:(FUSafetyLevel)safety
                        method:(FUCleanMethod)method {
    NSMutableArray<NSString *> *existing = [NSMutableArray array];
    long long size = [self sizeOfPaths:candidatePaths existing:existing];
    if (size <= 0 || existing.count == 0) { return nil; }

    FUCleanItem *item = [FUCleanItem itemWithTitle:title detail:detail
                                             paths:existing safety:safety method:method];
    item.sizeBytes = size;
    return item;
}

#pragma mark - Junk categories

- (NSArray<FUCleanItem *> *)scanJunkCategories {
    NSMutableArray<FUCleanItem *> *items = [NSMutableArray array];

    void (^add)(FUCleanItem *) = ^(FUCleanItem *it) { if (it) { [items addObject:it]; } };

    // --- Xcode user caches (Safe) ---
    add([self itemWithTitle:@"Xcode DerivedData"
                     detail:@"编译中间产物，下次构建自动重建"
                  candidate:@[[self home:@"Library/Developer/Xcode/DerivedData"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveContents]);

    add([self itemWithTitle:@"Xcode Interface Builder 缓存"
                     detail:@"IB Support 缓存，自动重建"
                  candidate:@[[self home:@"Library/Developer/Xcode/UserData/IB Support"],
                              [self home:@"Library/Developer/Xcode/UserData/IB%20Support"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveItem]);

    add([self itemWithTitle:@"Xcode 文档缓存"
                     detail:@"DocumentationCache，自动重建"
                  candidate:@[[self home:@"Library/Developer/Xcode/DocumentationCache"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveContents]);

    add([self itemWithTitle:@"Xcode 设备日志"
                     detail:@"iOS Device Logs / DeviceLogs"
                  candidate:@[[self home:@"Library/Developer/Xcode/iOS Device Logs"],
                              [self home:@"Library/Developer/Xcode/DeviceLogs"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveContents]);

    // --- System / app caches (Safe) ---
    add([self itemWithTitle:@"用户缓存 (~/Library/Caches)"
                     detail:@"各类应用缓存，系统保护项会自动跳过"
                  candidate:@[[self home:@"Library/Caches"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveContents]);

    add([self itemWithTitle:@"CoreDeviceService 缓存"
                     detail:@"设备服务缓存，自动重建"
                  candidate:@[[self home:@"Library/Containers/com.apple.CoreDevice.CoreDeviceService/Data/Library/Caches"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveContents]);

    // --- Dev tool caches outside ~/Library/Caches (Safe) ---
    add([self itemWithTitle:@"Gradle 缓存"
                     detail:@"~/.gradle/caches、daemon，下次构建重建"
                  candidate:@[[self home:@".gradle/caches"], [self home:@".gradle/daemon"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveItem]);

    add([self itemWithTitle:@"npm 缓存"
                     detail:@"~/.npm/_cacache、_logs"
                  candidate:@[[self home:@".npm/_cacache"], [self home:@".npm/_logs"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveItem]);

    add([self itemWithTitle:@"SonarLint 缓存"
                     detail:@"~/.sonar 分析缓存，可再生"
                  candidate:@[[self home:@".sonar/cache"], [self home:@".sonar/js"], [self home:@".sonar/_tmp"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveItem]);

    // --- Trash (Safe) ---
    add([self itemWithTitle:@"废纸篓"
                     detail:@"清空 ~/.Trash"
                  candidate:@[[self home:@".Trash"]]
                     safety:FUSafetyLevelSafe method:FUCleanMethodRemoveContents]);

    // --- Medium ---
    add([self itemWithTitle:@"Xcode iOS 真机调试符号"
                     detail:@"iOS DeviceSupport，下次连真机会重新下载"
                  candidate:@[[self home:@"Library/Developer/Xcode/iOS DeviceSupport"]]
                     safety:FUSafetyLevelMedium method:FUCleanMethodRemoveContents]);

    add([self itemWithTitle:@"GoogleUpdater 缓存"
                     detail:@"Chrome 更新器下载缓存，可再生"
                  candidate:@[[self home:@"Library/Application Support/Google/GoogleUpdater/crx_cache"]]
                     safety:FUSafetyLevelMedium method:FUCleanMethodRemoveContents]);

    FUCleanItem *unavailable = [self unavailableSimulatorsItem];
    add(unavailable);

    FUCleanItem *brew = [self brewCleanupItem];
    add(brew);

    // --- Caution: emulators & user-ish data ---
    add([self itemWithTitle:@"Android 模拟器 (AVD)"
                     detail:@"~/.android/avd，删除后需重新创建"
                  candidate:@[[self home:@".android/avd"]]
                     safety:FUSafetyLevelCaution method:FUCleanMethodRemoveContents]);

    add([self itemWithTitle:@"鸿蒙/华为模拟器"
                     detail:@"~/.Huawei，删除后需重新安装"
                  candidate:@[[self home:@".Huawei"]]
                     safety:FUSafetyLevelCaution method:FUCleanMethodRemoveItem]);

    FUCleanItem *claude = [self oldClaudeVersionsItem];
    add(claude);

    // Sort: largest first within the displayed list.
    [items sortUsingComparator:^NSComparisonResult(FUCleanItem *a, FUCleanItem *b) {
        if (a.sizeBytes == b.sizeBytes) { return NSOrderedSame; }
        return a.sizeBytes > b.sizeBytes ? NSOrderedAscending : NSOrderedDescending;
    }];
    return items;
}

#pragma mark - Unavailable simulators

- (FUCleanItem *)unavailableSimulatorsItem {
    NSDictionary *root = [self simctlListJSON];
    NSDictionary *devicesByRuntime = root[@"devices"];
    if (![devicesByRuntime isKindOfClass:[NSDictionary class]]) { return nil; }

    NSString *devicesDir = [self home:@"Library/Developer/CoreSimulator/Devices"];
    long long total = 0;
    NSInteger count = 0;
    for (NSArray *list in devicesByRuntime.allValues) {
        if (![list isKindOfClass:[NSArray class]]) { continue; }
        for (NSDictionary *dev in list) {
            BOOL available = [dev[@"isAvailable"] boolValue];
            if (available) { continue; }
            NSString *udid = dev[@"udid"];
            if (udid.length == 0) { continue; }
            NSString *path = [devicesDir stringByAppendingPathComponent:udid];
            total += [FUShell sizeOfPathInBytes:path];
            count++;
        }
    }
    if (count == 0) { return nil; }

    FUCleanItem *item = [FUCleanItem itemWithTitle:
                         [NSString stringWithFormat:@"失效的模拟器 (%ld 个)", (long)count]
                                            detail:@"运行时已不存在的模拟器，simctl delete unavailable"
                                             paths:@[devicesDir]
                                            safety:FUSafetyLevelMedium
                                            method:FUCleanMethodSimctlUnavailable];
    item.sizeBytes = total;
    return item;
}

#pragma mark - Homebrew

- (FUCleanItem *)brewCleanupItem {
    NSString *brew = [self brewPath];
    if (brew == nil) { return nil; }

    NSString *out = [FUShell run:brew arguments:@[@"cleanup", @"-n"]];
    if (out.length == 0) { return nil; }

    // Parse "would free approximately 79.3MB of disk space."
    long long bytes = 0;
    NSRange r = [out rangeOfString:@"approximately "];
    if (r.location != NSNotFound) {
        NSString *tail = [out substringFromIndex:NSMaxRange(r)];
        bytes = [self bytesFromBrewSizeString:tail];
    }
    if (bytes <= 0) { return nil; }

    FUCleanItem *item = [FUCleanItem itemWithTitle:@"Homebrew 旧版本"
                                            detail:@"brew cleanup：清除过期下载与旧版本"
                                             paths:@[]
                                            safety:FUSafetyLevelSafe
                                            method:FUCleanMethodBrewCleanup];
    item.sizeBytes = bytes;
    return item;
}

- (long long)bytesFromBrewSizeString:(NSString *)s {
    NSScanner *scanner = [NSScanner scannerWithString:s];
    double value = 0;
    if (![scanner scanDouble:&value]) { return 0; }
    NSString *unit = [[s substringFromIndex:scanner.scanLocation]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    unit = unit.uppercaseString;
    double mult = 1;
    if ([unit hasPrefix:@"KB"]) { mult = 1024; }
    else if ([unit hasPrefix:@"MB"]) { mult = 1024.0 * 1024; }
    else if ([unit hasPrefix:@"GB"]) { mult = 1024.0 * 1024 * 1024; }
    else if ([unit hasPrefix:@"TB"]) { mult = 1024.0 * 1024 * 1024 * 1024; }
    return (long long)(value * mult);
}

- (NSString *)brewPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in @[@"/opt/homebrew/bin/brew", @"/usr/local/bin/brew"]) {
        if ([fm isExecutableFileAtPath:p]) { return p; }
    }
    return nil;
}

#pragma mark - Old Claude versions

- (FUCleanItem *)oldClaudeVersionsItem {
    NSString *versionsDir = [self home:@".local/share/claude/versions"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:versionsDir error:NULL];
    if (entries.count < 2) { return nil; }

    // Keep the highest semantic version; collect the rest.
    NSArray<NSString *> *sorted = [entries sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b options:NSNumericSearch];
    }];
    NSString *keep = sorted.lastObject;

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSString *name in sorted) {
        if ([name isEqualToString:keep]) { continue; }
        [paths addObject:[versionsDir stringByAppendingPathComponent:name]];
    }
    if (paths.count == 0) { return nil; }

    return [self itemWithTitle:@"Claude 旧版本"
                        detail:[NSString stringWithFormat:@"保留 %@，删除其余旧版本", keep]
                     candidate:paths
                        safety:FUSafetyLevelMedium
                        method:FUCleanMethodRemoveItem];
}

#pragma mark - Simulator runtimes

- (NSArray<FUCleanItem *> *)scanSimulatorRuntimes {
    NSDictionary *root = [self simctlListJSON];
    NSArray *runtimes = root[@"runtimes"];
    if (![runtimes isKindOfClass:[NSArray class]]) { return @[]; }

    NSString *volumesDir = @"/Library/Developer/CoreSimulator/Volumes";
    NSMutableArray<FUCleanItem *> *items = [NSMutableArray array];

    for (NSDictionary *rt in runtimes) {
        NSString *identifier = rt[@"identifier"];
        NSString *name = rt[@"name"] ?: @"模拟器运行时";
        NSString *build = rt[@"buildversion"] ?: rt[@"buildVersion"];
        if (identifier.length == 0) { continue; }

        long long size = 0;
        if (build.length > 0) {
            NSString *vol = [volumesDir stringByAppendingPathComponent:
                             [@"iOS_" stringByAppendingString:build]];
            size = [FUShell sizeOfPathInBytes:vol];
        }

        FUCleanItem *item = [FUCleanItem itemWithTitle:name
                                                detail:[NSString stringWithFormat:@"%@  (%@)",
                                                        identifier, build ?: @"-"]
                                                 paths:@[]
                                                safety:FUSafetyLevelCaution
                                                method:FUCleanMethodSimctlRuntime];
        item.commandArgument = identifier;
        item.sizeBytes = size;
        [items addObject:item];
    }

    [items sortUsingComparator:^NSComparisonResult(FUCleanItem *a, FUCleanItem *b) {
        if (a.sizeBytes == b.sizeBytes) { return NSOrderedSame; }
        return a.sizeBytes > b.sizeBytes ? NSOrderedAscending : NSOrderedDescending;
    }];
    return items;
}

- (NSDictionary *)simctlListJSON {
    NSString *out = [FUShell run:@"/usr/bin/xcrun" arguments:@[@"simctl", @"list", @"-j"]];
    if (out.length == 0) { return @{}; }
    NSData *data = [out dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [json isKindOfClass:[NSDictionary class]] ? json : @{};
}

#pragma mark - Large files

- (NSArray<FUCleanItem *> *)scanLargeFilesWithMinBytes:(long long)minBytes {
    long long minMB = MAX(1, minBytes / (1024 * 1024));
    NSString *sizeArg = [NSString stringWithFormat:@"+%lldM", minMB];

    // find <home> -type f -size +NM  (errors silenced inside FUShell)
    NSString *out = [FUShell run:@"/usr/bin/find"
                       arguments:@[[self home], @"-type", @"f", @"-size", sizeArg]];
    if (out.length == 0) { return @[]; }

    NSArray<NSString *> *lines = [out componentsSeparatedByString:@"\n"];
    NSMutableArray<FUCleanItem *> *items = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *path in lines) {
        if (path.length == 0) { continue; }
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:NULL];
        long long size = [attrs[NSFileSize] longLongValue];
        if (size < minBytes) { continue; }

        FUCleanItem *item = [FUCleanItem itemWithTitle:path.lastPathComponent
                                                detail:path
                                                 paths:@[path]
                                                safety:FUSafetyLevelCaution
                                                method:FUCleanMethodTrash];
        item.sizeBytes = size;
        [items addObject:item];
    }

    [items sortUsingComparator:^NSComparisonResult(FUCleanItem *a, FUCleanItem *b) {
        if (a.sizeBytes == b.sizeBytes) { return NSOrderedSame; }
        return a.sizeBytes > b.sizeBytes ? NSOrderedAscending : NSOrderedDescending;
    }];
    return items;
}

@end
