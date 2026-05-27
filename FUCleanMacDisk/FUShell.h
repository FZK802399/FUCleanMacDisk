//
//  FUShell.h
//  FUCleanMacDisk
//
//  Runs external commands (du / find / xcrun / brew) via NSTask.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FUShell : NSObject

/// Runs a tool with arguments synchronously and returns stdout (trimmed).
/// Returns @"" on failure. Never throws.
+ (NSString *)run:(NSString *)launchPath arguments:(NSArray<NSString *> *)arguments;

/// Convenience: directory/file size in bytes using `du -sk`. 0 if missing.
+ (long long)sizeOfPathInBytes:(NSString *)path;

/// Available bytes on the data volume ("/").
+ (long long)freeDiskBytes;

/// Total / used bytes on the data volume ("/").
+ (long long)totalDiskBytes;

@end

NS_ASSUME_NONNULL_END
