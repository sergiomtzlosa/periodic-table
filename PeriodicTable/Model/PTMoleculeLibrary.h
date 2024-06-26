//
//  PTMoleculeLibrary.h
//  PeriodicTable
//

#import <Foundation/Foundation.h>
#import "PTElement.h"
#import "PTMolecule.h"

NS_ASSUME_NONNULL_BEGIN

/// Builds fully resolved 3D molecules from the compact specifications stored in
/// elements.json.  Coordinates are generated analytically from the geometry type
/// so the data file only has to describe the shape, never a coordinate list.
@interface PTMoleculeLibrary : NSObject

- (instancetype)initWithElements:(NSArray<PTElement *> *)elements
                    moleculeSpecs:(NSArray<NSDictionary *> *)moleculeSpecs
             explicitCoordinates:(nullable NSDictionary<NSString *, NSArray<NSArray<NSNumber *> *> *> *)explicitCoordinates
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Every molecule identifier in the library.
@property (nonatomic, readonly) NSArray<NSString *> *allIdentifiers;

/// The molecule with the given identifier, or nil.
- (nullable PTMolecule *)moleculeWithIdentifier:(nullable NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
