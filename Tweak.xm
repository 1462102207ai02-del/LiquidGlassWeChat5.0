
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook MainFrameTableView

- (void)setHeaderView:(UIView *)headerView {
    if (headerView) {
        UIView *topBanner = [self viewWithTag:1234]; // Assuming the tag or other reference method for identifying the top banner view
        if (topBanner) {
            topBanner.hidden = NO;  // Show the top banner when collapsed
        }
    }
    %orig;  // Calls the original method after modification
}

%end

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;

    // Ensure the top banner is hidden when expanded
    UIView *topBanner = [self.view viewWithTag:1234]; // Assuming the tag or other reference method for identifying the top banner view
    if (topBanner) {
        if ([self isGroupChatExpanded]) {
            topBanner.hidden = YES;  // Hide the top banner when expanded
        } else {
            topBanner.hidden = NO;  // Show the top banner when collapsed
        }
    }
}

// Simplified logic to determine if the group chat is expanded
- (BOOL)isGroupChatExpanded {
    // Assuming you will add the logic to determine if the group chat is expanded
    // This can be based on the visibility of certain UI elements, or any other relevant check
    return YES; // Here it is assumed that the group chat is always expanded
}

%end
