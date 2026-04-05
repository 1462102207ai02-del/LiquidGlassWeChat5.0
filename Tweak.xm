
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

    // Using subviews to locate the top banner and hide it when expanded
    UIView *topBanner = nil;
    for (UIView *subview in self.view.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"TopBanner"]) {
            topBanner = subview;
            break;
        }
    }
    if (topBanner) {
        if ([self isGroupChatExpanded]) {
            topBanner.hidden = YES;  // Hide the top banner when expanded
        } else {
            topBanner.hidden = NO;  // Show the top banner when collapsed
        }
    }
}

// Checking if the group chat is expanded by inspecting subviews for the group chat view
- (BOOL)isGroupChatExpanded {
    for (UIView *subview in self.view.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"GroupChat"]) {
            return YES;  // Return YES if group chat is found (adjust logic as needed)
        }
    }
    return NO;  // Return NO if not found
}

%end
