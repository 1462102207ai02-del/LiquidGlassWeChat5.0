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

static BOOL MMViewLooksVisible(UIView *view) {
    if (!view) return NO;
    if (view.hidden) return NO;
    if (view.alpha <= 0.01) return NO;
    if (CGRectIsEmpty(view.bounds)) return NO;
    return YES;
}

static CGFloat MMTopBannerBottomForFold(UIView *foldView) {
    UIView *superview = foldView.superview;
    if (!superview) return 0.0;

    CGFloat candidateBottom = 0.0;
    CGRect foldFrame = foldView.frame;

    for (UIView *sub in superview.subviews) {
        if (sub == foldView) continue;
        if (!MMViewLooksVisible(sub)) continue;

        NSString *name = NSStringFromClass([sub class]);

        // 过滤明显无关的小控件/分割线
        if (CGRectGetHeight(sub.bounds) < 20.0) continue;
        if (CGRectGetWidth(sub.bounds) < 120.0) continue;

        CGRect f = sub.frame;

        // 只关心在 fold 上方或与其顶部区域重叠的横幅类视图
        BOOL nearTopArea = CGRectGetMinY(f) < CGRectGetMaxY(foldFrame);
        BOOL notFarBelow = CGRectGetMinY(f) < CGRectGetMinY(foldFrame) + 20.0;
        if (!(nearTopArea && notFarBelow)) continue;

        // 跳过 table 背景/普通 cell 容器
        if ([name containsString:@"Cell"] || [name containsString:@"Wrapper"] || [name containsString:@"Separator"]) continue;

        CGFloat maxY = CGRectGetMaxY(f);
        if (maxY > candidateBottom) {
            candidateBottom = maxY;
        }
    }

    return candidateBottom;
}

static CGRect MMFixedFoldFrameIfNeeded(UIView *foldView, CGRect incoming) {
    if (!foldView) return incoming;
    if (!MMIsHomeFoldContext(foldView)) return incoming;

    MMRememberOriginalFoldFrame(foldView);
    CGRect original = MMOriginalFoldFrame(foldView);

    CGFloat collapsedHeight = CGRectGetHeight(original);
    if (collapsedHeight <= 1.0) collapsedHeight = 45.33;
    BOOL collapsed = incoming.size.height <= collapsedHeight + 2.0;

    if (collapsed) {
        // 收起时不要和上面的“其他设备登录”等横幅重叠
        CGFloat topBannerBottom = MMTopBannerBottomForFold(foldView);
        CGFloat targetY = original.origin.y;

        if (topBannerBottom > 0.0) {
            CGFloat spacing = 8.0;
            CGFloat minY = topBannerBottom + spacing;
            if (minY > targetY) {
                targetY = minY;
            }
        }

        incoming.origin.x = original.origin.x;
        incoming.origin.y = targetY;
        incoming.size.width = original.size.width;
        return incoming;
    }

    // 展开时只拦“被甩到底部”的情况
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
