//
//  PTMolecule.m
//  PeriodicTable
//

#import "PTMolecule.h"

@implementation PTMoleculeAtom

- (NSString *)description {
    return [NSString stringWithFormat:@"<PTMoleculeAtom %@>", self.symbol];
}

@end

@implementation PTMoleculeBond

- (NSString *)description {
    return [NSString stringWithFormat:@"<PTMoleculeBond %ld-%ld>", (long)self.fromIndex, (long)self.toIndex];
}

@end

@implementation PTMolecule

- (double)boundingRadius {
    double maximum = 0.0;
    for (PTMoleculeAtom *atom in self.atoms) {
        double distance = PTVec3Length(atom.position);
        if (distance > maximum) { maximum = distance; }
    }
    return maximum;
}

- (NSString *)subtitle {
    NSUInteger atomCount = self.atoms.count;
    NSUInteger bondCount = self.bonds.count;
    return [NSString stringWithFormat:@"%@ · %@ · %lu atom%@ · %lu bond%@",
            self.displayName,
            self.formula,
            (unsigned long)atomCount,
            atomCount == 1 ? @"" : @"s",
            (unsigned long)bondCount,
            bondCount == 1 ? @"" : @"s"];
}

@end
