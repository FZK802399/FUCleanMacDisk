//
//  FUScanner.h
//  FUCleanMacDisk
//
//  Scans the machine for reclaimable space following the manual cleanup
//  workflow: developer caches, simulator runtimes, and large files.
//

#import <Foundation/Foundation.h>
#import "FUCleanItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface FUScanner : NSObject

/// Junk categories (Xcode caches, dev tool caches, trash, emulators, ...).
/// Only entries that actually occupy space are returned. Synchronous.
- (NSArray<FUCleanItem *> *)scanJunkCategories;

/// Installed iOS simulator runtimes under /Library/Developer/CoreSimulator,
/// one item each with its on-disk size. Synchronous.
- (NSArray<FUCleanItem *> *)scanSimulatorRuntimes;

/// Files under the home directory larger than minBytes, sorted descending.
/// Synchronous; may take a while on large disks.
- (NSArray<FUCleanItem *> *)scanLargeFilesWithMinBytes:(long long)minBytes;

@end

NS_ASSUME_NONNULL_END
