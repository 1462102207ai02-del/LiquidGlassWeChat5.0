#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kMMBannerOriginalFrameKey = &kMMBannerOriginalFrameKey;
static const void *kMMBannerLockEnabledKey = &kMMBannerLockEnabledKey;

static UIViewController *MMNearestViewController(UIView *view) {
    UIResponder *r = view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    }
    return nil;
}

static BOOL MMIsHomeBannerContext(UIView *view) {
    UIViewController *vc = MMNearestViewController(view);
    if (!vc) return NO;

    NSString *vcName = NSStringFromClass([vc class]);
    if ([vcName isEqualToString:@"NewMainFrameViewController"]) return YES;

    UITabBarController *tab = vc.tabBarController;
    if (tab) {
        UIViewController *selected = tab.selectedViewController;
        if ([selected isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)selected;
            UIViewController *top = nav.topViewController ?: nav.visibleViewController ?: nav.viewControllers.firstObject;
            if ([NSStringFromClass([top class]) isEqualToString:@"NewMainFrameViewController"]) return YES;
        } else if ([NSStringFromClass([selected class]) isEqualToString:@"NewMainFrameViewController"]) {
            return YES;
        }
    }

    return NO;
}

static void MMRememberOriginalBannerFrame(UIView *banner) {
    if (!banner) return;
    NSValue *stored = objc_getAssociatedObject(banner, kMMBannerOriginalFrameKey);
    if (!stored) {
        objc_setAssociatedObject(banner, kMMBannerOriginalFrameKey, [NSValue valueWithCGRect:banner.frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGRect MMOriginalBannerFrame(UIView *banner) {
    NSValue *stored = objc_getAssociatedObject(banner, kMMBannerOriginalFrameKey);
    if (stored) return [stored CGRectValue];
    return banner.frame;
}

static void MMSetBannerLockEnabled(UIView *banner, BOOL enabled) {
    objc_setAssociatedObject(banner, kMMBannerLockEnabledKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL MMBannerLockEnabled(UIView *banner) {
    NSNumber *n = objc_getAssociatedObject(banner, kMMBannerLockEnabledKey);
    return n ? n.boolValue : NO;
}

static BOOL MMBannerExpanded(UIView *banner) {
    CGRect original = MMOriginalBannerFrame(banner);
    CGFloat collapsedHeight = CGRectGetHeight(original);
    if (collapsedHeight <= 1.0) collapsedHeight = 45.34;
    return CGRectGetHeight(banner.bounds) > collapsedHeight + 1.0;
}

static void MMFixBannerFrameIfNeeded(UIView *banner) {
    if (!banner) return;
    if (!MMIsHomeBannerContext(banner)) return;

    MMRememberOriginalBannerFrame(banner);

    CGRect original = MMOriginalBannerFrame(banner);
    BOOL expanded = MMBannerExpanded(banner);

    if (!expanded) {
        MMSetBannerLockEnabled(banner, NO);
        return;
    }

    MMSetBannerLockEnabled(banner, YES);

    CGRect f = banner.frame;
    f.origin.x = original.origin.x;
    f.origin.y = original.origin.y;
    f.size.width = original.size.width;
    banner.frame = f;
}

%hook MFBannerBtn

- (void)didMoveToWindow {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeBannerContext(view)) {
        MMRememberOriginalBannerFrame(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMFixBannerFrameIfNeeded(view);
        });
    }
}

- (void)setFrame:(CGRect)frame {
    UIView *view = (UIView *)self;
    if (MMIsHomeBannerContext(view)) {
        MMRememberOriginalBannerFrame(view);
        CGRect original = MMOriginalBannerFrame(view);

        CGFloat collapsedHeight = CGRectGetHeight(original);
        if (collapsedHeight <= 1.0) collapsedHeight = 45.34;

        BOOL looksExpanded = frame.size.height > collapsedHeight + 1.0 || MMBannerLockEnabled(view);
        if (looksExpanded) {
            frame.origin.x = original.origin.x;
            frame.origin.y = original.origin.y;
            frame.size.width = original.size.width;
            MMSetBannerLockEnabled(view, YES);
        }
    }
    %orig(frame);
}

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeBannerContext(view)) {
        MMRememberOriginalBannerFrame(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMFixBannerFrameIfNeeded(view);
        });
    }
}

%end
