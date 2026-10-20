//
//  PTCameraSceneView.h
//  PeriodicTable
//

#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A SceneKit view with its own camera control.
///
/// `SCNView`'s built-in camera controller nudges the camera whenever the mouse
/// moves over the view without a button held down, which makes the model
/// shimmer and jitter the moment the pointer happens to cross it.  This view
/// turns that off and implements plain drag-to-orbit and scroll-to-zoom
/// instead, so the model only moves when the user actually drags it.
@interface PTCameraSceneView : SCNView

/// The distance the model was framed at.
@property (nonatomic, assign) CGFloat homeDistance;

/// The user's zoom relative to the framed distance (1 = as framed).
@property (nonatomic, assign) CGFloat userZoom;

/// Re-fits the model to the current viewport, keeping the user's zoom.
- (void)refit;

/// Returns the camera to its framed position and zoom.
- (void)resetCamera;

@end

NS_ASSUME_NONNULL_END
