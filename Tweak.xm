#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kMMFoldOriginalFrameKey = &kMMFoldOriginalFrameKey;
static const void *kMMFoldLockEnabledKey = &kMMFoldLockEnabledKey;

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
    NSValue *stored = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameKey);
    if (!stored) {
        objc_setAssociatedObject(foldView, kMMFoldOriginalFrameKey, [NSValue valueWithCGRect:foldView.frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGRect MMOriginalFoldFrame(UIView *foldView) {
    NSValue *stored = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameKey);
    if (stored) return [stored CGRectValue];
    return foldView.frame;
}

static void MMSetFoldLockEnabled(UIView *foldView, BOOL enabled) {
    objc_setAssociatedObject(foldView, kMMFoldLockEnabledKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL MMFoldLockEnabled(UIView *foldView) {
    NSNumber *n = objc_getAssociatedObject(foldView, kMMFoldLockEnabledKey);
    return n ? n.boolValue : NO;
}

static void MMFixFoldFrameIfNeeded(UIView *foldView) {
    if (!foldView) return;
    if (!MMIsHomeFoldContext(foldView)) return;

    MMRememberOriginalFoldFrame(foldView);

    CGRect original = MMOriginalFoldFrame(foldView);
    CGRect current = foldView.frame;

    BOOL movedDown = current.origin.y > original.origin.y + 0.5;
    BOOL resized = fabs(current.size.height - original.size.height) > 0.5;
    BOOL shouldLock = movedDown || resized || MMFoldLockEnabled(foldView);

    if (!shouldLock) {
        return;
    }

    MMSetFoldLockEnabled(foldView, YES);

    current.origin.x = original.origin.x;
    current.origin.y = original.origin.y;
    current.size.width = original.size.width;
    foldView.frame = current;
}

%hook MainFrameSectionFoldView

- (void)didMoveToWindow {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        MMRememberOriginalFoldFrame(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMFixFoldFrameIfNeeded(view);
        });
    }
}

- (void)setFrame:(CGRect)frame {
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        MMRememberOriginalFoldFrame(view);
        CGRect original = MMOriginalFoldFrame(view);

        BOOL movedDown = frame.origin.y > original.origin.y + 0.5;
        BOOL resized = fabs(frame.size.height - original.size.height) > 0.5;

        if (movedDown || resized || MMFoldLockEnabled(view)) {
            frame.origin.x = original.origin.x;
            frame.origin.y = original.origin.y;
            frame.size.width = original.size.width;
            MMSetFoldLockEnabled(view, YES);
        }
    }
    %orig(frame);
}

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        MMRememberOriginalFoldFrame(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMFixFoldFrameIfNeeded(view);
        });
    }
}

%end
