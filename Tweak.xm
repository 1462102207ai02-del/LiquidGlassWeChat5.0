
#import <UIKit/UIKit.h>
#import "NewMainFrameViewController.h"  // Ensure full class declaration
#import "MainFrameTableView.h"

%hook MainFrameTableView

- (void)setHeaderView:(UIView *)headerView {
    if (headerView) {
        UIView *topBanner = [self.view viewWithTag:1234];  // Assuming tag is used to identify the top banner view
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

    // Use subviews to locate the top banner and hide it when expanded
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
    // Check for the presence of group chat in subviews to determine if it's expanded
    for (UIView *subview in self.view.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"GroupChat"]) {
            return YES;  // Return YES if group chat view is found
        }
    }
    return NO;  // Return NO if not found
}

%end
