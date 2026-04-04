#import <UIKit/UIKit.h>

%hook MainFrameTableView

- (void)setContentOffset:(CGPoint)contentOffset {
    UIViewController *vc = nil;
    UIResponder *r = (UIResponder *)self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            vc = (UIViewController *)r;
            break;
        }
    }

    if ([NSStringFromClass([vc class]) containsString:@"NewMainFrameViewController"]) {
        if (contentOffset.y < 0) {
            contentOffset.y = 0;
        }
    }

    %orig(contentOffset);
}

- (void)setBounds:(CGRect)bounds {
    UIViewController *vc = nil;
    UIResponder *r = (UIResponder *)self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            vc = (UIViewController *)r;
            break;
        }
    }

    if ([NSStringFromClass([vc class]) containsString:@"NewMainFrameViewController"]) {
        if (bounds.origin.y < 0) {
            bounds.origin.y = 0;
        }
    }

    %orig(bounds);
}

- (void)layoutSubviews {
    %orig;

    UIViewController *vc = nil;
    UIResponder *r = (UIResponder *)self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            vc = (UIViewController *)r;
            break;
        }
    }

    if ([NSStringFromClass([vc class]) containsString:@"NewMainFrameViewController"]) {
        if (self.contentOffset.y < 0) {
            [self setContentOffset:CGPointZero];
        }
    }
}

%end
