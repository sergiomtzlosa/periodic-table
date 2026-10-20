//
//  PTMoleculeLibrary.m
//  PeriodicTable
//

#import "PTMoleculeLibrary.h"

static const double kPi = 3.14159265358979323846;

@interface PTMoleculeLibrary ()
@property (nonatomic, copy) NSDictionary<NSString *, PTElement *> *elementsBySymbol;
@property (nonatomic, strong) NSDictionary<NSString *, PTMolecule *> *moleculesByIdentifier;
@end

@implementation PTMoleculeLibrary

- (instancetype)initWithElements:(NSArray<PTElement *> *)elements
                    moleculeSpecs:(NSArray<NSDictionary *> *)moleculeSpecs
             explicitCoordinates:(nullable NSDictionary<NSString *, NSArray<NSArray<NSNumber *> *> *> *)explicitCoordinates {
    self = [super init];
    if (!self) { return nil; }

    NSMutableDictionary<NSString *, PTElement *> *bySymbol = [NSMutableDictionary dictionary];
    for (PTElement *element in elements) {
        bySymbol[element.symbol] = element;
    }
    self.elementsBySymbol = bySymbol;

    NSMutableDictionary<NSString *, PTMolecule *> *molecules = [NSMutableDictionary dictionary];
    for (NSDictionary *spec in moleculeSpecs) {
        NSString *identifier = spec[@"identifier"];
        if (identifier.length == 0) { continue; }
        PTMolecule *molecule = [self moleculeFromSpecification:spec
                                            explicitCoordinates:explicitCoordinates];
        if (molecule) { molecules[identifier] = molecule; }
    }
    self.moleculesByIdentifier = molecules;

    return self;
}

- (NSArray<NSString *> *)allIdentifiers {
    return self.moleculesByIdentifier.allKeys;
}

- (nullable PTMolecule *)moleculeWithIdentifier:(nullable NSString *)identifier {
    if (identifier.length == 0) { return nil; }
    return self.moleculesByIdentifier[identifier];
}

#pragma mark - Building

- (nullable PTMolecule *)moleculeFromSpecification:(NSDictionary *)spec
                                explicitCoordinates:(nullable NSDictionary<NSString *, NSArray<NSArray<NSNumber *> *> *> *)explicitCoordinates {
    NSString *identifier = spec[@"identifier"];
    NSString *geometry = spec[@"geometry"] ?: @"monatomic";
    NSArray<NSString *> *symbols = spec[@"atoms"] ?: @[];

    if (symbols.count == 0) { return nil; }

    NSMutableArray<PTMoleculeAtom *> *atoms = [NSMutableArray arrayWithCapacity:symbols.count];
    for (NSString *symbol in symbols) {
        PTMoleculeAtom *atom = [[PTMoleculeAtom alloc] init];
        atom.symbol = symbol;
        PTElement *element = self.elementsBySymbol[symbol];
        atom.elementName = element.name ?: symbol;
        atom.radius = element ? element.covalentRadiusInAngstrom : 0.80;
        atom.metal = element ? element.isMetal : NO;
        [atoms addObject:atom];
    }

    NSMutableArray<PTMoleculeBond *> *bonds = [NSMutableArray array];
    NSArray<NSString *> *bondSpecs = spec[@"bonds"] ?: @[];
    NSDictionary<NSString *, NSNumber *> *orderSpecs = spec[@"bondOrders"] ?: @{};

    if ([geometry isEqualToString:@"explicit"]) {
        NSArray<NSArray<NSNumber *> *> *points = explicitCoordinates[identifier];
        if (points.count == atoms.count) {
            for (NSUInteger i = 0; i < atoms.count; i++) {
                NSArray<NSNumber *> *p = points[i];
                atoms[i].position = PTVec3Make(p[0].doubleValue, p[1].doubleValue, p[2].doubleValue);
            }
        } else {
            geometry = @"monatomic";
        }
    }

    if (![geometry isEqualToString:@"explicit"]) {
        [self applyGeometry:geometry toAtoms:atoms bonds:bonds];
    }

    // Explicit bond lists (from the data file) always win over generated ones.
    if (bondSpecs.count > 0) {
        [bonds removeAllObjects];
        for (NSUInteger i = 0; i < bondSpecs.count; i++) {
            NSArray<NSString *> *pair = [bondSpecs[i] componentsSeparatedByString:@"-"];
            if (pair.count != 2) { continue; }
            PTMoleculeBond *bond = [[PTMoleculeBond alloc] init];
            bond.fromIndex = pair[0].integerValue;
            bond.toIndex = pair[1].integerValue;
            bond.order = orderSpecs[@(i).stringValue].integerValue ?: 1;
            [bonds addObject:bond];
        }
    } else {
        NSUInteger i = 0;
        for (PTMoleculeBond *bond in bonds) {
            bond.order = orderSpecs[@(i).stringValue].integerValue ?: 1;
            i++;
        }
    }

    // Guard against out-of-range bonds.
    NSMutableArray<PTMoleculeBond *> *validBonds = [NSMutableArray array];
    for (PTMoleculeBond *bond in bonds) {
        if (bond.fromIndex < 0 || bond.toIndex < 0) { continue; }
        if (bond.fromIndex >= (NSInteger)atoms.count || bond.toIndex >= (NSInteger)atoms.count) { continue; }
        if (bond.fromIndex == bond.toIndex) { continue; }
        [validBonds addObject:bond];
    }

    PTMolecule *molecule = [[PTMolecule alloc] init];
    molecule.identifier = identifier;
    molecule.displayName = spec[@"name"] ?: identifier;
    molecule.formula = spec[@"formula"] ?: @"";
    molecule.details = spec[@"details"] ?: @"";
    molecule.atoms = atoms;
    molecule.bonds = validBonds;

    return molecule;
}

- (void)applyGeometry:(NSString *)geometry
                toAtoms:(NSMutableArray<PTMoleculeAtom *> *)atoms
                  bonds:(NSMutableArray<PTMoleculeBond *> *)bonds {
    NSUInteger count = atoms.count;
    if (count == 0) { return; }

    if ([geometry isEqualToString:@"monatomic"]) {
        atoms[0].position = PTVec3Make(0, 0, 0);
        return;
    }

    if ([geometry isEqualToString:@"diatomic"] && count >= 2) {
        double d = [self bondLengthFrom:0 to:1 inAtoms:atoms];
        atoms[0].position = PTVec3Make(-d / 2.0, 0, 0);
        atoms[1].position = PTVec3Make(d / 2.0, 0, 0);
        [bonds addObject:[self bondFrom:0 to:1]];
        return;
    }

    if ([geometry isEqualToString:@"linear"] && count >= 2) {
        atoms[0].position = PTVec3Make(0, 0, 0);
        NSUInteger positive = 0, negative = 0;
        for (NSUInteger i = 1; i < count; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            if (i % 2 == 1) {
                atoms[i].position = PTVec3Make(d, 0, 0);
                positive++;
            } else {
                atoms[i].position = PTVec3Make(-d, 0, 0);
                negative++;
            }
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        (void)positive; (void)negative;
        return;
    }

    if ([geometry isEqualToString:@"bent"] && count >= 3) {
        const double angle = 107.0 * kPi / 180.0;
        atoms[0].position = PTVec3Make(0, 0, 0);
        for (NSUInteger i = 1; i < count && i <= 2; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            double sign = (i == 1) ? 1.0 : -1.0;
            double theta = sign * angle / 2.0;
            atoms[i].position = PTVec3Make(d * cos(theta), d * sin(theta), 0);
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        return;
    }

    if ([geometry isEqualToString:@"planar-trigonal"] && count >= 4) {
        atoms[0].position = PTVec3Make(0, 0, 0);
        for (NSUInteger i = 1; i < count && i <= 3; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            double angle = (90.0 + 120.0 * (i - 1)) * kPi / 180.0;
            atoms[i].position = PTVec3Make(d * cos(angle), d * sin(angle), 0);
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        return;
    }

    if ([geometry isEqualToString:@"pyramidal"] && count >= 4) {
        const double polar = 107.0 * kPi / 180.0;
        atoms[0].position = PTVec3Make(0, 0, 0);
        for (NSUInteger i = 1; i < count && i <= 3; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            double azimuth = 90.0 * kPi / 180.0 + 120.0 * (i - 1) * kPi / 180.0;
            atoms[i].position = PTVec3Make(d * sin(polar) * cos(azimuth),
                                          d * sin(polar) * sin(azimuth),
                                          d * cos(polar));
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        return;
    }

    if ([geometry isEqualToString:@"tetrahedral"] && count >= 5) {
        static const double dirs[4][3] = {
            { 1,  1,  1}, {-1, -1,  1}, {-1,  1, -1}, { 1, -1, -1}
        };
        atoms[0].position = PTVec3Make(0, 0, 0);
        for (NSUInteger i = 1; i < count && i <= 4; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            PTVec3 direction = PTVec3Normalize(PTVec3Make(dirs[i - 1][0], dirs[i - 1][1], dirs[i - 1][2]));
            atoms[i].position = PTVec3Scale(direction, d);
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        return;
    }

    if ([geometry isEqualToString:@"octahedral"] && count >= 7) {
        static const double dirs[6][3] = {
            { 1, 0, 0}, {-1, 0, 0}, {0,  1, 0}, {0, -1, 0}, {0, 0,  1}, {0, 0, -1}
        };
        atoms[0].position = PTVec3Make(0, 0, 0);
        for (NSUInteger i = 1; i < count && i <= 6; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            atoms[i].position = PTVec3Make(dirs[i - 1][0] * d, dirs[i - 1][1] * d, dirs[i - 1][2] * d);
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        return;
    }

    if ([geometry isEqualToString:@"square-planar"] && count >= 5) {
        static const double dirs[4][3] = {
            { 1, 0, 0}, {-1, 0, 0}, {0,  1, 0}, {0, -1, 0}
        };
        atoms[0].position = PTVec3Make(0, 0, 0);
        for (NSUInteger i = 1; i < count && i <= 4; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            atoms[i].position = PTVec3Make(dirs[i - 1][0] * d, dirs[i - 1][1] * d, 0);
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        return;
    }

    if ([geometry isEqualToString:@"trigonal-bipyramidal"] && count >= 6) {
        atoms[0].position = PTVec3Make(0, 0, 0);
        for (NSUInteger i = 1; i < count && i <= 3; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            double angle = (90.0 + 120.0 * (i - 1)) * kPi / 180.0;
            atoms[i].position = PTVec3Make(d * cos(angle), d * sin(angle), 0);
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        for (NSUInteger i = 4; i < count && i <= 5; i++) {
            double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
            double sign = (i == 4) ? 1.0 : -1.0;
            atoms[i].position = PTVec3Make(0, 0, sign * d);
            [bonds addObject:[self bondFrom:0 to:i]];
        }
        return;
    }

    if ([geometry isEqualToString:@"ring"] && count >= 3) {
        double d = [self bondLengthFrom:0 to:1 inAtoms:atoms];
        double radius = d / (2.0 * sin(kPi / (double)count));
        for (NSUInteger i = 0; i < count; i++) {
            double angle = 2.0 * kPi * (double)i / (double)count;
            atoms[i].position = PTVec3Make(radius * cos(angle), radius * sin(angle), 0);
        }
        for (NSUInteger i = 0; i < count; i++) {
            [bonds addObject:[self bondFrom:i to:(i + 1) % count]];
        }
        return;
    }

    if ([geometry isEqualToString:@"ring-with-h"] && count >= 6 && count % 2 == 0) {
        NSUInteger ringCount = count / 2;
        double d = [self bondLengthFrom:0 to:1 inAtoms:atoms];
        double radius = d / (2.0 * sin(kPi / (double)ringCount));
        for (NSUInteger i = 0; i < ringCount; i++) {
            double angle = 2.0 * kPi * (double)i / (double)ringCount;
            atoms[i].position = PTVec3Make(radius * cos(angle), radius * sin(angle), 0);
        }
        for (NSUInteger i = ringCount; i < count; i++) {
            NSUInteger ringIndex = i - ringCount;
            PTVec3 base = atoms[ringIndex].position;
            PTVec3 outward = PTVec3Normalize(base);
            double d2 = [self bondLengthFrom:ringIndex to:i inAtoms:atoms];
            atoms[i].position = PTVec3Add(base, PTVec3Scale(outward, d2));
        }
        for (NSUInteger i = 0; i < ringCount; i++) {
            [bonds addObject:[self bondFrom:i to:(i + 1) % ringCount]];
        }
        for (NSUInteger i = 0; i < ringCount; i++) {
            [bonds addObject:[self bondFrom:i to:(i + ringCount)]];
        }
        return;
    }

    if ([geometry isEqualToString:@"tetrahedron4"] && count == 4) {
        static const double dirs[4][3] = {
            { 1,  1,  1}, {-1, -1,  1}, {-1,  1, -1}, { 1, -1, -1}
        };
        double d = [self bondLengthFrom:0 to:1 inAtoms:atoms];
        double radius = d * sqrt(6.0) / 4.0;
        for (NSUInteger i = 0; i < 4; i++) {
            PTVec3 direction = PTVec3Normalize(PTVec3Make(dirs[i][0], dirs[i][1], dirs[i][2]));
            atoms[i].position = PTVec3Scale(direction, radius);
        }
        for (NSUInteger i = 0; i < 4; i++) {
            for (NSUInteger j = i + 1; j < 4; j++) {
                [bonds addObject:[self bondFrom:i to:j]];
            }
        }
        return;
    }

    if ([geometry isEqualToString:@"cubic-na"] && count >= 2) {
        // A 3x3x3 rock-salt unit cell: the two species alternate along each axis.
        PTMoleculeAtom *cation = atoms[0];
        PTMoleculeAtom *anion = atoms[1];
        double spacing = MAX(1.2, [self bondLengthFrom:0 to:1 inAtoms:atoms]);

        [atoms removeAllObjects];
        NSMutableArray<NSValue *> *positions = [NSMutableArray array];

        for (NSInteger i = 0; i < 3; i++) {
            for (NSInteger j = 0; j < 3; j++) {
                for (NSInteger k = 0; k < 3; k++) {
                    BOOL even = (((i + j + k) % 2) + 2) % 2 == 0;
                    PTMoleculeAtom *source = even ? cation : anion;
                    PTMoleculeAtom *atom = [[PTMoleculeAtom alloc] init];
                    atom.symbol = source.symbol;
                    atom.elementName = source.elementName;
                    atom.radius = source.radius;
                    atom.metal = source.metal;
                    atom.position = PTVec3Make((i - 1) * spacing, (j - 1) * spacing, (k - 1) * spacing);
                    [atoms addObject:atom];
                    PTVec3 position = atom.position;
                    [positions addObject:[NSValue valueWithBytes:&position objCType:@encode(PTVec3)]];
                }
            }
        }

        // Connect nearest neighbours of opposite type.
        for (NSUInteger i = 0; i < positions.count; i++) {
            for (NSUInteger j = i + 1; j < positions.count; j++) {
                PTVec3 a, b;
                [positions[i] getValue:&a];
                [positions[j] getValue:&b];
                if (fabs(PTVec3Distance(a, b) - spacing) < 0.01) {
                    [bonds addObject:[self bondFrom:(NSInteger)i to:(NSInteger)j]];
                }
            }
        }
        return;
    }

    if ([geometry isEqualToString:@"cubic-cs"] && count >= 2) {
        // The caesium-chloride structure: eight corners plus one at the centre.
        PTMoleculeAtom *corner = atoms[0];
        PTMoleculeAtom *centre = atoms[1];
        double radius = MAX(1.2, [self bondLengthFrom:0 to:1 inAtoms:atoms]) * 1.25;

        static const double signs[8][3] = {
            { 1,  1,  1}, { 1,  1, -1}, { 1, -1,  1}, { 1, -1, -1},
            {-1,  1,  1}, {-1,  1, -1}, {-1, -1,  1}, {-1, -1, -1}
        };

        [atoms removeAllObjects];
        for (NSUInteger i = 0; i < 8; i++) {
            PTMoleculeAtom *atom = [[PTMoleculeAtom alloc] init];
            atom.symbol = corner.symbol;
            atom.elementName = corner.elementName;
            atom.radius = corner.radius;
            atom.metal = corner.metal;
            atom.position = PTVec3Make(signs[i][0] * radius, signs[i][1] * radius, signs[i][2] * radius);
            [atoms addObject:atom];
        }

        PTMoleculeAtom *middle = [[PTMoleculeAtom alloc] init];
        middle.symbol = centre.symbol;
        middle.elementName = centre.elementName;
        middle.radius = centre.radius;
        middle.metal = centre.metal;
        middle.position = PTVec3Make(0, 0, 0);
        [atoms addObject:middle];

        for (NSUInteger i = 0; i < 8; i++) {
            [bonds addObject:[self bondFrom:(NSInteger)i to:8]];
        }
        return;
    }

    // Unknown geometry: lay the atoms out in a gentle zig-zag so something sensible shows.
    atoms[0].position = PTVec3Make(0, 0, 0);
    for (NSUInteger i = 1; i < count; i++) {
        double d = [self bondLengthFrom:0 to:i inAtoms:atoms];
        atoms[i].position = PTVec3Make(d, (i % 2 ? 0.35 : -0.35) * d, 0);
        [bonds addObject:[self bondFrom:0 to:i]];
    }
}

#pragma mark - Helpers

- (double)bondLengthFrom:(NSInteger)i to:(NSInteger)j inAtoms:(NSArray<PTMoleculeAtom *> *)atoms {
    double a = (i >= 0 && i < (NSInteger)atoms.count) ? atoms[i].radius : 0.8;
    double b = (j >= 0 && j < (NSInteger)atoms.count) ? atoms[j].radius : 0.8;
    return MAX(0.90, a + b);
}

- (PTMoleculeBond *)bondFrom:(NSInteger)from to:(NSInteger)to {
    PTMoleculeBond *bond = [[PTMoleculeBond alloc] init];
    bond.fromIndex = from;
    bond.toIndex = to;
    bond.order = 1;
    return bond;
}

@end
