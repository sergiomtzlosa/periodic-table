//
//  PTElementStore.m
//  PeriodicTable
//

#import "PTElementStore.h"
#import "PTMoleculeLibrary.h"

@interface PTElementStore ()
@property (nonatomic, copy) NSArray<PTElement *> *allElements;
@property (nonatomic, copy) NSArray<PTMolecule *> *allMolecules;
@property (nonatomic, strong) PTMoleculeLibrary *library;
@end

@implementation PTElementStore

/// JSON `null` is parsed as NSNull, which does not behave like a missing value.
/// Everything optional therefore goes through here so it really is nil.
static id PTNullableValue(id value) {
    if (value == nil || value == (id)[NSNull null]) { return nil; }
    return value;
}

+ (instancetype)sharedStore {
    static PTElementStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[PTElementStore alloc] init];
    });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    NSDictionary *payload = [self loadPayload];
    NSArray<NSDictionary *> *elementDicts = payload[@"elements"] ?: @[];
    NSArray<NSDictionary *> *moleculeDicts = payload[@"molecules"] ?: @[];
    NSDictionary *explicitCoordinates = payload[@"explicitCoordinates"];

    NSMutableArray<PTElement *> *elements = [NSMutableArray arrayWithCapacity:elementDicts.count];
    for (NSDictionary *dict in elementDicts) {
        PTElement *element = [[PTElement alloc] init];
        element.atomicNumber = [dict[@"number"] integerValue];
        element.symbol = dict[@"symbol"] ?: @"";
        element.name = dict[@"name"] ?: @"";
        element.atomicMass = [dict[@"mass"] doubleValue];
        element.category = [PTElementCategories categoryFromString:dict[@"category"]];
        element.group = [dict[@"group"] integerValue];
        element.period = [dict[@"period"] integerValue];
        element.fBlock = [dict[@"fBlock"] boolValue];
        element.configuration = dict[@"configuration"] ?: @"";
        element.shells = dict[@"shells"] ?: @[];
        element.electronegativity = PTNullableValue(dict[@"electronegativity"]);
        element.atomicRadius = PTNullableValue(dict[@"atomicRadius"]);
        element.covalentRadius = PTNullableValue(dict[@"covalentRadius"]);
        element.meltingPoint = PTNullableValue(dict[@"meltingPoint"]);
        element.boilingPoint = PTNullableValue(dict[@"boilingPoint"]);
        element.density = PTNullableValue(dict[@"density"]);
        element.phase = dict[@"phase"] ?: @"Unknown";
        element.discoveryYear = dict[@"discoveryYear"] ?: @"";
        element.discoverer = dict[@"discoverer"] ?: @"";
        element.moleculeIdentifier = dict[@"molecule"] ?: @"";
        element.uses = dict[@"uses"] ?: @[];
        element.summary = dict[@"summary"] ?: @"";
        [elements addObject:element];
    }
    self.allElements = elements;

    self.library = [[PTMoleculeLibrary alloc] initWithElements:elements
                                                 moleculeSpecs:moleculeDicts
                                          explicitCoordinates:explicitCoordinates];

    NSMutableArray<PTMolecule *> *molecules = [NSMutableArray array];
    for (NSString *identifier in self.library.allIdentifiers) {
        PTMolecule *molecule = [self.library moleculeWithIdentifier:identifier];
        if (molecule) { [molecules addObject:molecule]; }
    }
    self.allMolecules = molecules;

    return self;
}

- (NSDictionary *)loadPayload {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"elements" withExtension:@"json"];
    if (url == nil) {
        NSLog(@"[PTElementStore] elements.json is missing from the app bundle.");
        return @{};
    }

    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    if (data == nil) {
        NSLog(@"[PTElementStore] could not read elements.json: %@", error.localizedDescription);
        return @{};
    }

    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[PTElementStore] elements.json is not a JSON object: %@", error.localizedDescription);
        return @{};
    }
    return parsed;
}

- (nullable PTElement *)elementWithAtomicNumber:(NSInteger)atomicNumber {
    if (atomicNumber < 1 || atomicNumber > (NSInteger)self.allElements.count) { return nil; }
    return self.allElements[atomicNumber - 1];
}

- (nullable PTElement *)elementWithSymbol:(nullable NSString *)symbol {
    if (symbol.length == 0) { return nil; }
    for (PTElement *element in self.allElements) {
        if ([element.symbol isEqualToString:symbol]) { return element; }
    }
    return nil;
}

- (nullable PTMolecule *)moleculeForElement:(nullable PTElement *)element {
    if (element == nil) { return nil; }
    PTMolecule *molecule = [self.library moleculeWithIdentifier:element.moleculeIdentifier];
    if (molecule) { return molecule; }

    // Fall back to a single atom of the element so the 3D view is never empty.
    PTMoleculeAtom *atom = [[PTMoleculeAtom alloc] init];
    atom.symbol = element.symbol;
    atom.elementName = element.name;
    atom.radius = element.covalentRadiusInAngstrom;
    atom.metal = element.isMetal;
    atom.position = PTVec3Make(0, 0, 0);

    PTMolecule *fallback = [[PTMolecule alloc] init];
    fallback.identifier = element.moleculeIdentifier.length ? element.moleculeIdentifier : element.symbol;
    fallback.displayName = [NSString stringWithFormat:@"%@ atom", element.name];
    fallback.formula = element.symbol;
    fallback.details = element.summary;
    fallback.atoms = @[atom];
    fallback.bonds = @[];
    return fallback;
}

@end
