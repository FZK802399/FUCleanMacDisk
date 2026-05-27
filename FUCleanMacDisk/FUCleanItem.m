//
//  FUCleanItem.m
//  FUCleanMacDisk
//

#import "FUCleanItem.h"

@implementation FUCleanItem

+ (instancetype)itemWithTitle:(NSString *)title
                       detail:(NSString *)detail
                        paths:(NSArray<NSString *> *)paths
                       safety:(FUSafetyLevel)safety
                       method:(FUCleanMethod)method {
    FUCleanItem *item = [[FUCleanItem alloc] init];
    item.title = title;
    item.detail = detail;
    item.paths = paths ?: @[];
    item.safety = safety;
    item.method = method;
    item.selected = (safety == FUSafetyLevelSafe); // safe items pre-checked
    return item;
}

- (NSString *)safetyLabel {
    switch (self.safety) {
        case FUSafetyLevelSafe:    return @"安全";
        case FUSafetyLevelMedium:  return @"可重建";
        case FUSafetyLevelCaution: return @"谨慎";
    }
    return @"";
}

@end
