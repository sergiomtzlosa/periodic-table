//
//  PTPeriodicTableViewController.m
//  PeriodicTable
//

#import "PTPeriodicTableViewController.h"
#import "PTElementStore.h"
#import "PTPeriodicTableView.h"
#import "PTElementCategories.h"

@interface PTPeriodicTableViewController () <PTPeriodicTableViewDelegate>
@property (nonatomic, strong) NSArray<PTElement *> *elements;
@property (nonatomic, copy) NSArray<PTElement *> *matches;
@property (nonatomic, strong, readwrite) PTPeriodicTableView *tableView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSTextField *resultLabel;
@property (nonatomic, strong) NSStackView *legendView;
@property (nonatomic, assign) NSInteger selectedAtomicNumber;
@end

@implementation PTPeriodicTableViewController

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1040, 700)];
    container.wantsLayer = YES;
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.elements = [PTElementStore sharedStore].allElements;
    self.matches = self.elements;

    [self buildSearchBar];
    [self buildLegend];
    [self buildTableView];
    [self buildConstraints];
}

#pragma mark - UI construction

- (void)buildSearchBar {
    NSSearchField *searchField = [[NSSearchField alloc] init];
    searchField.placeholderString = @"Search element, symbol or number";
    searchField.target = self;
    searchField.action = @selector(searchFieldChanged:);
    searchField.sendsWholeSearchString = NO;
    searchField.sendsSearchStringImmediately = YES;
    searchField.translatesAutoresizingMaskIntoConstraints = NO;
    [searchField.widthAnchor constraintEqualToConstant:240.0].active = YES;
    [self.view addSubview:searchField];
    self.searchField = searchField;

    NSTextField *resultLabel = [NSTextField labelWithString:@""];
    resultLabel.font = [NSFont systemFontOfSize:11.0];
    resultLabel.textColor = [NSColor colorWithWhite:0.45 alpha:1.0];
    resultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:resultLabel];
    self.resultLabel = resultLabel;
}

- (void)buildLegend {
    NSMutableArray<NSView *> *chips = [NSMutableArray array];
    for (NSNumber *categoryNumber in [PTElementCategories allCategories]) {
        PTElementCategory category = (PTElementCategory)categoryNumber.integerValue;
        [chips addObject:[self legendChipForCategory:category]];
    }

    NSStackView *legend = [NSStackView stackViewWithViews:chips];
    legend.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    legend.alignment = NSLayoutAttributeCenterY;
    legend.spacing = 10.0;
    legend.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:legend];

    self.legendView = legend;
}

- (NSView *)legendChipForCategory:(PTElementCategory)category {
    NSView *chip = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 84, 16)];
    chip.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *dot = [[NSView alloc] initWithFrame:NSZeroRect];
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 3.5;
    dot.layer.backgroundColor = [PTElementCategories colorForCategory:category].CGColor;
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    [chip addSubview:dot];

    NSTextField *label = [NSTextField labelWithString:[PTElementCategories nameForCategory:category]];
    label.font = [NSFont systemFontOfSize:10.0];
    label.textColor = [NSColor colorWithWhite:0.55 alpha:1.0];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [chip addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [chip.heightAnchor constraintEqualToConstant:15.0],

        [dot.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor],
        [dot.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        [dot.widthAnchor constraintEqualToConstant:7.0],
        [dot.heightAnchor constraintEqualToConstant:7.0],

        [label.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:5.0],
        [label.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        [chip.trailingAnchor constraintEqualToAnchor:label.trailingAnchor],
    ]];

    return chip;
}

- (void)buildTableView {
    PTPeriodicTableView *tableView = [[PTPeriodicTableView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 560)];
    tableView.elements = self.elements;
    tableView.matches = self.matches;
    tableView.delegate = self;
    tableView.translatesAutoresizingMaskIntoConstraints = YES;
    self.tableView = tableView;

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = tableView;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;
}

- (void)buildConstraints {
    NSView *search = self.searchField;
    NSView *result = self.resultLabel;
    NSView *legend = self.legendView;
    NSView *scroll = self.scrollView;

    [NSLayoutConstraint activateConstraints:@[
        [search.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [search.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10.0],
        [search.widthAnchor constraintEqualToConstant:240.0],
        [search.heightAnchor constraintEqualToConstant:24.0],

        [result.leadingAnchor constraintEqualToAnchor:search.trailingAnchor constant:10.0],
        [result.centerYAnchor constraintEqualToAnchor:search.centerYAnchor],

        [legend.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:14.0],
        [legend.topAnchor constraintEqualToAnchor:search.bottomAnchor constant:8.0],
        [legend.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-14.0],

        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:legend.bottomAnchor constant:8.0],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - Layout

- (void)viewDidLayout {
    [super viewDidLayout];
    [self updateTableGeometry];
    [self updateResultLabel];
}

- (void)updateTableGeometry {
    CGFloat width = NSWidth(self.scrollView.contentView.bounds);
    if (width <= 0) { return; }

    [self.tableView fitToWidth:width];
    NSSize size = self.tableView.contentSize;
    NSRect frame = self.tableView.frame;
    if (fabs(NSWidth(frame) - size.width) > 0.5 || fabs(NSHeight(frame) - size.height) > 0.5) {
        frame.size = size;
        self.tableView.frame = frame;
        [self.scrollView.contentView setFrameSize:size];
    }
}

- (void)updateResultLabel {
    if (self.matches.count == self.elements.count) {
        self.resultLabel.stringValue = [NSString stringWithFormat:@"%lu elements", (unsigned long)self.elements.count];
    } else {
        self.resultLabel.stringValue = [NSString stringWithFormat:@"%lu of %lu elements",
                                        (unsigned long)self.matches.count, (unsigned long)self.elements.count];
    }
}

#pragma mark - Search

- (void)searchFieldChanged:(NSSearchField *)sender {
    NSString *query = [sender.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].lowercaseString;
    if (query.length == 0) {
        self.matches = self.elements;
    } else {
        NSMutableArray<PTElement *> *matches = [NSMutableArray array];
        for (PTElement *element in self.elements) {
            BOOL hit = [element.symbol.lowercaseString containsString:query]
                    || [element.name.lowercaseString containsString:query]
                    || [element.summary.lowercaseString containsString:query]
                    || [[NSString stringWithFormat:@"%ld", (long)element.atomicNumber] isEqualToString:query]
                    || [[PTElementCategories nameForCategory:element.category].lowercaseString containsString:query];
            if (hit) { [matches addObject:element]; }
        }
        self.matches = matches;
    }

    self.tableView.matches = self.matches;
    [self updateResultLabel];
}

#pragma mark - Selection

- (void)selectElementWithAtomicNumber:(NSInteger)atomicNumber {
    if (atomicNumber < 1 || atomicNumber > (NSInteger)self.elements.count) { return; }

    self.selectedAtomicNumber = atomicNumber;
    [self.tableView selectElementWithAtomicNumber:atomicNumber];

    PTElement *element = self.elements[atomicNumber - 1];
    [self scrollToElement:element];
    [self notifyDelegateForElement:element];
}

/// Scrolls the minimum amount needed to bring the element's tile into view.
- (void)scrollToElement:(PTElement *)element {
    NSRect tile = [self.tableView rectForElement:element];
    if (NSIsEmptyRect(tile)) { return; }

    NSClipView *clipView = self.scrollView.contentView;
    NSRect visible = clipView.documentVisibleRect;

    CGFloat dx = 0.0, dy = 0.0;
    if (tile.origin.x < visible.origin.x) {
        dx = tile.origin.x - visible.origin.x;
    } else if (NSMaxX(tile) > NSMaxX(visible)) {
        dx = NSMaxX(tile) - NSMaxX(visible);
    }
    if (tile.origin.y < visible.origin.y) {
        dy = tile.origin.y - visible.origin.y;
    } else if (NSMaxY(tile) > NSMaxY(visible)) {
        dy = NSMaxY(tile) - NSMaxY(visible);
    }
    if (dx != 0.0 || dy != 0.0) {
        [clipView scrollToPoint:NSMakePoint(visible.origin.x + dx, visible.origin.y + dy)];
    }
}

- (void)notifyDelegateForElement:(PTElement *)element {
    if (element == nil) { return; }
    if ([self.delegate respondsToSelector:@selector(periodicTableViewController:didSelectElement:)]) {
        [self.delegate periodicTableViewController:self didSelectElement:element];
    }
}

#pragma mark - PTPeriodicTableViewDelegate

- (void)periodicTableView:(PTPeriodicTableView *)tableView didSelectElement:(PTElement *)element {
    self.selectedAtomicNumber = element.atomicNumber;
    [self notifyDelegateForElement:element];
}

@end
