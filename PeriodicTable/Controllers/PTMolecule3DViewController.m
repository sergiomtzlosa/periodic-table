//
//  PTMolecule3DViewController.m
//  PeriodicTable
//

#import "PTMolecule3DViewController.h"
#import "PTMoleculeSceneBuilder.h"
#import "PTCameraSceneView.h"

@interface PTMolecule3DViewController () <NSWindowDelegate>
@property (nonatomic, strong) PTCameraSceneView *sceneView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *subtitleLabel;
@property (nonatomic, strong) NSSegmentedControl *modeControl;
@property (nonatomic, strong) NSButton *playPauseButton;
@property (nonatomic, strong) PTMolecule *molecule;
@property (nonatomic, strong) PTElement *element;
@property (nonatomic, assign, getter=isAnimating) BOOL animating;
/// The viewport size the current scene was framed for.
@property (nonatomic, assign) NSSize framedViewportSize;
/// Pop-out windows that are currently open.
@property (nonatomic, strong) NSMutableArray<NSWindow *> *popOutWindows;
@end

@implementation PTMolecule3DViewController

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 420)];
    container.wantsLayer = YES;
    container.layer.backgroundColor = [NSColor colorWithSRGBRed:0.055 green:0.065 blue:0.09 alpha:1.0].CGColor;
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // ---- Scene view -----------------------------------------------------
    PTCameraSceneView *sceneView = [[PTCameraSceneView alloc] init];
    sceneView.translatesAutoresizingMaskIntoConstraints = NO;
    sceneView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    sceneView.preferredFramesPerSecond = 60;
    sceneView.backgroundColor = [NSColor colorWithSRGBRed:0.055 green:0.065 blue:0.09 alpha:1.0];
    sceneView.wantsLayer = YES;
    [self.view addSubview:sceneView];
    self.sceneView = sceneView;

    // ---- Overlay title --------------------------------------------------
    // A plain translucent panel rather than an NSVisualEffectView: a visual
    // effect samples the backdrop behind it on every frame, which with a
    // Metal-rendered scene underneath makes the panel shimmer and wastes
    // time copying the render target.
    NSView *overlay = [[NSView alloc] init];
    overlay.wantsLayer = YES;
    overlay.layer.cornerRadius = 8.0;
    overlay.layer.masksToBounds = YES;
    overlay.layer.backgroundColor = [NSColor colorWithSRGBRed:0.08 green:0.09 blue:0.13 alpha:0.78].CGColor;
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:overlay];

    self.titleLabel = [self makeOverlayLabelWithFont:[NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold]
                                                color:[NSColor colorWithWhite:0.95 alpha:1.0]];
    self.subtitleLabel = [self makeOverlayLabelWithFont:[NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular]
                                                  color:[NSColor colorWithWhite:0.65 alpha:1.0]];

    NSStackView *labelStack = [NSStackView stackViewWithViews:@[self.titleLabel, self.subtitleLabel]];
    labelStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    labelStack.alignment = NSLayoutAttributeLeading;
    labelStack.spacing = 2.0;
    labelStack.translatesAutoresizingMaskIntoConstraints = NO;
    [overlay addSubview:labelStack];

    // ---- Control bar ----------------------------------------------------
    self.modeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Molecule", @"Electron Shells"]
                                                              trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                    target:self
                                                                    action:@selector(modeControlChanged:)];
    self.modeControl.segmentStyle = NSSegmentStyleRounded;
    self.modeControl.selectedSegment = 0;
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;

    self.playPauseButton = [NSButton buttonWithTitle:@"Pause"
                                               target:self
                                               action:@selector(toggleAnimation:)];
    self.playPauseButton.bezelStyle = NSBezelStyleRounded;
    self.playPauseButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *popOutButton = [NSButton buttonWithTitle:@"Pop Out"
                                                 target:self
                                                 action:@selector(popOut:)];
    popOutButton.bezelStyle = NSBezelStyleRounded;
    popOutButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *controlStack = [NSStackView stackViewWithViews:@[self.modeControl, self.playPauseButton, popOutButton]];
    controlStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controlStack.spacing = 8.0;
    controlStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:controlStack];

    // ---- Constraints -----------------------------------------------------
    [NSLayoutConstraint activateConstraints:@[
        [sceneView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sceneView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [sceneView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sceneView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12.0],
        [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:12.0],
        [labelStack.leadingAnchor constraintEqualToAnchor:overlay.leadingAnchor constant:12.0],
        [labelStack.trailingAnchor constraintLessThanOrEqualToAnchor:overlay.trailingAnchor constant:-12.0],
        [labelStack.topAnchor constraintEqualToAnchor:overlay.topAnchor constant:8.0],
        [labelStack.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:-8.0],

        [controlStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12.0],
        [controlStack.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-12.0],
        [controlStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:12.0],
    ]];

    self.animating = YES;
    self.popOutWindows = [NSMutableArray array];
}


- (void)viewDidLayout {
    [super viewDidLayout];

    NSSize viewport = self.sceneView.bounds.size;
    if (viewport.width < 10 || viewport.height < 10) { return; }
    if (fabs(viewport.width - self.framedViewportSize.width) < 1.0 &&
        fabs(viewport.height - self.framedViewportSize.height) < 1.0) {
        return;
    }

    [self.sceneView refit];
    self.framedViewportSize = viewport;

}

- (NSTextField *)makeOverlayLabelWithFont:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:@""];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

#pragma mark - Content

- (void)showMolecule:(nullable PTMolecule *)molecule forElement:(nullable PTElement *)element {
    self.molecule = molecule;
    self.element = element;
    if (self.displayMode == PTMoleculeDisplayModeAtom) {
        [self applyScene];
    } else {
        [self applyScene];
    }
}

- (void)showElement:(nullable PTElement *)element {
    self.element = element;
    [self applyScene];
}

- (void)setDisplayMode:(PTMoleculeDisplayMode)displayMode {
    if (_displayMode == displayMode) { return; }
    _displayMode = displayMode;
    self.modeControl.selectedSegment = (displayMode == PTMoleculeDisplayModeAtom) ? 1 : 0;
    [self applyScene];
}

- (void)applyScene {
    if (!self.isViewLoaded) { return; }

    NSSize viewport = self.sceneView.bounds.size;
    if (viewport.width < 10 || viewport.height < 10) {
        viewport = NSMakeSize(520, 330);
    }

    if (self.displayMode == PTMoleculeDisplayModeAtom) {
        self.sceneView.scene = [PTMoleculeSceneBuilder atomSceneForElement:self.element
                                                               viewportSize:viewport];
        self.titleLabel.stringValue = self.element.name ?: @"";
        NSMutableString *subtitle = [NSMutableString string];
        if (self.element.shells.count > 0) {
            [subtitle appendFormat:@"%ld electrons · ", (long)self.element.atomicNumber];
            NSUInteger i = 0;
            for (NSNumber *shell in self.element.shells) {
                if (i > 0) { [subtitle appendString:@" / "]; }
                [subtitle appendFormat:@"K%lu", (unsigned long)(i + 1)];
                [subtitle appendFormat:@" %@", shell];
                i++;
            }
        }
        if (self.element.configuration.length > 0) {
            [subtitle appendFormat:@"  ·  %@", self.element.configuration];
        }
        self.subtitleLabel.stringValue = subtitle;
    } else {
        self.sceneView.scene = [PTMoleculeSceneBuilder moleculeSceneForMolecule:self.molecule
                                                                   viewportSize:viewport];
        self.titleLabel.stringValue = self.molecule.displayName ?: @"";
        self.subtitleLabel.stringValue = self.molecule.subtitle ?: @"";
    }

    self.sceneView.scene.rootNode.paused = !self.animating;
    self.framedViewportSize = viewport;
    self.playPauseButton.title = self.animating ? @"Pause" : @"Play";
}

#pragma mark - Actions

- (void)modeControlChanged:(NSSegmentedControl *)sender {
    self.displayMode = (sender.selectedSegment == 1) ? PTMoleculeDisplayModeAtom : PTMoleculeDisplayModeMolecule;
}

- (void)toggleAnimation:(id)sender {
    self.animating = !self.animating;
    self.sceneView.scene.rootNode.paused = !self.animating;
    self.playPauseButton.title = self.animating ? @"Pause" : @"Play";
}

- (void)popOut:(id)sender {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 560)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = self.displayMode == PTMoleculeDisplayModeAtom
        ? [NSString stringWithFormat:@"%@ — atom", self.element.name ?: @"Atom"]
        : [NSString stringWithFormat:@"%@ — molecule", self.molecule.displayName ?: @"Molecule"];
    window.backgroundColor = [NSColor colorWithSRGBRed:0.055 green:0.065 blue:0.09 alpha:1.0];

    // A programmatically created window is released as soon as it is closed,
    // which tears it down while AppKit is still handling the close and
    // crashes.  Keep it alive ourselves and let the user close it cleanly.
    window.releasedWhenClosed = NO;
    window.delegate = (id<NSWindowDelegate>)self;
    [self.popOutWindows addObject:window];

    PTCameraSceneView *sceneView = [[PTCameraSceneView alloc] init];
    sceneView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    sceneView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    sceneView.preferredFramesPerSecond = 60;
    sceneView.backgroundColor = [NSColor colorWithSRGBRed:0.055 green:0.065 blue:0.09 alpha:1.0];

    NSSize viewport = sceneView.bounds.size;
    if (viewport.width < 10 || viewport.height < 10) {
        viewport = NSMakeSize(720, 560);
    }
    if (self.displayMode == PTMoleculeDisplayModeAtom) {
        sceneView.scene = [PTMoleculeSceneBuilder atomSceneForElement:self.element viewportSize:viewport];
    } else {
        sceneView.scene = [PTMoleculeSceneBuilder moleculeSceneForMolecule:self.molecule viewportSize:viewport];
    }
    sceneView.scene.rootNode.paused = !self.animating;

    window.contentView = sceneView;
    [window center];
    [window makeKeyAndOrderFront:nil];
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification {
    NSWindow *window = notification.object;
    if (![window isKindOfClass:[NSWindow class]]) { return; }
    [self.popOutWindows removeObject:window];
}

@end
