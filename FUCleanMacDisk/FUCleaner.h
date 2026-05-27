//
//  FUCleaner.h
//  FUCleanMacDisk
//
//  Executes the removal described by FUCleanItem objects.
//

#import <Foundation/Foundation.h>
#import "FUCleanItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface FUCleaner : NSObject

/// Cleans the given items synchronously. `log` receives one human-readable
/// line per item. Returns the number of bytes freed on the data volume
/// (measured as free-space delta). Run this off the main thread.
- (long long)cleanItems:(NSArray<FUCleanItem *> *)items
                    log:(NSMutableArray<NSString *> *)log;

@end

NS_ASSUME_NONNULL_END
