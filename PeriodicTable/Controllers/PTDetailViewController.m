//
//  PTDetailViewController.m
//  PeriodicTable
//

#import "PTDetailViewController.h"
#import "PTMolecule3DViewController.h"
#import <SceneKit/SceneKit.h>
#import "PTElementStore.h"
#import "PTElectronShellView.h"
#import "PTMolecule3DViewController.h"
#import <SceneKit/SceneKit.h>

/// A top-down stack view, so it can be used as a scroll view's document view.
@interface PTFlippedStackView : NSStackView
@end

@implementation PTFlippedStackView
- (BOOL)isFlipped { return YES; }
@end

@interface PTDetailViewController ()
@property (nonatomic, strong) NSScrollView *infoScrollView;
@property (nonatomic, strong) NSStackView *infoStack;
@property (nonatomic, strong) PTMolecule3DViewController *moleculeController;
@property (nonatomic, strong, nullable) PTElement *element;
/// Labels whose width is pinned to the pane so they wrap instead of widening it.
@property (nonatomic, strong) NSMutableArray<NSTextField *> *pinnedLabels;
@end

@implementation PTDetailViewController

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 420, 760)];
    container.wantsLayer = YES;
    container.layer.backgroundColor = [NSColor colorWithSRGBRed:0.075 green:0.082 blue:0.11 alpha:1.0].CGColor;
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // ---- Scrolling information area --------------------------------------
    self.infoStack = [[PTFlippedStackView alloc] init];
    self.infoStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    // The stack's width is pinned to the pane, and the labels that can be long
    // are pinned to the same width so they wrap instead of widening the pane,
    // moving the split divider and resizing the window.
    self.infoStack.alignment = NSLayoutAttributeLeading;
    self.infoStack.spacing = 12.0;
    self.infoStack.edgeInsets = NSEdgeInsetsMake(18, 18, 18, 18);
    self.infoStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.infoStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.infoStack.alignment = NSLayoutAttributeLeading;
    self.infoStack.spacing = 12.0;
    self.infoStack.edgeInsets = NSEdgeInsetsMake(18, 18, 18, 18);
    self.infoStack.translatesAutoresizingMaskIntoConstraints = NO;

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = YES;
    scrollView.drawsBackground = NO;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = self.infoStack;
    [self.view addSubview:scrollView];
    self.infoScrollView = scrollView;

    // ---- 3D viewer ---------------------------------------------------------
    self.moleculeController = [[PTMolecule3DViewController alloc] init];
    [self addChildViewController:self.moleculeController];
    NSView *threeDView = self.moleculeController.view;
    threeDView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:threeDView];

    NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:separator];

    // The 3D viewport has a fixed height: it must not change size when the
    // information above it gets longer or shorter, otherwise the molecule
    // would be re-framed to a different size on every selection.
    NSLayoutConstraint *threeDHeight = [threeDView.heightAnchor constraintEqualToConstant:330.0];
    threeDHeight.priority = NSLayoutPriorityRequired;
    threeDHeight.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:separator.topAnchor],

        [separator.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [separator.heightAnchor constraintEqualToConstant:1.0],

        [threeDView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [threeDView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [threeDView.topAnchor constraintEqualToAnchor:separator.bottomAnchor],
        [threeDView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:240.0],

        // The information stack must match the clip view's width.
        [self.infoStack.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor],
    ]];

    if (self.element) { [self rebuildInformation]; }
}


#pragma mark - Content

- (void)displayElement:(nullable PTElement *)element {
    self.element = element;
    if (!self.isViewLoaded) {
        [self loadView];
        [self viewDidLoad];
    }
    [self rebuildInformation];
    [self.infoScrollView.contentView scrollToPoint:NSZeroPoint];

    PTMolecule *molecule = [[PTElementStore sharedStore] moleculeForElement:element];
    [self.moleculeController showMolecule:molecule forElement:element];
}

- (void)rebuildInformation {
    for (NSView *view in self.infoStack.arrangedSubviews) {
        [self.infoStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    self.pinnedLabels = [NSMutableArray array];

    PTElement *element = self.element;
    if (element == nil) {
        NSTextField *placeholder = [self labelWithText:@"Select an element to see its properties, uses and a 3D model."
                                                   font:[NSFont systemFontOfSize:13.0]
                                                  color:[NSColor colorWithWhite:0.55 alpha:1.0]];
        [self.infoStack addArrangedSubview:placeholder];
        return;
    }

    [self.infoStack addArrangedSubview:[self headerViewForElement:element]];
    [self.infoStack addArrangedSubview:[self separatorLine]];
    [self.infoStack addArrangedSubview:[self propertiesGridForElement:element]];
    [self.infoStack addArrangedSubview:[self electronSectionForElement:element]];
    [self.infoStack addArrangedSubview:[self usesSectionForElement:element]];
    [self.infoStack addArrangedSubview:[self historySectionForElement:element]];
    [self.infoStack addArrangedSubview:[self moleculeSectionForElement:element]];

    [self pinLabelsToPaneWidth];
}

#pragma mark - Sections

- (NSView *)headerViewForElement:(PTElement *)element {
    NSTextField *symbol = [self labelWithText:element.symbol
                                         font:[NSFont systemFontOfSize:58.0 weight:NSFontWeightBold]
                                        color:element.categoryColor];

    NSTextField *number = [self labelWithText:[NSString stringWithFormat:@"%ld", (long)element.atomicNumber]
                                         font:[NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold]
                                        color:[NSColor colorWithWhite:0.45 alpha:1.0]];

    NSTextField *name = [self labelWithText:element.name
                                       font:[NSFont systemFontOfSize:19.0 weight:NSFontWeightSemibold]
                                      color:[NSColor colorWithWhite:0.95 alpha:1.0]];

    NSTextField *category = [self labelWithText:[PTElementCategories nameForCategory:element.category]
                                           font:[NSFont systemFontOfSize:12.0]
                                          color:element.categoryColor];

    NSTextField *groupPeriod = [self labelWithText:element.groupPeriodDescription
                                              font:[NSFont systemFontOfSize:11.0]
                                             color:[NSColor colorWithWhite:0.45 alpha:1.0]];

    for (NSTextField *label in @[name, category, groupPeriod]) {
        label.lineBreakMode = NSLineBreakByTruncatingTail;
    }

    NSStackView *textStack = [NSStackView stackViewWithViews:@[name, category, groupPeriod]];
    textStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    textStack.alignment = NSLayoutAttributeLeading;
    textStack.spacing = 3.0;

    NSStackView *symbolColumn = [NSStackView stackViewWithViews:@[number, symbol]];
    symbolColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    symbolColumn.alignment = NSLayoutAttributeCenterX;
    symbolColumn.spacing = -4.0;

    NSStackView *topRow = [NSStackView stackViewWithViews:@[symbolColumn, textStack]];
    topRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    topRow.alignment = NSLayoutAttributeTop;
    topRow.translatesAutoresizingMaskIntoConstraints = NO;
    topRow.spacing = 14.0;

    NSTextField *summary = [self wrappingLabelWithText:element.summary
                                                    font:[NSFont systemFontOfSize:12.0]
                                                   color:[NSColor colorWithWhite:0.72 alpha:1.0]];

    NSStackView *header = [NSStackView stackViewWithViews:@[topRow, summary]];
    header.orientation = NSUserInterfaceLayoutOrientationVertical;
    header.alignment = NSLayoutAttributeLeading;
    header.spacing = 8.0;
    header.translatesAutoresizingMaskIntoConstraints = NO;
    return header;
}

- (NSGridView *)propertiesGridForElement:(PTElement *)element {
    NSMutableArray<NSArray<NSView *> *> *rows = [NSMutableArray array];

    [rows addObject:@[[self propertyNameLabel:@"Atomic mass"],
                       [self propertyValueLabel:[NSString stringWithFormat:@"%.3f u", element.atomicMass]]]];
    [rows addObject:@[[self propertyNameLabel:@"Phase at 20 °C"],
                       [self propertyValueLabel:element.phase]]];
    [rows addObject:@[[self propertyNameLabel:@"Electronegativity"],
                       [self propertyValueLabel:element.electronegativity != nil
                        ? [NSString stringWithFormat:@"%.2f (Pauling)", element.electronegativity.doubleValue]
                        : @"—"]]];
    [rows addObject:@[[self propertyNameLabel:@"Atomic radius"],
                       [self propertyValueLabel:element.atomicRadius != nil
                        ? [NSString stringWithFormat:@"%.0f pm", element.atomicRadius.doubleValue]
                        : @"—"]]];
    [rows addObject:@[[self propertyNameLabel:@"Melting point"],
                       [self propertyValueLabel:element.meltingPoint != nil
                        ? [NSString stringWithFormat:@"%.1f K (%.1f °C)", element.meltingPoint.doubleValue,
                           element.meltingPoint.doubleValue - 273.15]
                        : @"—"]]];
    [rows addObject:@[[self propertyNameLabel:@"Boiling point"],
                       [self propertyValueLabel:element.boilingPoint != nil
                        ? [NSString stringWithFormat:@"%.1f K (%.1f °C)", element.boilingPoint.doubleValue,
                           element.boilingPoint.doubleValue - 273.15]
                        : @"—"]]];
    [rows addObject:@[[self propertyNameLabel:@"Density"],
                       [self propertyValueLabel:element.density != nil
                        ? [NSString stringWithFormat:@"%.4f g/cm³", element.density.doubleValue]
                        : @"—"]]];
    [rows addObject:@[[self propertyNameLabel:@"Discovered"],
                       [self propertyValueLabel:element.discoveryYear]]];
    [rows addObject:@[[self propertyNameLabel:@"By"],
                       [self propertyValueLabel:element.discoverer]]];

    NSGridView *grid = [NSGridView gridViewWithViews:rows];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.rowSpacing = 5.0;
    grid.columnSpacing = 16.0;
    [grid columnAtIndex:0].xPlacement = NSGridCellPlacementTrailing;
    [grid columnAtIndex:1].xPlacement = NSGridCellPlacementLeading;
    return grid;
}

- (NSView *)electronSectionForElement:(PTElement *)element {
    NSMutableArray<NSView *> *children = [NSMutableArray array];

    [children addObject:[self sectionHeader:@"Electrons"]];

    // The configuration can be very long (oganesson has 21 sub-shells), so it
    // has to wrap rather than widen the whole pane.
    NSTextField *configuration = [self wrappingLabelWithText:element.configuration.length ? element.configuration : @"—"
                                                          font:[NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightRegular]
                                                         color:[NSColor colorWithWhite:0.85 alpha:1.0]];
    configuration.lineBreakMode = NSLineBreakByCharWrapping;
    [children addObject:configuration];

    PTElectronShellView *shellView = [[PTElectronShellView alloc] initWithFrame:NSMakeRect(0, 0, 130, 130)];
    shellView.shells = element.shells;
    shellView.shellColor = [NSColor colorWithWhite:1.0 alpha:0.25];
    shellView.electronColor = element.categoryColor;
    shellView.nucleusColor = [NSColor colorWithSRGBRed:0.95 green:0.4 blue:0.35 alpha:1.0];
    shellView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [shellView.widthAnchor constraintEqualToConstant:140.0],
        [shellView.heightAnchor constraintEqualToConstant:140.0],
    ]];
    [children addObject:shellView];

    // Shell breakdown text next to the diagram.
    NSMutableString *shellText = [NSMutableString string];
    NSUInteger index = 0;
    for (NSNumber *shell in element.shells) {
        if (index > 0) { [shellText appendString:@"\n"]; }
        [shellText appendFormat:@"Shell %lu — %@ electron%@", (unsigned long)(index + 1), shell,
         shell.unsignedIntegerValue == 1 ? @"" : @"s"];
        index++;
    }
    if (shellText.length == 0) { [shellText appendString:@"No shell data available."]; }
    NSTextField *shells = [self wrappingLabelWithText:shellText
                                                   font:[NSFont systemFontOfSize:11.5]
                                                  color:[NSColor colorWithWhite:0.68 alpha:1.0]];

    NSStackView *row = [NSStackView stackViewWithViews:@[shellView, shells]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 14.0;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [children addObject:row];

    return [self sectionContainerWithViews:children];
}

- (NSView *)usesSectionForElement:(PTElement *)element {
    NSMutableArray<NSView *> *children = [NSMutableArray array];
    [children addObject:[self sectionHeader:@"Common uses"]];

    if (element.uses.count == 0) {
        [children addObject:[self labelWithText:@"No common uses recorded."
                                          font:[NSFont systemFontOfSize:12.0]
                                         color:[NSColor colorWithWhite:0.55 alpha:1.0]]];
    } else {
        for (NSString *use in element.uses) {
            NSView *row = [self bulletRowWithText:use color:element.categoryColor];
            [children addObject:row];
        }
    }
    return [self sectionContainerWithViews:children];
}

- (NSView *)historySectionForElement:(PTElement *)element {
    NSMutableArray<NSView *> *children = [NSMutableArray array];
    [children addObject:[self sectionHeader:@"Discovery"]];
    [children addObject:[self labelWithText:[NSString stringWithFormat:@"%@ — %@", element.discoveryYear, element.discoverer]
                                      font:[NSFont systemFontOfSize:12.0]
                                     color:[NSColor colorWithWhite:0.72 alpha:1.0]]];
    return [self sectionContainerWithViews:children];
}

- (NSView *)moleculeSectionForElement:(PTElement *)element {
    PTMolecule *molecule = [[PTElementStore sharedStore] moleculeForElement:element];

    NSMutableArray<NSView *> *children = [NSMutableArray array];
    [children addObject:[self sectionHeader:@"3D model"]];

    NSTextField *name = [self labelWithText:molecule.displayName ?: @"—"
                                       font:[NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold]
                                      color:[NSColor colorWithWhite:0.95 alpha:1.0]];
    [children addObject:name];

    NSTextField *formula = [self labelWithText:molecule.formula
                                          font:[NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightMedium]
                                         color:element.categoryColor];
    [children addObject:formula];

    NSTextField *details = [self wrappingLabelWithText:molecule.details ?: @""
                                                    font:[NSFont systemFontOfSize:12.0]
                                                   color:[NSColor colorWithWhite:0.68 alpha:1.0]];
    [children addObject:details];

    NSTextField *stats = [self wrappingLabelWithText:molecule.subtitle ?: @""
                                                  font:[NSFont systemFontOfSize:11.0]
                                                 color:[NSColor colorWithWhite:0.45 alpha:1.0]];
    [children addObject:stats];

    return [self sectionContainerWithViews:children];
}

#pragma mark - Small builders

- (NSTextField *)labelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

/// A label that wraps inside the pane instead of widening it.  An NSTextField
/// never shrinks below the width of its text, so a long line (an electron
/// configuration) has to be pinned to the pane width explicitly.
- (NSTextField *)wrappingLabelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [self labelWithText:text font:font color:color];
    label.maximumNumberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    [label setContentHuggingPriority:NSLayoutPriorityDefaultLow
                         forOrientation:NSLayoutConstraintOrientationHorizontal];
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.pinnedLabels addObject:label];
    return label;
}

/// Pins every collected label to the width of the pane.  This has to happen
/// once the labels are in the view hierarchy, otherwise AppKit refuses to
/// activate the constraints.
- (void)pinLabelsToPaneWidth {
    NSLayoutAnchor *paneWidth = self.infoScrollView.contentView.widthAnchor;
    for (NSTextField *label in self.pinnedLabels) {
        [label.widthAnchor constraintEqualToAnchor:paneWidth].active = YES;
    }
}

- (NSTextField *)propertyNameLabel:(NSString *)text {
    NSTextField *label = [self labelWithText:text
                                         font:[NSFont systemFontOfSize:11.5]
                                        color:[NSColor colorWithWhite:0.5 alpha:1.0]];
    label.alignment = NSTextAlignmentRight;
    return label;
}

- (NSTextField *)propertyValueLabel:(NSString *)text {
    NSTextField *label = [self labelWithText:text
                                         font:[NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium]
                                        color:[NSColor colorWithWhite:0.88 alpha:1.0]];
    return label;
}

- (NSTextField *)sectionHeader:(NSString *)title {
    NSTextField *label = [self labelWithText:title.uppercaseString
                                         font:[NSFont systemFontOfSize:10.0 weight:NSFontWeightBold]
                                        color:[NSColor colorWithWhite:0.42 alpha:1.0]];
    return label;
}

- (NSView *)bulletRowWithText:(NSString *)text color:(NSColor *)color {
    NSView *dot = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 5, 5)];
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 2.5;
    dot.layer.backgroundColor = color.CGColor;
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:5.0],
        [dot.heightAnchor constraintEqualToConstant:5.0],
    ]];

    NSTextField *label = [self labelWithText:text
                                         font:[NSFont systemFontOfSize:12.0]
                                        color:[NSColor colorWithWhite:0.80 alpha:1.0]];

    NSStackView *row = [NSStackView stackViewWithViews:@[dot, label]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8.0;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    return row;
}

- (NSView *)separatorLine {
    NSBox *box = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, 360, 1)];
    box.boxType = NSBoxSeparator;
    box.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [box.heightAnchor constraintEqualToConstant:1.0],
    ]];
    return box;
}

- (NSView *)sectionContainerWithViews:(NSArray<NSView *> *)views {
    NSStackView *stack = [NSStackView stackViewWithViews:views];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 6.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    return stack;
}

@end
