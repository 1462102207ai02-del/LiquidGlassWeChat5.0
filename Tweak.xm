
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook MainFrameTableView

- (void)setHeaderView:(UIView *)headerView {
    if (headerView) {
        UIView *topBanner = [self viewWithTag:1234];  // Using tag to identify top banner
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

    // Hide or show the top banner based on whether the group chat is expanded
    UIView *topBanner = [self.view viewWithTag:1234];  // Using tag for top banner
    if (topBanner) {
        if ([self isGroupChatExpanded]) {
            topBanner.hidden = YES;  // Hide the top banner when expanded
        } else {
            topBanner.hidden = NO;  // Show the top banner when collapsed
        }
    }
}

- (BOOL)isGroupChatExpanded {
    // This method checks if the group chat is expanded based on some condition
    // You might want to adjust this logic to your actual implementation
    UIView *groupChatView = [self.view viewWithTag:5678];  // Assuming a tag for group chat
    return groupChatView != nil;  // If the group chat view exists, return YES (expanded)
}

%end
