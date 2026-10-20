//
//  PTMoleculeSceneBuilder.m
//  PeriodicTable
//

#import "PTMoleculeSceneBuilder.h"
#import "PTElementCategories.h"
#import <simd/simd.h>
#import <objc/runtime.h>

static const double kTwoPi = 6.28318530717958647692;
static const double kPiOverThree = 1.04719755119659774615;

/// Scene units are Angstrom.
static const double kAtomScale = 0.42;
static const double kBondRadius = 0.075;

/// The camera's vertical field of view, in degrees.
static const CGFloat kCameraFieldOfView = 42.0;

/// How much empty space to leave around the subject.
static const double kMoleculeMargin = 1.16;
static const double kAtomMargin = 1.10;


static NSString * const kCameraNodeName = @"PTCamera";
static NSString * const kContentNodeName = @"PTContent";

/// Stores the radius the scene was framed with, so it can be re-fitted later.
static const void *kPTFitRadiusKey = &kPTFitRadiusKey;
/// The margin that was used when the scene was first framed.
static const void *kPTFitMarginKey = &kPTFitMarginKey;

/// A quaternion that rotates the +Y axis onto the given direction.
static simd_quatf PTQuaternionFromYAxisToVector(simd_float3 direction) {
    simd_float3 from = simd_make_float3(0.0f, 1.0f, 0.0f);
    simd_float3 to = simd_normalize(direction);
    return simd_quaternion(from, to);
}

@implementation PTMoleculeSceneBuilder

#pragma mark - Framing maths

/// The distance the camera has to sit from a sphere of the given radius so the
/// sphere fits inside the frustum, for both the vertical and horizontal field of view.
+ (double)fitDistanceForRadius:(double)radius viewportSize:(NSSize)size margin:(double)margin {
    if (radius <= 0.0) { return 6.0; }

    double halfVertical = (kCameraFieldOfView * M_PI / 180.0) / 2.0;
    double aspect = (size.height > 1.0) ? ((double)size.width / (double)size.height) : 1.0;
    double halfHorizontal = atan(tan(halfVertical) * aspect);
    double half = MIN(halfVertical, halfHorizontal);
    if (half < 0.02) { half = halfVertical; }

    return (radius / sin(half)) * margin;
}

+ (void)rememberFitRadius:(double)radius margin:(double)margin forScene:(SCNScene *)scene {
    objc_setAssociatedObject(scene, kPTFitRadiusKey, @(radius), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(scene, kPTFitMarginKey, @(margin), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (double)fitMarginForScene:(SCNScene *)scene {
    NSNumber *value = objc_getAssociatedObject(scene, kPTFitMarginKey);
    return value ? value.doubleValue : kMoleculeMargin;
}

+ (double)fitRadiusForScene:(SCNScene *)scene {
    NSNumber *value = objc_getAssociatedObject(scene, kPTFitRadiusKey);
    return value ? value.doubleValue : 0.0;
}

+ (nullable SCNNode *)cameraNodeInScene:(SCNScene *)scene {
    __block SCNNode *found = nil;
    [scene.rootNode enumerateChildNodesUsingBlock:^(SCNNode *child, BOOL *stop) {
        if ([child.name isEqualToString:kCameraNodeName]) { found = child; *stop = YES; }
    }];
    return found;
}

+ (void)frameScene:(nullable SCNScene *)scene viewportSize:(NSSize)viewportSize {
    if (scene == nil) { return; }

    SCNNode *camera = [self cameraNodeInScene:scene];
    if (camera == nil) { return; }

    double radius = [self fitRadiusForScene:scene];
    if (radius <= 0.0) { return; }

    // Keep the direction the user has orbited to, only correct the distance.
    simd_float3 current = camera.simdPosition;
    simd_float3 offset = simd_make_float3(current.x, current.y, current.z);
    double currentDistance = simd_length(offset);
    simd_float3 direction = (currentDistance > 0.001)
        ? simd_normalize(offset)
        : simd_make_float3(0.0f, 0.0f, 1.0f);

    double margin = [self fitMarginForScene:scene];
    double distance = [self fitDistanceForRadius:radius viewportSize:viewportSize margin:margin];

    camera.simdPosition = simd_make_float3(direction.x * (float)distance,
                                           direction.y * (float)distance,
                                           direction.z * (float)distance);
}

#pragma mark - Shared

+ (void)addLightsToScene:(SCNScene *)scene {
    SCNNode *ambient = [[SCNNode alloc] init];
    ambient.light = [SCNLight light];
    ambient.light.type = SCNLightTypeAmbient;
    ambient.light.intensity = 500;
    ambient.light.color = [NSColor colorWithWhite:0.78 alpha:1.0];
    [scene.rootNode addChildNode:ambient];

    SCNNode *key = [[SCNNode alloc] init];
    key.light = [SCNLight light];
    key.light.type = SCNLightTypeOmni;
    key.light.intensity = 1400;
    key.light.attenuationStartDistance = 1.0;
    key.light.attenuationEndDistance = 60.0;
    key.light.color = [NSColor colorWithSRGBRed:1.0 green:0.97 blue:0.92 alpha:1.0];
    key.position = SCNVector3Make(6, 7, 9);
    [scene.rootNode addChildNode:key];

    SCNNode *fill = [[SCNNode alloc] init];
    fill.light = [SCNLight light];
    fill.light.type = SCNLightTypeOmni;
    fill.light.intensity = 900;
    fill.light.attenuationStartDistance = 1.0;
    fill.light.attenuationEndDistance = 60.0;
    fill.light.color = [NSColor colorWithSRGBRed:0.55 green:0.70 blue:1.0 alpha:1.0];
    fill.position = SCNVector3Make(-8, -4, 6);
    [scene.rootNode addChildNode:fill];

    SCNNode *rim = [[SCNNode alloc] init];
    rim.light = [SCNLight light];
    rim.light.type = SCNLightTypeDirectional;
    rim.light.intensity = 320;
    rim.light.color = [NSColor colorWithSRGBRed:0.75 green:0.85 blue:1.0 alpha:1.0];
    rim.eulerAngles = SCNVector3Make(-kPiOverThree, M_PI_4, 0);
    [scene.rootNode addChildNode:rim];
}

+ (SCNNode *)cameraNodeLookingAtNode:(SCNNode *)target distance:(double)distance {
    SCNNode *camera = [[SCNNode alloc] init];
    camera.name = kCameraNodeName;
    camera.camera = [SCNCamera camera];
    camera.camera.fieldOfView = kCameraFieldOfView;
    camera.position = SCNVector3Make(0, 0, distance);
    camera.constraints = @[[SCNLookAtConstraint lookAtConstraintWithTarget:target]];
    return camera;
}

+ (SCNMaterial *)materialForElementSymbol:(NSString *)symbol metal:(BOOL)metal {
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelPhysicallyBased;
    material.diffuse.contents = [self colorForSymbol:symbol];
    material.roughness.contents = metal ? @(0.30) : @(0.12);
    material.metalness.contents = metal ? @(0.85) : @(0.10);
    material.locksAmbientWithDiffuse = YES;
    return material;
}

+ (SCNMaterial *)flatMaterialWithColor:(NSColor *)color {
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelConstant;
    material.diffuse.contents = color;
    return material;
}

/// CPK-style colour for an element symbol.
+ (NSColor *)colorForSymbol:(NSString *)symbol {
    static NSDictionary<NSString *, NSColor *> *palette = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        palette = @{
            @"H":  [NSColor colorWithSRGBRed:0.95 green:0.95 blue:0.95 alpha:1.0],
            @"He": [NSColor colorWithSRGBRed:0.85 green:0.95 blue:1.00 alpha:1.0],
            @"Li": [NSColor colorWithSRGBRed:0.80 green:0.50 blue:1.00 alpha:1.0],
            @"Be": [NSColor colorWithSRGBRed:0.76 green:1.00 blue:0.00 alpha:1.0],
            @"B":  [NSColor colorWithSRGBRed:1.00 green:0.71 blue:0.71 alpha:1.0],
            @"C":  [NSColor colorWithSRGBRed:0.32 green:0.32 blue:0.32 alpha:1.0],
            @"N":  [NSColor colorWithSRGBRed:0.19 green:0.31 blue:0.97 alpha:1.0],
            @"O":  [NSColor colorWithSRGBRed:1.00 green:0.05 blue:0.05 alpha:1.0],
            @"F":  [NSColor colorWithSRGBRed:0.56 green:0.88 blue:0.31 alpha:1.0],
            @"Ne": [NSColor colorWithSRGBRed:0.70 green:0.89 blue:0.96 alpha:1.0],
            @"Na": [NSColor colorWithSRGBRed:0.67 green:0.36 blue:0.95 alpha:1.0],
            @"Mg": [NSColor colorWithSRGBRed:0.54 green:1.00 blue:0.00 alpha:1.0],
            @"Al": [NSColor colorWithSRGBRed:0.75 green:0.65 blue:0.65 alpha:1.0],
            @"Si": [NSColor colorWithSRGBRed:0.94 green:0.78 blue:0.63 alpha:1.0],
            @"P":  [NSColor colorWithSRGBRed:1.00 green:0.50 blue:0.00 alpha:1.0],
            @"S":  [NSColor colorWithSRGBRed:1.00 green:1.00 blue:0.19 alpha:1.0],
            @"Cl": [NSColor colorWithSRGBRed:0.12 green:0.94 blue:0.12 alpha:1.0],
            @"Ar": [NSColor colorWithSRGBRed:0.50 green:0.82 blue:0.89 alpha:1.0],
            @"K":  [NSColor colorWithSRGBRed:0.56 green:0.25 blue:0.83 alpha:1.0],
            @"Ca": [NSColor colorWithSRGBRed:0.24 green:1.00 blue:0.00 alpha:1.0],
            @"Sc": [NSColor colorWithSRGBRed:0.90 green:0.90 blue:0.90 alpha:1.0],
            @"Ti": [NSColor colorWithSRGBRed:0.75 green:0.76 blue:0.78 alpha:1.0],
            @"V":  [NSColor colorWithSRGBRed:0.65 green:0.65 blue:0.67 alpha:1.0],
            @"Cr": [NSColor colorWithSRGBRed:0.54 green:0.60 blue:0.78 alpha:1.0],
            @"Mn": [NSColor colorWithSRGBRed:0.61 green:0.48 blue:0.78 alpha:1.0],
            @"Fe": [NSColor colorWithSRGBRed:0.88 green:0.40 blue:0.20 alpha:1.0],
            @"Co": [NSColor colorWithSRGBRed:0.94 green:0.56 blue:0.63 alpha:1.0],
            @"Ni": [NSColor colorWithSRGBRed:0.31 green:0.82 blue:0.31 alpha:1.0],
            @"Cu": [NSColor colorWithSRGBRed:0.78 green:0.50 blue:0.20 alpha:1.0],
            @"Zn": [NSColor colorWithSRGBRed:0.49 green:0.50 blue:0.69 alpha:1.0],
            @"Ga": [NSColor colorWithSRGBRed:0.76 green:0.56 blue:0.56 alpha:1.0],
            @"Ge": [NSColor colorWithSRGBRed:0.40 green:0.56 blue:0.56 alpha:1.0],
            @"As": [NSColor colorWithSRGBRed:0.74 green:0.50 blue:0.89 alpha:1.0],
            @"Se": [NSColor colorWithSRGBRed:1.00 green:0.63 blue:0.00 alpha:1.0],
            @"Br": [NSColor colorWithSRGBRed:0.65 green:0.16 blue:0.16 alpha:1.0],
            @"Kr": [NSColor colorWithSRGBRed:0.36 green:0.72 blue:0.82 alpha:1.0],
            @"Ag": [NSColor colorWithSRGBRed:0.75 green:0.75 blue:0.75 alpha:1.0],
            @"Au": [NSColor colorWithSRGBRed:1.00 green:0.82 blue:0.14 alpha:1.0],
            @"Hg": [NSColor colorWithSRGBRed:0.72 green:0.72 blue:0.82 alpha:1.0],
            @"Pb": [NSColor colorWithSRGBRed:0.34 green:0.35 blue:0.38 alpha:1.0],
            @"U":  [NSColor colorWithSRGBRed:0.00 green:0.56 blue:0.00 alpha:1.0],
        };
    });
    NSColor *color = palette[symbol];
    if (color) { return color; }
    // Fall back to a stable pastel derived from the symbol.
    NSUInteger hash = symbol.hash;
    CGFloat hue = (CGFloat)(hash % 360) / 360.0;
    return [NSColor colorWithHue:hue saturation:0.35 brightness:0.85 alpha:1.0];
}

#pragma mark - Molecule scene

+ (SCNScene *)moleculeSceneForMolecule:(nullable PTMolecule *)molecule
                           viewportSize:(NSSize)viewportSize {
    SCNScene *scene = [SCNScene scene];
    scene.background.contents = [NSColor colorWithSRGBRed:0.055 green:0.065 blue:0.09 alpha:1.0];

    SCNNode *root = [[SCNNode alloc] init];
    root.name = kContentNodeName;
    [scene.rootNode addChildNode:root];

    if (molecule == nil || molecule.atoms.count == 0) {
        [self addLightsToScene:scene];
        [self rememberFitRadius:1.5 margin:kMoleculeMargin forScene:scene];
        SCNNode *camera = [self cameraNodeLookingAtNode:root
                                                 distance:[self fitDistanceForRadius:1.5
                                                                     viewportSize:viewportSize
                                                                          margin:kMoleculeMargin]];
        [scene.rootNode addChildNode:camera];
        return scene;
    }

    // ---- Atoms ------------------------------------------------------------
    NSMutableArray<SCNNode *> *atomNodes = [NSMutableArray array];
    NSMutableArray<NSNumber *> *atomRadii = [NSMutableArray array];
    for (PTMoleculeAtom *atom in molecule.atoms) {
        double radius = MAX(0.18, atom.radius * kAtomScale);
        SCNSphere *sphere = [SCNSphere sphereWithRadius:radius];
        sphere.segmentCount = 48;
        sphere.materials = @[[self materialForElementSymbol:atom.symbol metal:atom.isMetal]];

        SCNNode *node = [[SCNNode alloc] init];
        node.geometry = sphere;
        node.position = SCNVector3Make(atom.position.x, atom.position.y, atom.position.z);
        [root addChildNode:node];
        [atomNodes addObject:node];
        [atomRadii addObject:@(radius)];
    }

    // ---- Centre the molecule on its own bounding sphere --------------------
    // Spinning about the geometric centre looks right, and it lets the camera
    // simply sit on the +Z axis.
    double minX = DBL_MAX, maxX = -DBL_MAX, minY = DBL_MAX, maxY = -DBL_MAX;
    double minZ = DBL_MAX, maxZ = -DBL_MAX;
    for (NSUInteger i = 0; i < atomNodes.count; i++) {
        SCNVector3 p = atomNodes[i].position;
        double r = atomRadii[i].doubleValue;
        minX = MIN(minX, p.x - r); maxX = MAX(maxX, p.x + r);
        minY = MIN(minY, p.y - r); maxY = MAX(maxY, p.y + r);
        minZ = MIN(minZ, p.z - r); maxZ = MAX(maxZ, p.z + r);
    }
    double centreX = (minX + maxX) / 2.0;
    double centreY = (minY + maxY) / 2.0;
    double centreZ = (minZ + maxZ) / 2.0;

    double fitRadius = 0.0;
    for (NSUInteger i = 0; i < atomNodes.count; i++) {
        SCNNode *node = atomNodes[i];
        node.position = SCNVector3Make(node.position.x - centreX,
                                       node.position.y - centreY,
                                       node.position.z - centreZ);
        double distance = simd_length(simd_make_float3((float)node.position.x,
                                                       (float)node.position.y,
                                                       (float)node.position.z));
        fitRadius = MAX(fitRadius, distance + atomRadii[i].doubleValue);
    }

    // ---- Bonds -------------------------------------------------------------
    for (PTMoleculeBond *bond in molecule.bonds) {
        if (bond.fromIndex < 0 || bond.fromIndex >= (NSInteger)atomNodes.count) { continue; }
        if (bond.toIndex < 0 || bond.toIndex >= (NSInteger)atomNodes.count) { continue; }

        SCNVector3 a = atomNodes[bond.fromIndex].position;
        SCNVector3 b = atomNodes[bond.toIndex].position;
        simd_float3 delta = simd_make_float3(b.x - a.x, b.y - a.y, b.z - a.z);
        float length = simd_length(delta);
        if (length < 0.001f) { continue; }

        double radius = kBondRadius * (1.0 + 0.18 * (double)(bond.order - 1));
        SCNCylinder *cylinder = [SCNCylinder cylinderWithRadius:radius height:length * 0.92];
        cylinder.radialSegmentCount = 24;

        SCNMaterial *bondMaterial = [SCNMaterial material];
        bondMaterial.lightingModelName = SCNLightingModelPhysicallyBased;
        bondMaterial.diffuse.contents = [NSColor colorWithWhite:0.86 alpha:1.0];
        bondMaterial.roughness.contents = @(0.35);
        bondMaterial.metalness.contents = @(0.35);
        cylinder.materials = @[bondMaterial];

        SCNNode *node = [[SCNNode alloc] init];
        node.geometry = cylinder;
        node.position = SCNVector3Make((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, (a.z + b.z) / 2.0);
        node.simdOrientation = PTQuaternionFromYAxisToVector(delta);

        [root addChildNode:node];
    }

    // ---- Animation ---------------------------------------------------------
    // The molecule turns as one rigid body and gently "breathes" by scaling.
    // Animating the atoms individually would tear the bonds off them, so the
    // whole group moves together instead.
    SCNAction *spin = [SCNAction repeatActionForever:[SCNAction rotateByAngle:(CGFloat)kTwoPi
                                                          aroundAxis:SCNVector3Make(0, 1, 0)
                                                             duration:16.0]];
    [root runAction:spin];

    // Only one smooth rotation.  A second, slower rotation on another axis plus
    // a pulsing scale made the model look like it was trembling rather than
    // turning, so the animation is kept to a single, calm turntable motion.

    // ---- Camera ------------------------------------------------------------
    // The model keeps its natural scale and the camera is placed so that it
    // exactly fills the (fixed size) viewport.
    fitRadius = MAX(fitRadius, 0.6);
    [self rememberFitRadius:fitRadius margin:kMoleculeMargin forScene:scene];
    [self addLightsToScene:scene];
    SCNNode *camera = [self cameraNodeLookingAtNode:root
                                             distance:[self fitDistanceForRadius:fitRadius
                                                                 viewportSize:viewportSize
                                                                      margin:kMoleculeMargin]];
    [scene.rootNode addChildNode:camera];

    return scene;
}

#pragma mark - Atom scene

+ (SCNScene *)atomSceneForElement:(nullable PTElement *)element
                      viewportSize:(NSSize)viewportSize {
    SCNScene *scene = [SCNScene scene];
    scene.background.contents = [NSColor colorWithSRGBRed:0.055 green:0.065 blue:0.09 alpha:1.0];

    SCNNode *root = [[SCNNode alloc] init];
    root.name = kContentNodeName;
    [scene.rootNode addChildNode:root];

    if (element == nil) {
        [self addLightsToScene:scene];
        [self rememberFitRadius:1.5 margin:kMoleculeMargin forScene:scene];
        SCNNode *camera = [self cameraNodeLookingAtNode:root
                                                 distance:[self fitDistanceForRadius:1.5
                                                                     viewportSize:viewportSize
                                                                          margin:kAtomMargin]];
        [scene.rootNode addChildNode:camera];
        return scene;
    }

    NSArray<NSNumber *> *shells = element.shells;
    NSUInteger shellCount = shells.count;

    // ---- Nucleus: protons and neutrons -------------------------------------
    NSInteger protonCount = element.atomicNumber;
    NSInteger neutronCount = MAX(0, (NSInteger)llround(element.atomicMass) - protonCount);

    NSUInteger renderedNucleons = MIN((NSUInteger)MAX(protonCount, neutronCount), 42);
    SCNNode *nucleus = [[SCNNode alloc] init];
    [root addChildNode:nucleus];

    double nucleonRadius = 0.085;
    for (NSUInteger i = 0; i < renderedNucleons; i++) {
        BOOL isProton = (i < (NSUInteger)protonCount);
        SCNSphere *sphere = [SCNSphere sphereWithRadius:nucleonRadius];
        sphere.segmentCount = 16;
        sphere.materials = @[[self flatMaterialWithColor:isProton
                          ? [NSColor colorWithSRGBRed:0.95 green:0.32 blue:0.28 alpha:1.0]
                          : [NSColor colorWithSRGBRed:0.72 green:0.75 blue:0.80 alpha:1.0]]];

        SCNNode *node = [[SCNNode alloc] init];
        node.geometry = sphere;
        // Pack the nucleons into a small spiral so the cluster reads as a nucleus.
        double angle = i * 2.399963;   // golden angle
        double ring = 0.18 + 0.055 * (double)(i % 7);
        double y = -0.32 + 0.075 * (double)(i % 5);
        node.position = SCNVector3Make((float)(ring * cos(angle)), (float)y, (float)(ring * sin(angle)));
        [nucleus addChildNode:node];
    }

    // ---- Shells -------------------------------------------------------------
    double baseRadius = 0.95;
    double shellStep = 0.62;
    double electronRadius = 0.055;
    double maxShellRadius = baseRadius + shellStep * (double)MAX((NSInteger)1, (NSInteger)shellCount - 1);

    for (NSUInteger i = 0; i < shellCount; i++) {
        double radius = baseRadius + shellStep * (double)i;
        CGFloat hue = (CGFloat)(0.55 + 0.35 * (double)i / (double)MAX((NSUInteger)1, shellCount));
        NSColor *shellColour = [NSColor colorWithHue:hue saturation:0.55 brightness:0.95 alpha:1.0];

        SCNNode *shellNode = [[SCNNode alloc] init];
        // Tilt each shell a little differently so the orbits read as 3D.
        shellNode.eulerAngles = SCNVector3Make((CGFloat)(0.35 * ((i % 3) - 1)),
                                                (CGFloat)(0.5 * (i % 2)),
                                                (CGFloat)(0.25 * ((i % 4) - 1)));
        [root addChildNode:shellNode];

        SCNTorus *torus = [SCNTorus torusWithRingRadius:radius pipeRadius:0.016];
        torus.ringSegmentCount = 96;
        torus.pipeSegmentCount = 10;
        torus.materials = @[[self flatMaterialWithColor:[shellColour colorWithAlphaComponent:0.55]]];

        SCNNode *torusNode = [[SCNNode alloc] init];
        torusNode.geometry = torus;
        [shellNode addChildNode:torusNode];

        // Electrons on this shell.
        NSUInteger electronCount = shells[i].unsignedIntegerValue;
        if (electronCount == 0) { continue; }

        SCNNode *orbit = [[SCNNode alloc] init];
        [shellNode addChildNode:orbit];

        NSTimeInterval period = 2.2 + 1.7 * (double)i + 0.25 * (double)(electronCount % 4);
        SCNAction *orbitAction = [SCNAction repeatActionForever:[SCNAction rotateByAngle:(CGFloat)kTwoPi
                                                                        aroundAxis:SCNVector3Make(0, 1, 0)
                                                                           duration:period]];
        [orbit runAction:orbitAction];

        SCNSphere *electronGeometry = [SCNSphere sphereWithRadius:electronRadius];
        electronGeometry.segmentCount = 12;
        electronGeometry.materials = @[[self flatMaterialWithColor:
            [NSColor colorWithSRGBRed:0.55 green:0.85 blue:1.0 alpha:1.0]]];

        for (NSUInteger e = 0; e < electronCount; e++) {
            SCNNode *electron = [[SCNNode alloc] init];
            electron.geometry = electronGeometry;
            double angle = kTwoPi * (double)e / (double)electronCount;
            electron.position = SCNVector3Make((float)(radius * cos(angle)), 0, (float)(radius * sin(angle)));
            [orbit addChildNode:electron];
        }
    }

    // ---- Animation -----------------------------------------------------------
    SCNAction *nucleusSpin = [SCNAction repeatActionForever:[SCNAction rotateByAngle:(CGFloat)kTwoPi
                                                             aroundAxis:SCNVector3Make(0.2, 1, 0.1)
                                                                duration:9.0]];
    [nucleus runAction:nucleusSpin];

    // ---- Camera ---------------------------------------------------------------
    // The shells are tilted, so leave a little more room than a flat circle needs.
    [self rememberFitRadius:(maxShellRadius + electronRadius) margin:kAtomMargin forScene:scene];
    [self addLightsToScene:scene];
    SCNNode *camera = [self cameraNodeLookingAtNode:root
                                             distance:[self fitDistanceForRadius:(maxShellRadius + electronRadius)
                                                                 viewportSize:viewportSize
                                                                      margin:kAtomMargin]];
    [scene.rootNode addChildNode:camera];

    return scene;
}

@end
