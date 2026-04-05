
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

    // Access subviews to find the top banner and hide it when expanded
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

// Directly check for group chat expansion state using subviews
- (BOOL)isGroupChatExpanded {
    for (UIView *subview in self.view.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"GroupChat"]) {
            return YES;  // Return YES if the group chat view is found (adjust logic as needed)
        }
    }
    return NO;  // Return NO if not found
}

%end
