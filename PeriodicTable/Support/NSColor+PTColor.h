//
//  NSColor+PTColor.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (PTColor)

/// Parses "#RRGGBB", "RRGGBB" or "#RRGGBBAA" into a colour. Returns nil when unparsable.
+ (nullable NSColor *)pt_colorWithHexString:(NSString *)hex;

/// A colour with the given components in the 0...1 range.
+ (NSColor *)pt_colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue;

/// Brightens (amount > 0) or darkens (amount < 0) a colour in HSB space.
- (NSColor *)pt_colorAdjustedByBrightness:(CGFloat)amount;

@end

NS_ASSUME_NONNULL_END
