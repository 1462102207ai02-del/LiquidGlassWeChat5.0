#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kMMFoldOriginalFrameKey = &kMMFoldOriginalFrameKey;
static const void *kMMTopBannerLastFrameKey = &kMMTopBannerLastFrameKey;

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
    if (!foldView || !MMIsHomeFoldContext(foldView)) return;
    NSValue *stored = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameKey);
    if (!stored) {
        objc_setAssociatedObject(foldView, kMMFoldOriginalFrameKey, [NSValue valueWithCGRect:foldView.frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGRect MMOriginalFoldFrame(UIView *foldView) {
    NSValue *stored = objc_getAssociatedObject(foldView, kMMFoldOriginalFrameKey);
    return stored ? [stored CGRectValue] : foldView.frame;
}

static BOOL MMViewLooksVisible(UIView *view) {
    if (!view) return NO;
    if (view.hidden) return NO;
    if (view.alpha <= 0.01) return NO;
    if (CGRectIsEmpty(view.frame)) return NO;
    return YES;
}

static UIView *MMFindTopBannerSibling(UIView *foldView) {
    UIView *superview = foldView.superview;
    if (!superview) return nil;

    CGRect original = MMOriginalFoldFrame(foldView);
    UIView *best = nil;
    CGFloat bestBottom = 0.0;

    for (UIView *sub in superview.subviews) {
        if (sub == foldView) continue;
        if (!MMViewLooksVisible(sub)) continue;

        NSString *name = NSStringFromClass([sub class]);
        CGRect f = sub.frame;

        if (CGRectGetWidth(f) < 200.0) continue;
        if (CGRectGetHeight(f) < 24.0 || CGRectGetHeight(f) > 90.0) continue;

        if ([name containsString:@"Table"] || [name containsString:@"Cell"] || [name containsString:@"Wrapper"] || [name containsString:@"Separator"]) continue;

        if (CGRectGetMinY(f) > original.origin.y + 4.0) continue;

        CGFloat bottom = CGRectGetMaxY(f);
        if (bottom > bestBottom) {
            bestBottom = bottom;
            best = sub;
        }
    }

    return best;
}

static CGFloat MMAnchorYForFold(UIView *foldView) {
    CGRect original = MMOriginalFoldFrame(foldView);
    UIView *topBanner = MMFindTopBannerSibling(foldView);

    if (topBanner) {
        CGRect bannerFrame = topBanner.frame;
        objc_setAssociatedObject(foldView, kMMTopBannerLastFrameKey, [NSValue valueWithCGRect:bannerFrame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return CGRectGetMaxY(bannerFrame) + 8.0;
    }

    NSValue *storedBanner = objc_getAssociatedObject(foldView, kMMTopBannerLastFrameKey);
    if (storedBanner) {
        CGRect lastBannerFrame = [storedBanner CGRectValue];
        return lastBannerFrame.origin.y;
    }

    return original.origin.y;
}

static CGRect MMFixedFoldFrameIfNeeded(UIView *foldView, CGRect incoming) {
    if (!foldView || !MMIsHomeFoldContext(foldView)) return incoming;

    MMRememberOriginalFoldFrame(foldView);
    CGRect original = MMOriginalFoldFrame(foldView);
    CGFloat anchorY = MMAnchorYForFold(foldView);

    incoming.origin.x = original.origin.x;
    incoming.origin.y = anchorY;
    incoming.size.width = original.size.width;

    return incoming;
}

static void MMFixFoldViewIfNeeded(UIView *foldView) {
    if (!foldView || !MMIsHomeFoldContext(foldView)) return;
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
