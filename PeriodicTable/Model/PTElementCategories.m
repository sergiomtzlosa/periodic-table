//
//  PTElementCategories.m
//  PeriodicTable
//

#import "PTElementCategories.h"

@implementation PTElementCategories

+ (NSArray<NSNumber *> *)allCategories {
    static NSArray *categories = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        categories = @[
            @(PTElementCategoryReactiveNonmetal),
            @(PTElementCategoryNobleGas),
            @(PTElementCategoryHalogen),
            @(PTElementCategoryAlkaliMetal),
            @(PTElementCategoryAlkalineEarthMetal),
            @(PTElementCategoryMetalloid),
            @(PTElementCategoryTransitionMetal),
            @(PTElementCategoryPostTransitionMetal),
            @(PTElementCategoryLanthanide),
            @(PTElementCategoryActinide),
            @(PTElementCategoryUnknown),
        ];
    });
    return categories;
}

+ (PTElementCategory)categoryFromString:(nullable NSString *)string {
    if (string.length == 0) { return PTElementCategoryUnknown; }

    static NSDictionary<NSString *, NSNumber *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"alkali-metal":           @(PTElementCategoryAlkaliMetal),
            @"alkaline-earth-metal":   @(PTElementCategoryAlkalineEarthMetal),
            @"transition-metal":       @(PTElementCategoryTransitionMetal),
            @"post-transition-metal":  @(PTElementCategoryPostTransitionMetal),
            @"metalloid":              @(PTElementCategoryMetalloid),
            @"reactive-nonmetal":      @(PTElementCategoryReactiveNonmetal),
            @"halogen":                @(PTElementCategoryHalogen),
            @"noble-gas":              @(PTElementCategoryNobleGas),
            @"lanthanide":             @(PTElementCategoryLanthanide),
            @"actinide":               @(PTElementCategoryActinide),
            @"unknown":                @(PTElementCategoryUnknown),
        };
    });

    NSNumber *value = map[string];
    return value ? (PTElementCategory)value.integerValue : PTElementCategoryUnknown;
}

+ (NSString *)nameForCategory:(PTElementCategory)category {
    switch (category) {
        case PTElementCategoryAlkaliMetal:          return @"Alkali metal";
        case PTElementCategoryAlkalineEarthMetal:   return @"Alkaline earth metal";
        case PTElementCategoryTransitionMetal:      return @"Transition metal";
        case PTElementCategoryPostTransitionMetal: return @"Post-transition metal";
        case PTElementCategoryMetalloid:            return @"Metalloid";
        case PTElementCategoryReactiveNonmetal:     return @"Reactive nonmetal";
        case PTElementCategoryHalogen:              return @"Halogen";
        case PTElementCategoryNobleGas:             return @"Noble gas";
        case PTElementCategoryLanthanide:           return @"Lanthanide";
        case PTElementCategoryActinide:             return @"Actinide";
        case PTElementCategoryUnknown:              return @"Unknown";
    }
    return @"Unknown";
}

+ (NSString *)shortNameForCategory:(PTElementCategory)category {
    switch (category) {
        case PTElementCategoryAlkaliMetal:          return @"Alk";
        case PTElementCategoryAlkalineEarthMetal:   return @"A.E.";
        case PTElementCategoryTransitionMetal:      return @"Trans";
        case PTElementCategoryPostTransitionMetal: return @"P-Trans";
        case PTElementCategoryMetalloid:            return @"Met";
        case PTElementCategoryReactiveNonmetal:     return @"Non-Met";
        case PTElementCategoryHalogen:              return @"Hal";
        case PTElementCategoryNobleGas:             return @"Noble";
        case PTElementCategoryLanthanide:           return @"Lanth";
        case PTElementCategoryActinide:             return @"Act";
        case PTElementCategoryUnknown:              return @"Unk";
    }
    return @"Unk";
}

+ (NSColor *)colorForCategory:(PTElementCategory)category {
    switch (category) {
        case PTElementCategoryAlkaliMetal:          return [NSColor colorWithSRGBRed:0.98 green:0.42 blue:0.42 alpha:1.0];
        case PTElementCategoryAlkalineEarthMetal:   return [NSColor colorWithSRGBRed:0.99 green:0.76 blue:0.35 alpha:1.0];
        case PTElementCategoryTransitionMetal:      return [NSColor colorWithSRGBRed:0.95 green:0.60 blue:0.60 alpha:1.0];
        case PTElementCategoryPostTransitionMetal: return [NSColor colorWithSRGBRed:0.78 green:0.80 blue:0.83 alpha:1.0];
        case PTElementCategoryMetalloid:            return [NSColor colorWithSRGBRed:0.63 green:0.86 blue:0.55 alpha:1.0];
        case PTElementCategoryReactiveNonmetal:     return [NSColor colorWithSRGBRed:0.44 green:0.78 blue:0.89 alpha:1.0];
        case PTElementCategoryHalogen:              return [NSColor colorWithSRGBRed:0.76 green:0.92 blue:0.35 alpha:1.0];
        case PTElementCategoryNobleGas:             return [NSColor colorWithSRGBRed:0.45 green:0.85 blue:0.60 alpha:1.0];
        case PTElementCategoryLanthanide:           return [NSColor colorWithSRGBRed:0.85 green:0.58 blue:0.95 alpha:1.0];
        case PTElementCategoryActinide:             return [NSColor colorWithSRGBRed:0.96 green:0.52 blue:0.72 alpha:1.0];
        case PTElementCategoryUnknown:              return [NSColor colorWithSRGBRed:0.55 green:0.55 blue:0.58 alpha:1.0];
    }
    return [NSColor grayColor];
}

@end
