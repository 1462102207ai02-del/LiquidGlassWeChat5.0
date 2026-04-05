
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook MainFrameTableView

- (void)setHeaderView:(UIView *)headerView {
    if (headerView) {
        UIView *topBanner = [self viewWithTag:1234]; 
        if (topBanner) {
            topBanner.hidden = NO;  // 收起时显示横幅
        }
    }
    %orig;
}

%end

%hook NewMainFrameViewController

- (void)viewDidLoad {
    %orig;

    UIView *topBanner = [self.view viewWithTag:1234];
    if (topBanner) {
        if (self.isGroupChatExpanded) {
            topBanner.hidden = YES; // 展开时隐藏横幅
        } else {
            topBanner.hidden = NO; // 收起时显示横幅
        }
    }
}

- (BOOL)isGroupChatExpanded {
    return YES; 
}

%end
