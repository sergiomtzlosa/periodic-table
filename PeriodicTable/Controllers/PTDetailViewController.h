//
//  PTDetailViewController.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>
#import "PTElement.h"

@class PTMolecule3DViewController;

NS_ASSUME_NONNULL_BEGIN

/// The right-hand pane: everything known about the selected element plus the
/// live 3D molecule / atom view.
@interface PTDetailViewController : NSViewController

/// Replaces the contents with the given element and refreshes the 3D view.
- (void)displayElement:(nullable PTElement *)element;

/// The element currently on show.
@property (nonatomic, strong, readonly, nullable) PTElement *element;

/// The embedded 3D viewer.
@property (nonatomic, strong, readonly) PTMolecule3DViewController *moleculeController;

/// The scrolling information pane.
@property (nonatomic, strong, readonly) NSScrollView *infoScrollView;

@end

NS_ASSUME_NONNULL_END
