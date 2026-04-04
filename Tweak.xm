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

static BOOL MMViewLooksUsable(UIView *view) {
    if (!view) return NO;
    if (view.hidden) return NO;
    if (view.alpha <= 0.01) return NO;
    if (CGRectIsEmpty(view.frame)) return NO;
    return YES;
}

static CGFloat MMNearestUpperBannerBottom(UIView *foldView) {
    UIView *superview = foldView.superview;
    if (!superview) return -1.0;

    CGFloat foldY = CGRectGetMinY(foldView.frame);
    CGFloat bestBottom = -1.0;

    for (UIView *sub in superview.subviews) {
        if (sub == foldView) continue;
        if (!MMViewLooksUsable(sub)) continue;

        CGRect f = sub.frame;
        NSString *name = NSStringFromClass([sub class]);

        if (CGRectGetWidth(f) < 200.0) continue;
        if (CGRectGetHeight(f) < 30.0 || CGRectGetHeight(f) > 70.0) continue;
        if (CGRectGetMinY(f) >= foldY) continue;

        if ([name containsString:@"TableViewCell"] || [name containsString:@"ContentView"] || [name containsString:@"Cell"]) {
            CGFloat bottom = CGRectGetMaxY(f);
            if (bottom > bestBottom) {
                bestBottom = bottom;
            }
        }
    }

    return bestBottom;
}

static CGRect MMFixedFoldFrame(UIView *foldView, CGRect incoming) {
    if (!foldView) return incoming;
    if (!MMIsHomeFoldContext(foldView)) return incoming;

    MMRememberOriginalFoldFrame(foldView);
    CGRect original = MMOriginalFoldFrame(foldView);

    CGFloat upperBottom = MMNearestUpperBannerBottom(foldView);
    CGFloat spacing = 6.67;
    CGFloat targetY = (upperBottom >= 0.0) ? (upperBottom + spacing) : 0.0;

    CGFloat collapsedHeight = CGRectGetHeight(original) > 1.0 ? CGRectGetHeight(original) : 45.33;
    BOOL collapsed = incoming.size.height <= collapsedHeight + 2.0;

    incoming.origin.x = original.origin.x;
    incoming.size.width = original.size.width;

    if (collapsed) {
        incoming.origin.y = targetY;
        incoming.size.height = collapsedHeight;
        return incoming;
    }

    if (incoming.origin.y > targetY + 120.0 || fabs(incoming.origin.x - original.origin.x) > 1.0 || fabs(incoming.size.width - original.size.width) > 1.0) {
        incoming.origin.y = targetY;
        incoming.size.width = original.size.width;
    }

    return incoming;
}

static void MMFixFoldViewIfNeeded(UIView *foldView) {
    if (!foldView) return;
    if (!MMIsHomeFoldContext(foldView)) return;

    CGRect fixed = MMFixedFoldFrame(foldView, foldView.frame);
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
        frame = MMFixedFoldFrame(view, frame);
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
