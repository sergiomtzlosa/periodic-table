//
//  PTElementCategories.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PTElementCategory) {
    PTElementCategoryAlkaliMetal = 0,
    PTElementCategoryAlkalineEarthMetal,
    PTElementCategoryTransitionMetal,
    PTElementCategoryPostTransitionMetal,
    PTElementCategoryMetalloid,
    PTElementCategoryReactiveNonmetal,
    PTElementCategoryHalogen,
    PTElementCategoryNobleGas,
    PTElementCategoryLanthanide,
    PTElementCategoryActinide,
    PTElementCategoryUnknown,
};

@interface PTElementCategories : NSObject

/// Human readable category name, e.g. "Transition metal".
+ (NSString *)nameForCategory:(PTElementCategory)category;

/// Short badge label, e.g. "Tr".
+ (NSString *)shortNameForCategory:(PTElementCategory)category;

/// The category's signature colour, shared by the table tiles, legend and 3D atoms.
+ (NSColor *)colorForCategory:(PTElementCategory)category;

/// Maps a JSON category string to the enum. Returns PTElementCategoryUnknown for junk.
+ (PTElementCategory)categoryFromString:(nullable NSString *)string;

/// Every category in display order, for the legend.
+ (NSArray<NSNumber *> *)allCategories;

@end

NS_ASSUME_NONNULL_END
