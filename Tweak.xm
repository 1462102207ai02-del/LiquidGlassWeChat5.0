
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

    // Directly hiding the top banner without relying on 'view' property
    UIView *topBanner = [self.view viewWithTag:1234];  // Using a tag or another unique identifier
    if (topBanner) {
        topBanner.hidden = YES;
    }

    // Ensuring group chat is fully expanded by modifying its frame
    UIView *groupChatView = [self.view viewWithTag:5678];  // Assuming a tag for the group chat
    if (groupChatView) {
        CGRect expandedFrame = groupChatView.frame;
        expandedFrame.size.height = 200;  // Example height adjustment
        groupChatView.frame = expandedFrame;
    }
}

%end
