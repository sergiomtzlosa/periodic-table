//
//  PTElement.h
//  PeriodicTable
//

#import <Foundation/Foundation.h>
#import "PTElementCategories.h"

NS_ASSUME_NONNULL_BEGIN

/// A single chemical element. Pure data — no AppKit dependency beyond the category colour.
@interface PTElement : NSObject

/// Atomic number, 1…118.
@property (nonatomic, assign) NSInteger atomicNumber;
/// Chemical symbol, e.g. "Fe".
@property (nonatomic, copy) NSString *symbol;
/// Element name, e.g. "Iron".
@property (nonatomic, copy) NSString *name;
/// Standard atomic weight.
@property (nonatomic, assign) double atomicMass;
/// Category used for colouring and grouping.
@property (nonatomic, assign) PTElementCategory category;
/// IUPAC group (1…18). The f-block occupies groups 3…17.
@property (nonatomic, assign) NSInteger group;
/// Period (1…7).
@property (nonatomic, assign) NSInteger period;
/// YES for the lanthanides and actinides, which live in their own rows.
@property (nonatomic, assign, getter=isFBlock) BOOL fBlock;
/// Ground-state electron configuration, e.g. "1s2 2s2 2p6 3s2 3p6 3d6 4s2".
@property (nonatomic, copy) NSString *configuration;
/// Electrons per principal shell, e.g. @[2, 8, 14, 2].
@property (nonatomic, copy) NSArray<NSNumber *> *shells;
/// Pauling electronegativity, or nil when unknown.
@property (nonatomic, strong, nullable) NSNumber *electronegativity;
/// Empirical atomic radius in picometres, or nil.
@property (nonatomic, strong, nullable) NSNumber *atomicRadius;
/// Covalent radius in picometres, or nil.
@property (nonatomic, strong, nullable) NSNumber *covalentRadius;
/// Melting point in kelvin, or nil.
@property (nonatomic, strong, nullable) NSNumber *meltingPoint;
/// Boiling point in kelvin, or nil.
@property (nonatomic, strong, nullable) NSNumber *boilingPoint;
/// Density in g/cm³ at standard conditions, or nil.
@property (nonatomic, strong, nullable) NSNumber *density;
/// Phase at room temperature: "Solid", "Liquid", "Gas" or "Unknown".
@property (nonatomic, copy) NSString *phase;
/// Year of discovery, e.g. "1766" or "Ancient".
@property (nonatomic, copy) NSString *discoveryYear;
/// Who discovered it.
@property (nonatomic, copy) NSString *discoverer;
/// Identifier of the molecule shown in 3D for this element.
@property (nonatomic, copy) NSString *moleculeIdentifier;
/// Common uses.
@property (nonatomic, copy) NSArray<NSString *> *uses;
/// One-sentence description.
@property (nonatomic, copy) NSString *summary;

/// The category colour.
@property (nonatomic, readonly) NSColor *categoryColor;

/// "Group 14 · Period 2"
@property (nonatomic, readonly) NSString *groupPeriodDescription;

/// Covalent radius in Angstrom, with a sensible fallback for unknown values.
@property (nonatomic, readonly) double covalentRadiusInAngstrom;

/// YES when the element is metallic in the everyday sense.
@property (nonatomic, readonly) BOOL isMetal;

@end

NS_ASSUME_NONNULL_END
