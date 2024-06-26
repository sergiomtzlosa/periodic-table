//
//  PTMolecule3DViewController.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>
#import "PTElement.h"
#import "PTMolecule.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PTMoleculeDisplayMode) {
    /// Show the compound the element forms.
    PTMoleculeDisplayModeMolecule = 0,
    /// Show the element's own nucleus and electron shells.
    PTMoleculeDisplayModeAtom = 1,
};

@class PTCameraSceneView;

/// Hosts the SceneKit view, the display-mode switch and the playback controls.
@interface PTMolecule3DViewController : NSViewController

/// The SceneKit view that renders the molecule or atom.
@property (nonatomic, strong, readonly) PTCameraSceneView *sceneView;

/// Which of the two representations is currently shown.
@property (nonatomic, assign) PTMoleculeDisplayMode displayMode;

/// YES while the animation is running.
@property (nonatomic, readonly, getter=isAnimating) BOOL animating;

/// Shows the given molecule (and remembers the element for the atom view).
- (void)showMolecule:(nullable PTMolecule *)molecule forElement:(nullable PTElement *)element;

/// Shows the element's nucleus and electron shells.
- (void)showElement:(nullable PTElement *)element;

/// Opens the current model in its own window.
- (void)popOut:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
