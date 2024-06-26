//
//  AppDelegate.m
//  PeriodicTable
//

#import "AppDelegate.h"
/// The table pane never gets narrower than this.
static const CGFloat kMinimumTableWidth = 620.0;
/// The detail pane keeps this width, which keeps the 3D viewport a fixed size.
static const CGFloat kDetailPaneWidth = 460.0;

#import "PTPeriodicTableViewController.h"
#import "PTDetailViewController.h"
#import "PTMolecule3DViewController.h"

@interface AppDelegate () <PTPeriodicTableViewControllerDelegate, NSSplitViewDelegate>
@property (nonatomic, strong) PTPeriodicTableViewController *tableController;
@property (nonatomic, strong) PTDetailViewController *detailController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self buildMainMenu];

    // ---- View controllers -------------------------------------------------
    self.tableController = [[PTPeriodicTableViewController alloc] init];
    self.tableController.delegate = self;

    self.detailController = [[PTDetailViewController alloc] init];

    // ---- Window ------------------------------------------------------------
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                               NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1460, 860)
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Periodic Table";
    window.minSize = NSMakeSize(1040, 620);
    window.contentMinSize = NSMakeSize(1040, 620);
    window.contentMaxSize = NSMakeSize(2600, 1800);
    window.backgroundColor = [NSColor colorWithSRGBRed:0.07 green:0.075 blue:0.10 alpha:1.0];
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    [window center];
    self.window = window;

    // ---- Split view --------------------------------------------------------
    NSSplitView *splitView = [[NSSplitView alloc] init];
    splitView.vertical = YES;                 // vertical divider: table left, detail right
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    splitView.delegate = self;
    splitView.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *tableView = self.tableController.view;
    NSView *detailView = self.detailController.view;
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    detailView.translatesAutoresizingMaskIntoConstraints = NO;

    [splitView addSubview:tableView];
    [splitView addSubview:detailView];

    NSView *contentView = window.contentView;
    [contentView addSubview:splitView];
    [NSLayoutConstraint activateConstraints:@[
        [splitView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [splitView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [splitView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [splitView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
    ]];

    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    // Start with the table taking most of the width and the detail pane a
    // fixed, comfortable size.
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat tableWidth = MAX(kMinimumTableWidth, NSWidth(window.contentView.bounds) - kDetailPaneWidth);
        [splitView setPosition:tableWidth ofDividerAtIndex:0];
    });

    // Show a familiar element straight away.
    [self.tableController selectElementWithAtomicNumber:6];

}

#pragma mark - NSSplitViewDelegate

// The detail pane keeps a fixed width, so the 3D viewport inside it never
// changes size and the window never resizes as you move between elements.
// Returning a larger minimum declares a minimum size for the pane on the
// left of the divider, returning a smaller maximum declares a minimum size for
// the pane on the right.  Together they keep the detail pane — and therefore
// the 3D viewport inside it — the same width whatever element is selected.
- (CGFloat)splitView:(NSSplitView *)splitView
constrainMinCoordinate:(CGFloat)proposedMinimumPosition
          ofSubviewAt:(NSInteger)dividerIndex {
    if (dividerIndex == 0) { return MAX(proposedMinimumPosition, kMinimumTableWidth); }
    return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView
constrainMaxCoordinate:(CGFloat)proposedMaximumPosition
          ofSubviewAt:(NSInteger)dividerIndex {
    if (dividerIndex == 0) {
        CGFloat width = NSWidth(splitView.bounds);
        return MIN(proposedMaximumPosition, width - kDetailPaneWidth);
    }
    return proposedMaximumPosition;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return NO;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Menu

- (void)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // Application menu
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"About Periodic Table"
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide Periodic Table" action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit Periodic Table" action:@selector(terminate:) keyEquivalent:@"q"];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];

    // File menu — carries the standard Close Window shortcut (⌘W), which closes
    // whichever window is frontmost, so a popped-out 3D model can be dismissed
    // with the keyboard.
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    NSMenuItem *closeItem = [fileMenu addItemWithTitle:@"Close Window"
                                                action:@selector(performClose:)
                                         keyEquivalent:@"w"];
    closeItem.target = nil;   // send it down the responder chain to the key window
    fileMenuItem.submenu = fileMenu;
    [mainMenu addItem:fileMenuItem];

    // Window menu
    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
    windowMenuItem.submenu = windowMenu;
    [mainMenu addItem:windowMenuItem];

    // Edit menu — gives the search field the standard shortcuts.
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:NSSelectorFromString(@"undo:") keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:NSSelectorFromString(@"redo:") keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *findItem = [editMenu addItemWithTitle:@"Find Element" action:@selector(focusSearchField:) keyEquivalent:@"f"];
    findItem.target = self;
    editMenuItem.submenu = editMenu;
    [mainMenu addItem:editMenuItem];

    // View menu
    NSMenuItem *viewMenuItem = [[NSMenuItem alloc] init];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem *moleculeItem = [viewMenu addItemWithTitle:@"Show Molecule"
                                                   action:@selector(showMoleculeMode:)
                                            keyEquivalent:@"1"];
    moleculeItem.target = self;
    NSMenuItem *atomItem = [viewMenu addItemWithTitle:@"Show Electron Shells"
                                               action:@selector(showAtomMode:)
                                        keyEquivalent:@"2"];
    atomItem.target = self;
    [viewMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *zoomItem = [viewMenu addItemWithTitle:@"Zoom In" action:@selector(zoomIn:) keyEquivalent:@"+"];
    zoomItem.target = self;
    NSMenuItem *zoomOutItem = [viewMenu addItemWithTitle:@"Zoom Out" action:@selector(zoomOut:) keyEquivalent:@"-"];
    zoomOutItem.target = self;
    viewMenuItem.submenu = viewMenu;
    [mainMenu addItem:viewMenuItem];

    NSApp.mainMenu = mainMenu;
}

- (void)focusSearchField:(id)sender {
    [self.window makeFirstResponder:self.tableController.searchField];
}

- (void)showMoleculeMode:(id)sender {
    self.detailController.moleculeController.displayMode = PTMoleculeDisplayModeMolecule;
}

- (void)showAtomMode:(id)sender {
    self.detailController.moleculeController.displayMode = PTMoleculeDisplayModeAtom;
}

- (void)zoomIn:(id)sender {
    [self zoomBy:1.25];
}

- (void)zoomOut:(id)sender {
    [self zoomBy:0.8];
}

- (void)zoomBy:(CGFloat)factor {
    NSSize size = self.window.frame.size;
    CGFloat width = MIN(MAX(760.0, size.width * factor), 3200.0);
    CGFloat height = MIN(MAX(520.0, size.height * factor), 2400.0);
    [self.window setFrame:NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, width, height)
                 display:YES];
}

#pragma mark - PTPeriodicTableViewControllerDelegate

- (void)periodicTableViewController:(PTPeriodicTableViewController *)controller
                   didSelectElement:(PTElement *)element {
    [self.detailController displayElement:element];
}

@end
