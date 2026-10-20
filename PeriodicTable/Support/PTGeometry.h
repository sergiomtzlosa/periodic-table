//
//  PTGeometry.h
//  PeriodicTable
//
//  Small 3D vector helpers used by the model and the SceneKit layer.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct PTVec3 {
    double x;
    double y;
    double z;
} PTVec3;

static inline PTVec3 PTVec3Make(double x, double y, double z) {
    PTVec3 v; v.x = x; v.y = y; v.z = z; return v;
}

static inline PTVec3 PTVec3Add(PTVec3 a, PTVec3 b) {
    return PTVec3Make(a.x + b.x, a.y + b.y, a.z + b.z);
}

static inline PTVec3 PTVec3Subtract(PTVec3 a, PTVec3 b) {
    return PTVec3Make(a.x - b.x, a.y - b.y, a.z - b.z);
}

static inline PTVec3 PTVec3Scale(PTVec3 a, double s) {
    return PTVec3Make(a.x * s, a.y * s, a.z * s);
}

static inline double PTVec3Dot(PTVec3 a, PTVec3 b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

static inline double PTVec3Length(PTVec3 a) {
    return sqrt(PTVec3Dot(a, a));
}

static inline PTVec3 PTVec3Normalize(PTVec3 a) {
    double len = PTVec3Length(a);
    if (len < 1e-9) { return PTVec3Make(0, 0, 0); }
    return PTVec3Scale(a, 1.0 / len);
}

static inline PTVec3 PTVec3Cross(PTVec3 a, PTVec3 b) {
    return PTVec3Make(a.y * b.z - a.z * b.y,
                      a.z * b.x - a.x * b.z,
                      a.x * b.y - a.y * b.x);
}

static inline double PTVec3Distance(PTVec3 a, PTVec3 b) {
    return PTVec3Length(PTVec3Subtract(a, b));
}

NS_ASSUME_NONNULL_END
