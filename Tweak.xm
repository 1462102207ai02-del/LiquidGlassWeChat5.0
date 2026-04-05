
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook MainFrameTableView

- (void)setHeaderView:(UIView *)headerView {
    if (headerView) {
        // Here we hide the top banner view
        UIView *topBanner = nil;
        for (UIView *subview in self.subviews) {
            if ([NSStringFromClass([subview class]) containsString:@"TopBanner"]) {
                topBanner = subview;
                break;
            }
        }
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

    // Hiding the top banner without using `view` directly, using subviews instead
    UIView *topBanner = nil;
    for (UIView *subview in self.view.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"TopBanner"]) {
            topBanner = subview;
            break;
        }
    }
    if (topBanner) {
        topBanner.hidden = YES;
    }

    // Ensuring group chat is fully expanded by modifying its frame directly
    UIView *groupChatView = nil;
    for (UIView *subview in self.view.subviews) {
        if ([NSStringFromClass([subview class]) containsString:@"GroupChat"]) {
            groupChatView = subview;
            break;
        }
    }

    if (groupChatView) {
        CGRect expandedFrame = groupChatView.frame;
        expandedFrame.size.height = 200;  // Example height adjustment
        groupChatView.frame = expandedFrame;
    }
}

%end
