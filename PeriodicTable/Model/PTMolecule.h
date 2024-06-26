//
//  PTMolecule.h
//  PeriodicTable
//

#import <Foundation/Foundation.h>
#import "PTGeometry.h"

NS_ASSUME_NONNULL_BEGIN

/// One atom inside a molecule.
@interface PTMoleculeAtom : NSObject

@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSString *elementName;
/// Position in Angstrom, molecule centred on the origin.
@property (nonatomic, assign) PTVec3 position;
/// Covalent radius in Angstrom, used for the sphere size.
@property (nonatomic, assign) double radius;
/// YES when the atom should be rendered with a metallic material.
@property (nonatomic, assign, getter=isMetal) BOOL metal;

@end

/// A bond between two atoms of a molecule.
@interface PTMoleculeBond : NSObject

@property (nonatomic, assign) NSInteger fromIndex;
@property (nonatomic, assign) NSInteger toIndex;
/// Bond order: 1 = single, 2 = double, 3 = triple.
@property (nonatomic, assign) NSInteger order;

@end

/// A fully resolved molecule: atoms with 3D coordinates plus the bonds between them.
@interface PTMolecule : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *formula;
@property (nonatomic, copy) NSString *details;
@property (nonatomic, copy) NSArray<PTMoleculeAtom *> *atoms;
@property (nonatomic, copy) NSArray<PTMoleculeBond *> *bonds;

/// Distance from the origin to the furthest atom — used to frame the camera.
@property (nonatomic, readonly) double boundingRadius;

/// A short line such as "Water · H2O · 3 atoms · 2 bonds".
@property (nonatomic, readonly) NSString *subtitle;

@end

NS_ASSUME_NONNULL_END
