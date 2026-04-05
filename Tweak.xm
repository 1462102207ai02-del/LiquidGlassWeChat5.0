
#import <UIKit/UIKit.h>

%hook MainFrameTableView

- (void)setHeaderView:(UIView *)headerView {
    if (headerView) {
        // Here we hide the top banner view
        UIView *topBanner = [self viewWithTag:1234]; // Assuming the tag or other reference method for identifying the top banner view
        if (topBanner) {
            topBanner.hidden = YES;  // Hides the top banner
        }
    }
    %orig;  // Calls the original method after modification
}

%end

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;

    // Using UIViewController as base to ensure 'view' property is accessible
    UIView *topBanner = [self.view viewWithTag:1234];  // Using a tag or another unique identifier
    if (topBanner) {
        topBanner.hidden = YES;
    }
}

%end
