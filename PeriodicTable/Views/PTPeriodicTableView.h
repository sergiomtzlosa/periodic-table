//
//  PTPeriodicTableView.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>
#import "PTElement.h"

NS_ASSUME_NONNULL_BEGIN

@class PTPeriodicTableView;

@protocol PTPeriodicTableViewDelegate <NSObject>
- (void)periodicTableView:(PTPeriodicTableView *)tableView didSelectElement:(PTElement *)element;
@end

/// Draws the periodic table itself: 18 columns × 7 periods with the
/// lanthanides and actinides in their own rows, plus the group and period
/// rulers.  Everything is painted by the view, so there are no item views to
/// manage and the layout is exact.
@interface PTPeriodicTableView : NSView

/// Every element, in atomic-number order.
@property (nonatomic, copy) NSArray<PTElement *> *elements;
/// The subset that matches the current search; everything else is dimmed.
@property (nonatomic, copy) NSArray<PTElement *> *matches;
@property (nonatomic, weak, nullable) id<PTPeriodicTableViewDelegate> delegate;
/// Atomic number of the selected element, or 0.
@property (nonatomic, assign) NSInteger selectedAtomicNumber;

/// Size of one tile.  Changing this re-lays out the table.
@property (nonatomic, assign) NSSize itemSize;

/// Selects the element with the given atomic number (does not notify the delegate).
- (void)selectElementWithAtomicNumber:(NSInteger)atomicNumber;

/// Recomputes the tile size so the table fits the given width.
- (void)fitToWidth:(CGFloat)width;

/// The size the table needs to draw every element.
@property (nonatomic, readonly) NSSize contentSize;

/// The rectangle the given element's tile occupies, in the view's coordinates.
- (NSRect)rectForElement:(nullable PTElement *)element;

@end

NS_ASSUME_NONNULL_END
