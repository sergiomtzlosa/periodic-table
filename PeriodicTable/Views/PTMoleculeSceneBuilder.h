//
//  PTMoleculeSceneBuilder.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>
#import <SceneKit/SceneKit.h>
#import "PTElement.h"
#import "PTMolecule.h"

NS_ASSUME_NONNULL_BEGIN

/// Builds the 3D scenes shown in the viewer:
///  * a molecule scene with bonded atoms that rotate and breathe,
///  * an atom scene with a proton/neutron nucleus and orbiting electrons.
@interface PTMoleculeSceneBuilder : NSObject

/// A SceneKit scene of the given molecule, animated and framed for the viewport.
+ (SCNScene *)moleculeSceneForMolecule:(nullable PTMolecule *)molecule
                           viewportSize:(NSSize)viewportSize;

/// A SceneKit scene of the element's nucleus and electron shells, animated and framed.
+ (SCNScene *)atomSceneForElement:(nullable PTElement *)element
                      viewportSize:(NSSize)viewportSize;

/// Re-fits the camera of an existing scene to a new viewport size, keeping the
/// current viewing direction so a manual orbit is not lost.
+ (void)frameScene:(nullable SCNScene *)scene viewportSize:(NSSize)viewportSize;

@end

NS_ASSUME_NONNULL_END
