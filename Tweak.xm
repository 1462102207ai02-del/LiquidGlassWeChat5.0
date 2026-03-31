#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook MMTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    UITabBarController *tabVC = (UITabBarController *)self;
    UITabBar *tabBar = tabVC.tabBar;
    if (!tabBar) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableString *log = [NSMutableString string];

        for (UIView *v in tabBar.subviews) {
            [log appendFormat:@"TABBAR: %@\n", NSStringFromClass([v class])];
        }

        [log writeToFile:@"/var/mobile/tabbar.log"
             atomically:YES
               encoding:NSUTF8StringEncoding
                  error:nil];
    });
}

%end
