//
//  PTElementStore.h
//  PeriodicTable
//

#import <Foundation/Foundation.h>
#import "PTElement.h"
#import "PTMolecule.h"

NS_ASSUME_NONNULL_BEGIN

/// Loads and owns the element + molecule data.  Parsed once, then cached.
@interface PTElementStore : NSObject

+ (instancetype)sharedStore;

/// Every element, ordered by atomic number.
@property (nonatomic, readonly) NSArray<PTElement *> *allElements;

/// Every molecule in the library.
@property (nonatomic, readonly) NSArray<PTMolecule *> *allMolecules;

- (nullable PTElement *)elementWithAtomicNumber:(NSInteger)atomicNumber;
- (nullable PTElement *)elementWithSymbol:(nullable NSString *)symbol;

/// The molecule that represents the given element in 3D, or nil.
- (nullable PTMolecule *)moleculeForElement:(nullable PTElement *)element;

@end

NS_ASSUME_NONNULL_END
