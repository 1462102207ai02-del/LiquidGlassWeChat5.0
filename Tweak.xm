#import <UIKit/UIKit.h>

@interface MainFrameTableView : UIScrollView
@end

%hook MainFrameTableView

- (void)setContentOffset:(CGPoint)contentOffset {
    if (contentOffset.y < 0) {
        contentOffset.y = 0;
    }
    %orig(contentOffset);
}

- (void)layoutSubviews {
    %orig;

    UIView *deviceBanner = nil;
    UIView *topBanner = nil;

    for (UIView *sub in self.subviews) {
        NSString *cls = NSStringFromClass([sub class]);

        if ([cls containsString:@"Banner"] || [cls containsString:@"Login"]) {
            deviceBanner = sub;
        }

        if ([cls containsString:@"FoldView"]) {
            topBanner = sub;
        }
    }

    if (deviceBanner && topBanner) {
        CGRect f1 = deviceBanner.frame;
        CGRect f2 = topBanner.frame;

        f2.origin.y = CGRectGetMaxY(f1);

        topBanner.frame = f2;
    }
}

%end
