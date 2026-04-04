#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kMMFoldOriginalFrameKey = &kMMFoldOriginalFrameKey;

static UIViewController *MMNearestViewController(UIView *view) {
    UIResponder *r = (UIResponder *)view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)r;
        }
    }
    return nil;
}

static BOOL MMIsHomeFoldContext(UIView *view) {
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

static void MMRememberOriginalFoldFrame(UIView *foldView) {
    if (!foldView) return;
    if (!MMIsHomeFoldContext(foldView)) return;

    NSValue *stored = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameKey);
    if (!stored) {
        objc_setAssociatedObject(foldView, kMMFoldOriginalFrameKey, [NSValue valueWithCGRect:foldView.frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGRect MMOriginalFoldFrame(UIView *foldView) {
    NSValue *stored = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameKey);
    return stored ? [stored CGRectValue] : foldView.frame;
}

static CGRect MMFixedFoldFrameIfNeeded(UIView *foldView, CGRect incoming) {
    if (!foldView) return incoming;
    if (!MMIsHomeFoldContext(foldView)) return incoming;

    MMRememberOriginalFoldFrame(foldView);
    CGRect original = MMOriginalFoldFrame(foldView);

    CGFloat threshold = original.origin.y + 120.0;
    BOOL movedTooFarDown = incoming.origin.y > threshold;
    BOOL widthChangedTooMuch = fabs(incoming.size.width - original.size.width) > 1.0;
    BOOL xChangedTooMuch = fabs(incoming.origin.x - original.origin.x) > 1.0;

    if (movedTooFarDown || widthChangedTooMuch || xChangedTooMuch) {
        incoming.origin.x = original.origin.x;
        incoming.origin.y = original.origin.y;
        incoming.size.width = original.size.width;
    }

    return incoming;
}

static void MMFixFoldViewIfNeeded(UIView *foldView) {
    if (!foldView) return;
    if (!MMIsHomeFoldContext(foldView)) return;

    CGRect fixed = MMFixedFoldFrameIfNeeded(foldView, foldView.frame);
    if (!CGRectEqualToRect(fixed, foldView.frame)) {
        foldView.frame = fixed;
    }
}

%hook MainFrameSectionFoldView

- (void)didMoveToWindow {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        MMRememberOriginalFoldFrame(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMFixFoldViewIfNeeded(view);
        });
    }
}

- (void)didMoveToSuperview {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        MMRememberOriginalFoldFrame(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMFixFoldViewIfNeeded(view);
        });
    }
}

- (void)setFrame:(CGRect)frame {
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        frame = MMFixedFoldFrameIfNeeded(view, frame);
    }
    %orig(frame);
}

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MMFixFoldViewIfNeeded(view);
        });
    }
}

%end
