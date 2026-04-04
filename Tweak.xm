#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kMMFoldOriginalFrameInSuperviewKey = &kMMFoldOriginalFrameInSuperviewKey;
static const void *kMMFoldOriginalRectInRootKey = &kMMFoldOriginalRectInRootKey;

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

static UIViewController *MMHomeRootControllerForView(UIView *view) {
    UIViewController *vc = MMNearestViewController(view);
    if (!vc) return nil;

    NSString *vcName = NSStringFromClass([vc class]);
    if ([vcName isEqualToString:@"NewMainFrameViewController"]) return vc;

    UITabBarController *tab = vc.tabBarController;
    if (!tab) return nil;

    UIViewController *selected = tab.selectedViewController;
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        UIViewController *top = nav.topViewController ?: nav.visibleViewController ?: nav.viewControllers.firstObject;
        if ([NSStringFromClass([top class]) isEqualToString:@"NewMainFrameViewController"]) return top;
    } else if ([NSStringFromClass([selected class]) isEqualToString:@"NewMainFrameViewController"]) {
        return selected;
    }

    return nil;
}

static BOOL MMIsHomeFoldContext(UIView *view) {
    return MMHomeRootControllerForView(view) != nil;
}

static void MMRememberOriginalFoldPosition(UIView *foldView) {
    if (!foldView || !foldView.superview) return;
    if (!MMIsHomeFoldContext(foldView)) return;

    NSValue *storedSuperviewFrame = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameInSuperviewKey);
    NSValue *storedRootRect = objc_getAssociatedObject(foldView, kMMFoldOriginalRectInRootKey);

    UIViewController *homeVC = MMHomeRootControllerForView(foldView);
    if (!homeVC) return;

    if (!storedSuperviewFrame) {
        objc_setAssociatedObject(foldView, kMMFoldOriginalFrameInSuperviewKey, [NSValue valueWithCGRect:foldView.frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!storedRootRect) {
        CGRect rectInRoot = [foldView.superview convertRect:foldView.frame toView:homeVC.view];
        objc_setAssociatedObject(foldView, kMMFoldOriginalRectInRootKey, [NSValue valueWithCGRect:rectInRoot], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGRect MMOriginalFoldFrameInSuperview(UIView *foldView) {
    NSValue *v = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameInSuperviewKey);
    return v ? [v CGRectValue] : foldView.frame;
}

static CGRect MMOriginalFoldRectInRoot(UIView *foldView) {
    NSValue *v = objc_getAssociatedObject(foldView, kMMFoldOriginalRectInRootKey);
    if (v) return [v CGRectValue];

    UIViewController *homeVC = MMHomeRootControllerForView(foldView);
    if (homeVC && foldView.superview) {
        return [foldView.superview convertRect:foldView.frame toView:homeVC.view];
    }
    return foldView.frame;
}

static void MMLockFoldToTopAbsolutePosition(UIView *foldView) {
    if (!foldView || !foldView.superview) return;
    if (!MMIsHomeFoldContext(foldView)) return;

    UIViewController *homeVC = MMHomeRootControllerForView(foldView);
    if (!homeVC) return;

    MMRememberOriginalFoldPosition(foldView);

    CGRect originalSuperviewFrame = MMOriginalFoldFrameInSuperview(foldView);
    CGRect originalRootRect = MMOriginalFoldRectInRoot(foldView);

    CGRect currentRootRect = [foldView.superview convertRect:foldView.frame toView:homeVC.view];

    BOOL movedVertically = fabs(currentRootRect.origin.y - originalRootRect.origin.y) > 0.5;
    BOOL movedHorizontally = fabs(currentRootRect.origin.x - originalRootRect.origin.x) > 0.5;
    BOOL widthChanged = fabs(currentRootRect.size.width - originalRootRect.size.width) > 0.5;

    if (!(movedVertically || movedHorizontally || widthChanged)) return;

    CGRect targetRootRect = currentRootRect;
    targetRootRect.origin.x = originalRootRect.origin.x;
    targetRootRect.origin.y = originalRootRect.origin.y;
    targetRootRect.size.width = originalRootRect.size.width;

    CGRect targetInSuperview = [foldView.superview convertRect:targetRootRect fromView:homeVC.view];

    CGRect fixed = foldView.frame;
    fixed.origin.x = targetInSuperview.origin.x;
    fixed.origin.y = targetInSuperview.origin.y;
    fixed.size.width = targetInSuperview.size.width;

    if (fixed.size.height <= 1.0) {
        fixed.size.height = originalSuperviewFrame.size.height;
    }

    foldView.frame = fixed;
    [foldView.superview bringSubviewToFront:foldView];
}

%hook MainFrameSectionFoldView

- (void)didMoveToWindow {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        MMRememberOriginalFoldPosition(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMLockFoldToTopAbsolutePosition(view);
        });
    }
}

- (void)didMoveToSuperview {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        MMRememberOriginalFoldPosition(view);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMLockFoldToTopAbsolutePosition(view);
        });
    }
}

- (void)setFrame:(CGRect)frame {
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view) && view.superview) {
        MMRememberOriginalFoldPosition(view);

        UIViewController *homeVC = MMHomeRootControllerForView(view);
        if (homeVC) {
            CGRect originalRootRect = MMOriginalFoldRectInRoot(view);
            CGRect incomingRootRect = [view.superview convertRect:frame toView:homeVC.view];

            if (fabs(incomingRootRect.origin.y - originalRootRect.origin.y) > 0.5 ||
                fabs(incomingRootRect.origin.x - originalRootRect.origin.x) > 0.5 ||
                fabs(incomingRootRect.size.width - originalRootRect.size.width) > 0.5) {

                incomingRootRect.origin.x = originalRootRect.origin.x;
                incomingRootRect.origin.y = originalRootRect.origin.y;
                incomingRootRect.size.width = originalRootRect.size.width;
                frame = [view.superview convertRect:incomingRootRect fromView:homeVC.view];
            }
        }
    }
    %orig(frame);
}

- (void)layoutSubviews {
    %orig;
    UIView *view = (UIView *)self;
    if (MMIsHomeFoldContext(view)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MMLockFoldToTopAbsolutePosition(view);
        });
    }
}

%end

%hook MainFrameTableView

- (void)layoutSubviews {
    %orig;
    UIView *tableView = (UIView *)self;
    if (MMIsHomeFoldContext(tableView)) {
        for (UIView *sub in tableView.subviews) {
            if ([NSStringFromClass([sub class]) isEqualToString:@"MainFrameSectionFoldView"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    MMLockFoldToTopAbsolutePosition(sub);
                });
                break;
            }
        }
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    %orig(contentOffset);
    UIView *tableView = (UIView *)self;
    if (MMIsHomeFoldContext(tableView)) {
        for (UIView *sub in tableView.subviews) {
            if ([NSStringFromClass([sub class]) isEqualToString:@"MainFrameSectionFoldView"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    MMLockFoldToTopAbsolutePosition(sub);
                });
                break;
            }
        }
    }
}

%end
