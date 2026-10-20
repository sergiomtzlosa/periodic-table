//
//  PTElectronShellView.m
//  PeriodicTable
//

#import "PTElectronShellView.h"

@implementation PTElectronShellView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (!self) { return nil; }
    _shells = @[];
    _shellColor = [NSColor colorWithWhite:1.0 alpha:0.30];
    _electronColor = [NSColor colorWithSRGBRed:0.45 green:0.80 blue:1.0 alpha:1.0];
    _nucleusColor = [NSColor colorWithSRGBRed:1.0 green:0.45 blue:0.40 alpha:1.0];
    return self;
}

- (void)setShells:(NSArray<NSNumber *> *)shells {
    if (_shells == shells) { return; }
    _shells = [shells copy];
    [self setNeedsDisplay:YES];
}

- (void)setShellColor:(NSColor *)shellColor { _shellColor = shellColor; [self setNeedsDisplay:YES]; }
- (void)setElectronColor:(NSColor *)electronColor { _electronColor = electronColor; [self setNeedsDisplay:YES]; }
- (void)setNucleusColor:(NSColor *)nucleusColor { _nucleusColor = nucleusColor; [self setNeedsDisplay:YES]; }

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = self.bounds;
    CGFloat side = MIN(NSWidth(bounds), NSHeight(bounds));
    if (side <= 4.0) { return; }

    CGPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    NSUInteger shellCount = self.shells.count;
    if (shellCount == 0) {
        // Empty state: a small dim nucleus.
        NSBezierPath *nucleus = [NSBezierPath bezierPathWithOvalInRect:
            NSMakeRect(center.x - 3, center.y - 3, 6, 6)];
        [[self.nucleusColor colorWithAlphaComponent:0.6] set];
        [nucleus fill];
        return;
    }

    CGFloat maxRadius = side / 2.0 - 4.0;
    CGFloat minRadius = MAX(4.0, maxRadius * 0.16);
    CGFloat step = shellCount > 1 ? (maxRadius - minRadius) / (double)(shellCount - 1) : 0.0;

    // Shell circles.
    for (NSUInteger i = 0; i < shellCount; i++) {
        CGFloat radius = minRadius + step * (CGFloat)i;
        NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:
            NSMakeRect(center.x - radius, center.y - radius, radius * 2, radius * 2)];
        circle.lineWidth = 1.0;
        [self.shellColor set];
        [circle stroke];
    }

    // Electrons.
    for (NSUInteger i = 0; i < shellCount; i++) {
        NSUInteger electronCount = self.shells[i].unsignedIntegerValue;
        if (electronCount == 0) { continue; }

        CGFloat radius = minRadius + step * (CGFloat)i;
        CGFloat dotRadius = MAX(1.8, side * 0.035);
        for (NSUInteger e = 0; e < electronCount; e++) {
            double angle = -M_PI_2 + 2.0 * M_PI * (double)e / (double)electronCount;
            CGFloat x = center.x + radius * cos(angle);
            CGFloat y = center.y + radius * sin(angle);
            NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:
                NSMakeRect(x - dotRadius, y - dotRadius, dotRadius * 2, dotRadius * 2)];
            [self.electronColor set];
            [dot fill];
        }
    }

    // Nucleus.
    CGFloat nucleusRadius = MAX(3.0, minRadius * 0.55);
    NSBezierPath *nucleus = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(center.x - nucleusRadius, center.y - nucleusRadius, nucleusRadius * 2, nucleusRadius * 2)];
    [self.nucleusColor set];
    [nucleus fill];
}

@end
