//
//  PTElement.m
//  PeriodicTable
//

#import "PTElement.h"

@implementation PTElement

- (NSColor *)categoryColor {
    return [PTElementCategories colorForCategory:self.category];
}

- (NSString *)groupPeriodDescription {
    if (self.isFBlock) {
        return [NSString stringWithFormat:@"F-block · Period %ld", (long)self.period];
    }
    return [NSString stringWithFormat:@"Group %ld · Period %ld", (long)self.group, (long)self.period];
}

- (double)covalentRadiusInAngstrom {
    if (self.covalentRadius != nil) {
        return self.covalentRadius.doubleValue / 100.0;
    }
    // Fall back to a radius that grows gently with the atomic number so the
    // 3D view still looks sensible for the superheavy elements.
    return 0.60 + 0.012 * (double)self.atomicNumber;
}

- (BOOL)isMetal {
    switch (self.category) {
        case PTElementCategoryAlkaliMetal:
        case PTElementCategoryAlkalineEarthMetal:
        case PTElementCategoryTransitionMetal:
        case PTElementCategoryPostTransitionMetal:
        case PTElementCategoryLanthanide:
        case PTElementCategoryActinide:
            return YES;
        default:
            return NO;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PTElement %@ (%@)>", self.symbol, self.name];
}

@end
