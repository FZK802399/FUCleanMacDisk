//
//  FUCleanItem.h
//  FUCleanMacDisk
//
//  Model describing one cleanable entry (a junk category, a simulator
//  runtime, or a large file).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// How risky removing this item is, used for color coding and defaults.
typedef NS_ENUM(NSInteger, FUSafetyLevel) {
    FUSafetyLevelSafe = 0,   // regenerable caches; selected by default
    FUSafetyLevelMedium,     // slow to regenerate / device data
    FUSafetyLevelCaution,    // user data or emulators; never auto-selected
};

/// How the item is removed.
typedef NS_ENUM(NSInteger, FUCleanMethod) {
    FUCleanMethodRemoveContents = 0, // delete children of each path, keep the dir
    FUCleanMethodRemoveItem,         // delete the paths themselves
    FUCleanMethodTrash,              // move paths to Trash (recoverable)
    FUCleanMethodSimctlRuntime,      // xcrun simctl runtime delete <identifier>
    FUCleanMethodSimctlUnavailable,  // xcrun simctl delete unavailable
    FUCleanMethodBrewCleanup,        // brew cleanup
};

@interface FUCleanItem : NSObject

@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *detail;       // human explanation
@property (nonatomic, copy)   NSArray<NSString *> *paths; // absolute paths involved
@property (nonatomic, assign) long long sizeBytes;
@property (nonatomic, assign) FUSafetyLevel safety;
@property (nonatomic, assign) FUCleanMethod method;
@property (nonatomic, copy, nullable) NSString *commandArgument; // e.g. runtime identifier
@property (nonatomic, assign) BOOL selected;

/// Localized one-word safety label.
@property (nonatomic, readonly) NSString *safetyLabel;

+ (instancetype)itemWithTitle:(NSString *)title
                       detail:(NSString *)detail
                        paths:(NSArray<NSString *> *)paths
                       safety:(FUSafetyLevel)safety
                       method:(FUCleanMethod)method;

@end

NS_ASSUME_NONNULL_END
