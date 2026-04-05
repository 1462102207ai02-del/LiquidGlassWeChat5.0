
#import <UIKit/UIKit.h>

%hook MainFrameTableView

// Ensuring group chat is fully expanded and banners are hidden
- (void)setHeaderView:(UIView *)headerView {
    if (headerView) {
        UIView *topBanner = [self viewWithTag:1234]; // Assuming the tag or other reference method for identifying the top banner view
        if (topBanner) {
            topBanner.hidden = YES;  // Hides the top banner
        }
    }
    %orig;
}

%end

%hook NewMainFrameViewController

// Ensure top group chat is fully expanded and no banner is shown
- (void)viewDidLoad {
    %orig;

    // Hiding top banner if present
    UIView *topBanner = [self.view viewWithTag:1234];
    if (topBanner) {
        topBanner.hidden = YES;
    }

    // Ensure group chat is fully expanded here (adjust the logic as per actual view logic)
    [self expandGroupChat];  // Hypothetical method to fully expand group chat
}

- (void)expandGroupChat {
    // Logic to fully expand the group chat view (adjust as necessary)
    // This is just a placeholder; you would need the actual logic for this.
}

%end
