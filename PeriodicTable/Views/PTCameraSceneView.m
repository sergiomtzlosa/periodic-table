//
//  PTCameraSceneView.m
//  PeriodicTable
//

#import "PTCameraSceneView.h"
#import "PTMoleculeSceneBuilder.h"

static NSString * const PTCameraNodeName = @"PTCamera";

/// Radians of rotation per point of mouse movement.
static const double kOrbitSensitivity = 0.008;
/// Multiplier applied per scroll wheel notch.
static const double kZoomStep = 1.12;

@interface PTCameraSceneView ()
@property (nonatomic, strong, nullable) SCNNode *cameraNode;
@property (nonatomic, assign) NSPoint dragOrigin;
@property (nonatomic, assign) BOOL isDragging;
@end

@implementation PTCameraSceneView

- (instancetype)init {
    // NSView's -init does not necessarily route through -initWithFrame:, so
    // the setup has to happen here as well — otherwise the camera zoom would
    // start at zero and collapse the model into the origin.
    self = [super init];
    if (!self) { return nil; }
    [self commonInit];
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (!self) { return nil; }
    [self commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self) { return nil; }
    [self commonInit];
    return self;
}

- (void)commonInit {
    // The default camera controller is what makes the model twitch under the
    // mouse, so the view drives the camera itself instead.
    self.allowsCameraControl = NO;
    self.autoenablesDefaultLighting = NO;
    // The view deliberately does not implement -mouseMoved:, so the model
    // cannot react to the pointer merely passing over it.
    self.homeDistance = 6.0;
    self.userZoom = 1.0;
}

- (void)setScene:(SCNScene *)scene {
    [super setScene:scene];
    [self findCameraNode];
    [self readHomeDistance];
}

- (void)findCameraNode {
    self.cameraNode = nil;
    __block SCNNode *found = nil;
    [self.scene.rootNode enumerateChildNodesUsingBlock:^(SCNNode *child, BOOL *stop) {
        if ([child.name isEqualToString:PTCameraNodeName]) { found = child; *stop = YES; }
    }];
    self.cameraNode = found;
}

- (void)readHomeDistance {
    SCNNode *camera = self.cameraNode;
    if (camera == nil) { return; }
    SCNVector3 p = camera.position;
    double distance = sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
    if (distance > 0.001) { self.homeDistance = distance; }
}

- (void)refit {
    if (self.scene == nil) { return; }

    [self findCameraNode];
    [PTMoleculeSceneBuilder frameScene:self.scene viewportSize:self.bounds.size];
    [self findCameraNode];
    [self readHomeDistance];
    [self applyZoom];
}

- (void)resetCamera {
    self.userZoom = 1.0;
    [self applyZoom];
}

- (void)applyZoom {
    SCNNode *camera = self.cameraNode;
    if (camera == nil) { return; }

    if (self.userZoom <= 0.0) { self.userZoom = 1.0; }
    if (self.homeDistance <= 0.0) { return; }

    double azimuth = 0.0, elevation = 0.0;
    [self sphericalAnglesForCamera:camera azimuth:&azimuth elevation:&elevation];
    [self setCameraAzimuth:azimuth elevation:elevation distance:self.homeDistance * self.userZoom];
}

#pragma mark - Camera maths

/// The camera's current position as spherical coordinates around the origin.
- (void)sphericalAnglesForCamera:(SCNNode *)camera azimuth:(double *)azimuth elevation:(double *)elevation {
    SCNVector3 p = camera.position;
    double distance = sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
    if (distance < 0.0001) {
        if (azimuth) { *azimuth = 0.0; }
        if (elevation) { *elevation = 0.0; }
        return;
    }
    if (azimuth) { *azimuth = atan2(p.x, p.z); }
    if (elevation) { *elevation = asin(MAX(-1.0, MIN(1.0, p.y / distance))); }
}

- (void)setCameraAzimuth:(double)azimuth elevation:(double)elevation distance:(double)distance {
    SCNNode *camera = self.cameraNode;
    if (camera == nil) { return; }

    double clampedElevation = MAX(-1.35, MIN(1.35, elevation));
    double cosE = cos(clampedElevation);
    camera.position = SCNVector3Make(distance * cosE * sin(azimuth),
                                     distance * sin(clampedElevation),
                                     distance * cosE * cos(azimuth));
}

- (double)cameraDistance {
    SCNNode *camera = self.cameraNode;
    if (camera == nil) { return 0.0; }
    SCNVector3 p = camera.position;
    return sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
}

#pragma mark - Interaction

- (void)mouseDown:(NSEvent *)event {
    if (self.cameraNode == nil) { return; }
    self.isDragging = YES;
    self.dragOrigin = [self convertPoint:event.locationInWindow fromView:nil];
}

- (void)mouseDragged:(NSEvent *)event {
    if (!self.isDragging || self.cameraNode == nil) { return; }

    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    double dx = point.x - self.dragOrigin.x;
    double dy = point.y - self.dragOrigin.y;
    self.dragOrigin = point;

    double azimuth = 0.0, elevation = 0.0;
    [self sphericalAnglesForCamera:self.cameraNode azimuth:&azimuth elevation:&elevation];

    [self setCameraAzimuth:azimuth - dx * kOrbitSensitivity
                  elevation:elevation + dy * kOrbitSensitivity
                   distance:[self cameraDistance]];
}

- (void)mouseUp:(NSEvent *)event {
    self.isDragging = NO;
}

- (void)scrollWheel:(NSEvent *)event {
    if (self.cameraNode == nil) { return; }

    double distance = [self cameraDistance];
    if (distance < 0.0001) { return; }

    double factor = pow(kZoomStep, event.hasPreciseScrollingDeltas ? -event.scrollingDeltaY * 0.05 : event.scrollingDeltaY);
    double minimum = self.homeDistance * 0.25;
    double maximum = self.homeDistance * 3.0;
    distance = MAX(minimum, MIN(maximum, distance * factor));

    double azimuth = 0.0, elevation = 0.0;
    [self sphericalAnglesForCamera:self.cameraNode azimuth:&azimuth elevation:&elevation];
    [self setCameraAzimuth:azimuth elevation:elevation distance:distance];

    if (self.homeDistance > 0.001) {
        self.userZoom = distance / self.homeDistance;
    }

}

@end
