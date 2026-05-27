//
//  FUShell.m
//  FUCleanMacDisk
//

#import "FUShell.h"

@implementation FUShell

+ (NSString *)run:(NSString *)launchPath arguments:(NSArray<NSString *> *)arguments {
    if (launchPath.length == 0) { return @""; }

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:launchPath];
    task.arguments = arguments ?: @[];

    NSPipe *outPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = [NSPipe pipe]; // discard stderr noise

    NSError *error = nil;
    @try {
        if (![task launchAndReturnError:&error]) {
            return @"";
        }
        NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSString *out = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        return [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } @catch (NSException *exception) {
        return @"";
    }
}

+ (long long)sizeOfPathInBytes:(NSString *)path {
    if (path.length == 0) { return 0; }
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) { return 0; }

    // `du -sk` reports size in 1024-byte blocks. Robust for huge trees.
    NSString *out = [self run:@"/usr/bin/du" arguments:@[@"-sk", path]];
    if (out.length == 0) { return 0; }
    NSString *first = [[out componentsSeparatedByCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]] firstObject];
    long long kb = [first longLongValue];
    return kb * 1024LL;
}

+ (NSDictionary *)attributesForRoot {
    NSError *error = nil;
    return [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/" error:&error] ?: @{};
}

+ (long long)freeDiskBytes {
    NSNumber *free = [self attributesForRoot][NSFileSystemFreeSize];
    return free.longLongValue;
}

+ (long long)totalDiskBytes {
    NSNumber *total = [self attributesForRoot][NSFileSystemSize];
    return total.longLongValue;
}

@end
