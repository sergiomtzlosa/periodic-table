//
//  PTElectronShellView.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A 2D Bohr-style diagram: concentric shell circles with electrons drawn on them.
@interface PTElectronShellView : NSView

/// Electrons per principal shell, e.g. @[2, 8, 14, 2].
@property (nonatomic, copy) NSArray<NSNumber *> *shells;
@property (nonatomic, strong) NSColor *shellColor;
@property (nonatomic, strong) NSColor *electronColor;
@property (nonatomic, strong) NSColor *nucleusColor;

@end

NS_ASSUME_NONNULL_END
