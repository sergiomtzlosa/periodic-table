//
//  NSColor+PTColor.m
//  PeriodicTable
//

#import "NSColor+PTColor.h"

@implementation NSColor (PTColor)

+ (nullable NSColor *)pt_colorWithHexString:(NSString *)hex {
    if (hex.length == 0) { return nil; }

    NSString *cleaned = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
    if ([cleaned hasPrefix:@"#"]) {
        cleaned = [cleaned substringFromIndex:1];
    }
    if (cleaned.length != 6 && cleaned.length != 8) { return nil; }

    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:cleaned];
    if (![scanner scanHexLongLong:&value]) { return nil; }

    CGFloat red, green, blue, alpha = 1.0;
    if (cleaned.length == 8) {
        red   = ((value >> 24) & 0xFF) / 255.0;
        green = ((value >> 16) & 0xFF) / 255.0;
        blue  = ((value >>  8) & 0xFF) / 255.0;
        alpha = ( value        & 0xFF) / 255.0;
    } else {
        red   = ((value >> 16) & 0xFF) / 255.0;
        green = ((value >>  8) & 0xFF) / 255.0;
        blue  = ( value        & 0xFF) / 255.0;
    }
    return [self pt_colorWithRed:red green:green blue:blue];
}

+ (NSColor *)pt_colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue {
    return [NSColor colorWithSRGBRed:MAX(0.0, MIN(1.0, red))
                               green:MAX(0.0, MIN(1.0, green))
                                blue:MAX(0.0, MIN(1.0, blue))
                               alpha:1.0];
}

- (NSColor *)pt_colorAdjustedByBrightness:(CGFloat)amount {
    NSColor *rgb = [self colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] ?: self;
    CGFloat hue = rgb.hueComponent;
    CGFloat saturation = rgb.saturationComponent;
    CGFloat brightness = rgb.brightnessComponent;
    CGFloat alpha = rgb.alphaComponent;
    brightness = MAX(0.0, MIN(1.0, brightness + amount));
    return [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

@end
