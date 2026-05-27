//
//  FUCleaner.m
//  FUCleanMacDisk
//

#import "FUCleaner.h"
#import "FUShell.h"

@implementation FUCleaner

- (long long)cleanItems:(NSArray<FUCleanItem *> *)items
                    log:(NSMutableArray<NSString *> *)log {
    long long before = [FUShell freeDiskBytes];

    for (FUCleanItem *item in items) {
        NSString *result = [self cleanOne:item];
        if (log) { [log addObject:[NSString stringWithFormat:@"%@ — %@", item.title, result]]; }
    }

    long long after = [FUShell freeDiskBytes];
    return MAX(0, after - before);
}

- (NSString *)cleanOne:(FUCleanItem *)item {
    switch (item.method) {
        case FUCleanMethodRemoveContents: return [self removeContentsOfPaths:item.paths];
        case FUCleanMethodRemoveItem:     return [self removeItems:item.paths];
        case FUCleanMethodTrash:          return [self trashPaths:item.paths];
        case FUCleanMethodSimctlRuntime:  return [self deleteRuntime:item.commandArgument];
        case FUCleanMethodSimctlUnavailable: return [self deleteUnavailableSimulators];
        case FUCleanMethodBrewCleanup:    return [self brewCleanup];
    }
    return @"未知操作";
}

#pragma mark - File operations

/// Delete each child of every path, keeping the parent directory. Skips
/// entries that can't be removed (e.g. SIP-protected) instead of failing.
- (NSString *)removeContentsOfPaths:(NSArray<NSString *> *)paths {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUInteger removed = 0, skipped = 0;
    for (NSString *dir in paths) {
        NSArray<NSString *> *children = [fm contentsOfDirectoryAtPath:dir error:NULL];
        for (NSString *name in children) {
            NSString *child = [dir stringByAppendingPathComponent:name];
            if ([fm removeItemAtPath:child error:NULL]) { removed++; }
            else { skipped++; }
        }
    }
    if (skipped > 0) {
        return [NSString stringWithFormat:@"已清 %lu 项，跳过 %lu 项(受保护)",
                (unsigned long)removed, (unsigned long)skipped];
    }
    return [NSString stringWithFormat:@"已清 %lu 项", (unsigned long)removed];
}

- (NSString *)removeItems:(NSArray<NSString *> *)paths {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUInteger removed = 0, skipped = 0;
    for (NSString *p in paths) {
        if (![fm fileExistsAtPath:p]) { continue; }
        if ([fm removeItemAtPath:p error:NULL]) { removed++; }
        else { skipped++; }
    }
    if (skipped > 0) {
        return [NSString stringWithFormat:@"已删 %lu 项，失败 %lu 项",
                (unsigned long)removed, (unsigned long)skipped];
    }
    return [NSString stringWithFormat:@"已删 %lu 项", (unsigned long)removed];
}

- (NSString *)trashPaths:(NSArray<NSString *> *)paths {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUInteger moved = 0;
    for (NSString *p in paths) {
        NSURL *url = [NSURL fileURLWithPath:p];
        if ([fm trashItemAtURL:url resultingItemURL:NULL error:NULL]) { moved++; }
    }
    return [NSString stringWithFormat:@"已移到废纸篓 %lu 项(可恢复)", (unsigned long)moved];
}

#pragma mark - simctl / brew

- (NSString *)deleteRuntime:(NSString *)identifier {
    if (identifier.length == 0) { return @"缺少运行时标识"; }
    [FUShell run:@"/usr/bin/xcrun" arguments:@[@"simctl", @"runtime", @"delete", identifier]];
    return @"已请求删除(后台异步释放空间)";
}

- (NSString *)deleteUnavailableSimulators {
    [FUShell run:@"/usr/bin/xcrun" arguments:@[@"simctl", @"delete", @"unavailable"]];
    return @"已删除失效模拟器";
}

- (NSString *)brewCleanup {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *brew = nil;
    for (NSString *p in @[@"/opt/homebrew/bin/brew", @"/usr/local/bin/brew"]) {
        if ([fm isExecutableFileAtPath:p]) { brew = p; break; }
    }
    if (brew == nil) { return @"未找到 brew"; }
    [FUShell run:brew arguments:@[@"cleanup"]];
    return @"已执行 brew cleanup";
}

@end
