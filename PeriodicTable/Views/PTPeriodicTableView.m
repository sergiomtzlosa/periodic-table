//
//  PTPeriodicTableView.m
//  PeriodicTable
//

#import "PTPeriodicTableView.h"
#import "PTElementCategories.h"
#import "NSColor+PTColor.h"

static const NSInteger PTColumnCount = 18;
static const NSInteger PTPeriodCount = 7;
static const NSInteger PTLanthanideRow = 7;
static const NSInteger PTActinideRow = 8;
static const NSInteger PTRowCount = 9;

static const CGFloat PTSpacing = 3.0;
static const CGFloat PTTopInset = 18.0;      // group-number ruler
static const CGFloat PTLeftInset = 26.0;     // period-number ruler
static const CGFloat PTFBlockGap = 14.0;

@interface PTPeriodicTableView ()
@property (nonatomic, strong) NSMutableArray<NSNumber *> *slots;
@property (nonatomic, assign) NSInteger fBlockStartRow;
@end

@implementation PTPeriodicTableView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (!self) { return nil; }
    _itemSize = NSMakeSize(54, 54);
    _elements = @[];
    _matches = @[];
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor colorWithSRGBRed:0.075 green:0.082 blue:0.11 alpha:1.0].CGColor;
    [self rebuildSlots];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)canBecomeKeyView { return YES; }

#pragma mark - Data

- (void)setElements:(NSArray<PTElement *> *)elements {
    _elements = [elements copy];
    [self rebuildSlots];
    [self setNeedsDisplay:YES];
}

- (void)setMatches:(NSArray<PTElement *> *)matches {
    _matches = [matches copy];
    [self setNeedsDisplay:YES];
}

- (void)setSelectedAtomicNumber:(NSInteger)selectedAtomicNumber {
    if (_selectedAtomicNumber == selectedAtomicNumber) { return; }
    _selectedAtomicNumber = selectedAtomicNumber;
    [self setNeedsDisplay:YES];
}

- (void)setItemSize:(NSSize)itemSize {
    if (NSEqualSizes(_itemSize, itemSize)) { return; }
    _itemSize = itemSize;
    [self setNeedsDisplay:YES];
    [self setNeedsLayout:YES];
}

- (void)rebuildSlots {
    NSMutableArray<NSNumber *> *slots = [NSMutableArray arrayWithCapacity:self.elements.count];
    for (PTElement *element in self.elements) {
        NSInteger row;
        if (element.isFBlock) {
            row = (element.atomicNumber <= 71) ? PTLanthanideRow : PTActinideRow;
        } else {
            row = element.period - 1;
        }
        NSInteger column = element.group - 1;

        // Pack the slot into a single NSInteger so it can live in an NSValue.
        NSInteger packed = (row << 16) | (column & 0xFFFF);
        [slots addObject:@(packed)];
    }
    self.slots = slots;
}

- (void)slotAtIndex:(NSInteger)index column:(out NSInteger *)column row:(out NSInteger *)row {
    if (index < 0 || index >= (NSInteger)self.slots.count) {
        if (column) { *column = -1; }
        if (row) { *row = -1; }
        return;
    }
    NSInteger packed = self.slots[index].integerValue;
    if (column) { *column = packed & 0xFFFF; }
    if (row) { *row = (packed >> 16) & 0xFFFF; }
}

#pragma mark - Geometry

- (CGFloat)originXForColumn:(NSInteger)column {
    return PTLeftInset + column * (self.itemSize.width + PTSpacing);
}

- (CGFloat)originYForRow:(NSInteger)row {
    CGFloat y = PTTopInset;
    for (NSInteger r = 0; r < row; r++) {
        y += self.itemSize.height + PTSpacing;
        if (r + 1 == PTLanthanideRow) { y += PTFBlockGap; }
    }
    return y;
}

- (NSSize)contentSize {
    CGFloat width = PTLeftInset + PTColumnCount * self.itemSize.width
                  + (PTColumnCount - 1) * PTSpacing + 4.0;
    CGFloat height = PTTopInset;
    for (NSInteger row = 0; row < PTRowCount; row++) {
        height += self.itemSize.height;
        if (row < PTRowCount - 1) {
            height += PTSpacing;
            if (row + 1 == PTLanthanideRow) { height += PTFBlockGap; }
        }
    }
    height += 4.0;
    return NSMakeSize(width, height);
}

- (void)fitToWidth:(CGFloat)width {
    CGFloat available = width - PTLeftInset - 6.0;
    if (available <= 0) { return; }
    CGFloat item = floor((available - PTSpacing * (PTColumnCount - 1)) / (CGFloat)PTColumnCount);
    item = MAX(30.0, MIN(58.0, item));
    if (fabs(item - self.itemSize.width) > 0.5) {
        self.itemSize = NSMakeSize(item, item);
    }
}

- (NSRect)rectForSlotColumn:(NSInteger)column row:(NSInteger)row {
    return NSMakeRect([self originXForColumn:column],
                      [self originYForRow:row],
                      self.itemSize.width,
                      self.itemSize.height);
}

- (NSRect)rectForElement:(PTElement *)element {
    if (element == nil) { return NSZeroRect; }
    NSInteger index = element.atomicNumber - 1;
    if (index < 0 || index >= (NSInteger)self.elements.count) { return NSZeroRect; }
    NSInteger column = 0, row = 0;
    [self slotAtIndex:index column:&column row:&row];
    if (column < 0) { return NSZeroRect; }
    return [self rectForSlotColumn:column row:row];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [self drawRulersInRect:dirtyRect];

    for (NSInteger index = 0; index < (NSInteger)self.elements.count; index++) {
        PTElement *element = self.elements[index];
        NSInteger column = 0, row = 0;
        [self slotAtIndex:index column:&column row:&row];
        if (column < 0) { continue; }

        NSRect rect = [self rectForSlotColumn:column row:row];
        if (!NSIntersectsRect(rect, dirtyRect)) { continue; }

        BOOL selected = (element.atomicNumber == self.selectedAtomicNumber);
        BOOL dimmed = (self.matches.count > 0 && ![self.matches containsObject:element]);
        [self drawTileForElement:element inRect:rect selected:selected dimmed:dimmed];
    }
}

- (void)drawRulersInRect:(NSRect)dirtyRect {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:9.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:1.0 alpha:0.34],
    };

    for (NSInteger column = 0; column < PTColumnCount; column++) {
        NSString *label = [NSString stringWithFormat:@"%ld", (long)(column + 1)];
        NSSize size = [label sizeWithAttributes:attributes];
        CGFloat x = [self originXForColumn:column] + (self.itemSize.width - size.width) / 2.0;
        [label drawAtPoint:NSMakePoint(x, 3.0) withAttributes:attributes];
    }

    for (NSInteger row = 0; row < PTRowCount; row++) {
        NSString *label;
        if (row < PTPeriodCount) {
            label = [NSString stringWithFormat:@"%ld", (long)(row + 1)];
        } else if (row == PTLanthanideRow) {
            label = @"57";
        } else {
            label = @"89";
        }
        NSSize size = [label sizeWithAttributes:attributes];
        CGFloat y = [self originYForRow:row] + (self.itemSize.height - size.height) / 2.0;
        [label drawAtPoint:NSMakePoint(MAX(0.0, PTLeftInset - size.width - 5.0), y) withAttributes:attributes];
    }
}

- (void)drawTileForElement:(PTElement *)element
                    inRect:(NSRect)tile
                  selected:(BOOL)selected
                    dimmed:(BOOL)dimmed {
    NSColor *base = element.categoryColor;
    NSColor *fill = selected ? base : [base colorWithAlphaComponent:0.20];
    NSColor *edge = selected ? [base pt_colorAdjustedByBrightness:0.25] : [base colorWithAlphaComponent:0.85];

    if (selected) {
        NSColor *glow = [base colorWithAlphaComponent:0.35];
        [glow set];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(tile, -2.0, -2.0) xRadius:7.0 yRadius:7.0] fill];
    }

    [fill set];
    [[NSBezierPath bezierPathWithRoundedRect:tile xRadius:5.0 yRadius:5.0] fill];

    [edge set];
    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:tile xRadius:5.0 yRadius:5.0];
    border.lineWidth = selected ? 1.6 : 1.0;
    [border stroke];

    NSColor *symbolColor = selected ? [NSColor whiteColor]
                                    : (dimmed ? [base colorWithAlphaComponent:0.32] : [base pt_colorAdjustedByBrightness:0.10]);
    NSColor *detailColor = selected ? [NSColor colorWithWhite:1.0 alpha:0.85]
                                    : (dimmed ? [base colorWithAlphaComponent:0.28] : [base colorWithAlphaComponent:0.80]);

    CGFloat width = NSWidth(tile);

    NSString *numberText = [NSString stringWithFormat:@"%ld", (long)element.atomicNumber];
    NSDictionary *numberAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:MAX(7.0, width * 0.155) weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: detailColor,
    };
    [numberText drawAtPoint:NSMakePoint(NSMinX(tile) + 3.0, NSMinY(tile) + 2.0) withAttributes:numberAttributes];

    NSString *symbolText = element.symbol;
    NSDictionary *symbolAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:MAX(11.0, width * 0.40) weight:NSFontWeightBold],
        NSForegroundColorAttributeName: symbolColor,
    };
    NSSize symbolSize = [symbolText sizeWithAttributes:symbolAttributes];
    [symbolText drawAtPoint:NSMakePoint(NSMidX(tile) - symbolSize.width / 2.0,
                                        NSMidY(tile) - symbolSize.height / 2.0 - 1.0)
             withAttributes:symbolAttributes];

    if (width >= 44.0) {
        NSString *nameText = element.name;
        NSDictionary *nameAttributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:MAX(5.5, width * 0.105) weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: detailColor,
        };
        NSSize nameSize = [nameText sizeWithAttributes:nameAttributes];
        [nameText drawAtPoint:NSMakePoint(NSMidX(tile) - nameSize.width / 2.0, NSMaxY(tile) - nameSize.height - 2.0)
               withAttributes:nameAttributes];
    }
}

#pragma mark - Interaction

- (NSInteger)indexAtPoint:(NSPoint)point {
    for (NSInteger index = 0; index < (NSInteger)self.elements.count; index++) {
        NSInteger column = 0, row = 0;
        [self slotAtIndex:index column:&column row:&row];
        if (column < 0) { continue; }
        NSRect rect = [self rectForSlotColumn:column row:row];
        if (NSPointInRect(point, rect)) { return index; }
    }
    return -1;
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger index = [self indexAtPoint:point];
    if (index < 0) { return; }

    PTElement *element = self.elements[index];
    self.selectedAtomicNumber = element.atomicNumber;
    [self setNeedsDisplay:YES];

    if ([self.delegate respondsToSelector:@selector(periodicTableView:didSelectElement:)]) {
        [self.delegate periodicTableView:self didSelectElement:element];
    }
}

- (void)keyDown:(NSEvent *)event {
    NSInteger current = 0;
    for (NSInteger index = 0; index < (NSInteger)self.elements.count; index++) {
        if (self.elements[index].atomicNumber == self.selectedAtomicNumber) { current = index; break; }
    }

    NSInteger step = 0;
    if (event.keyCode == 123) { step = -1; }        // left
    else if (event.keyCode == 124) { step = 1; }    // right
    else if (event.keyCode == 125) { step = -18; }  // down
    else if (event.keyCode == 126) { step = 18; }   // up

    if (step == 0) {
        [super keyDown:event];
        return;
    }

    NSInteger next = current + step;
    if (next < 0) { next = 0; }
    if (next >= (NSInteger)self.elements.count) { next = (NSInteger)self.elements.count - 1; }

    PTElement *element = self.elements[next];
    self.selectedAtomicNumber = element.atomicNumber;
    [self setNeedsDisplay:YES];

    if ([self.delegate respondsToSelector:@selector(periodicTableView:didSelectElement:)]) {
        [self.delegate periodicTableView:self didSelectElement:element];
    }
}

- (void)selectElementWithAtomicNumber:(NSInteger)atomicNumber {
    self.selectedAtomicNumber = atomicNumber;
    [self setNeedsDisplay:YES];
}

@end
