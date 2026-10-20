//
//  main.m
//  PeriodicTable
//

#import <AppKit/AppKit.h>
#import "AppDelegate.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        application.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;

        [application run];
    }
    return 0;
}
