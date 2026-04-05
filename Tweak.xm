
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

    // Hiding the top banner explicitly using subviews or other references
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

- (BOOL)isGroupChatExpanded {
    // Using a simpler method to determine if the group chat is expanded
    // Check whether the group chat section is expanded
    for (UIView *subview in self.view.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"GroupChat"]) {
            return YES;  // Return YES if group chat is found (adjust logic as needed)
        }
    }
    return NO;  // Default to NO if not found
}

%end
