#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kMMBannerOriginalFrameKey = &kMMBannerOriginalFrameKey;

static UIViewController *MMCurrentContentController(UIViewController *vc) {
    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {}

    UIViewController *content = [selected isKindOfClass:[UIViewController class]] ? selected : vc;
    if ([content isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)content;
        return nav.topViewController ?: nav.visibleViewController ?: nav.viewControllers.firstObject;
    }
    return content;
}

static UIView *MMFindBannerButtonRecursive(UIView *view) {
    if ([NSStringFromClass([view class]) isEqualToString:@"MFBannerBtn"]) return view;
    for (UIView *sub in view.subviews) {
        UIView *v = MMFindBannerButtonRecursive(sub);
        if (v) return v;
    }
    return nil;
}

static void MMAdjustBannerIfNeeded(UIViewController *vc) {
    UIViewController *content = MMCurrentContentController(vc);
    if (![NSStringFromClass([content class]) isEqualToString:@"NewMainFrameViewController"]) return;

    UIView *banner = MMFindBannerButtonRecursive(content.view);
    if (!banner || !banner.superview) return;

    NSValue *stored = objc_getAssociatedObject(banner, kMMBannerOriginalFrameKey);
    if (!stored) {
        stored = [NSValue valueWithCGRect:banner.frame];
        objc_setAssociatedObject(banner, kMMBannerOriginalFrameKey, stored, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    CGRect original = [stored CGRectValue];
    CGFloat collapsedHeight = 45.34;
    BOOL expanded = banner.bounds.size.height > collapsedHeight + 1.0;

    if (!expanded) {
        banner.frame = original;
        [banner.superview bringSubviewToFront:banner];
        return;
    }

    CGRect f = banner.frame;
    f.origin.x = original.origin.x;
    f.origin.y = original.origin.y;
    f.size.width = original.size.width;
    banner.frame = f;

    banner.clipsToBounds = NO;
    banner.layer.masksToBounds = NO;

    [banner.superview bringSubviewToFront:banner];
}

%hook MainTabBarViewController

- (void)viewDidLayoutSubviews {
    %orig;
    MMAdjustBannerIfNeeded((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMAdjustBannerIfNeeded((UIViewController *)self);
}

%end

%hook MFBannerBtn

- (void)layoutSubviews {
    %orig;

    UIResponder *r = (UIResponder *)self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            UITabBarController *tab = vc.tabBarController;
            if ([NSStringFromClass([tab class]) isEqualToString:@"MainTabBarViewController"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    MMAdjustBannerIfNeeded((UIViewController *)tab);
                });
                break;
            }
        }
    }
}

%end
