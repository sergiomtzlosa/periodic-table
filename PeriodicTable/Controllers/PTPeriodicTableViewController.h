//
//  PTPeriodicTableViewController.h
//  PeriodicTable
//

#import <AppKit/AppKit.h>
#import "PTElement.h"

NS_ASSUME_NONNULL_BEGIN

@class PTPeriodicTableViewController;
@class PTPeriodicTableView;

@protocol PTPeriodicTableViewControllerDelegate <NSObject>
- (void)periodicTableViewController:(PTPeriodicTableViewController *)controller
                   didSelectElement:(PTElement *)element;
@end

/// The left-hand pane: the periodic table itself, plus search and a legend.
@interface PTPeriodicTableViewController : NSViewController

@property (nonatomic, weak, nullable) id<PTPeriodicTableViewControllerDelegate> delegate;

/// The search field, exposed so the menu can focus it.
@property (nonatomic, strong, readonly, nullable) NSSearchField *searchField;

/// The table view.
@property (nonatomic, strong, readonly) PTPeriodicTableView *tableView;

/// Selects (and scrolls to) the element with the given atomic number.
- (void)selectElementWithAtomicNumber:(NSInteger)atomicNumber;

@end

NS_ASSUME_NONNULL_END
