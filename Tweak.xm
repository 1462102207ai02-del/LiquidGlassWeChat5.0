
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

    // Hiding the top banner explicitly
    UIView *topBanner = [self.view viewWithTag:1234];  // Using a tag or another unique identifier
    if (topBanner) {
        topBanner.hidden = YES;
    }

    // Ensuring the group chat is fully expanded (simplified approach without the non-existing method)
    [self fullyExpandGroupChat];
}

- (void)fullyExpandGroupChat {
    // Implementing a simple method to ensure the group chat is expanded
    // This is where you can adjust the logic for expanding the group chat based on your UI structure
}

%end
