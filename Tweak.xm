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

static BOOL MMIsHomeTableContext(UIView *view) {
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

static UIView *MMFindFoldViewInTable(UIView *tableView) {
    for (UIView *sub in tableView.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name isEqualToString:@"MainFrameSectionFoldView"]) {
            return sub;
        }
    }
    return nil;
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

static void MMLockFoldViewTopInTable(UIView *tableView) {
    if (!tableView) return;
    if (!MMIsHomeTableContext(tableView)) return;

    UIView *foldView = MMFindFoldViewInTable(tableView);
    if (!foldView) return;

    MMRememberOriginalFoldFrame(foldView);

    CGRect original = MMOriginalFoldFrame(foldView);
    CGRect current = foldView.frame;

    BOOL movedAway = fabs(current.origin.y - original.origin.y) > 0.5;
    BOOL widthChanged = fabs(current.size.width - original.size.width) > 0.5;

    if (movedAway || widthChanged) {
        current.origin.x = original.origin.x;
        current.origin.y = original.origin.y;
        current.size.width = original.size.width;
        foldView.frame = current;
    }

    [tableView bringSubviewToFront:foldView];
}

%hook MainFrameTableView

- (void)layoutSubviews {
    %orig;
    UIView *tableView = (UIView *)self;
    if (MMIsHomeTableContext(tableView)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MMLockFoldViewTopInTable(tableView);
        });
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    %orig(contentOffset);
    UIView *tableView = (UIView *)self;
    if (MMIsHomeTableContext(tableView)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MMLockFoldViewTopInTable(tableView);
        });
    }
}

%end

%hook MainFrameSectionFoldView

- (void)didMoveToSuperview {
    %orig;
    UIView *foldView = (UIView *)self;
    UIView *superview = foldView.superview;
    if (superview && [NSStringFromClass([superview class]) isEqualToString:@"MainFrameTableView"]) {
        MMRememberOriginalFoldFrame(foldView);
        dispatch_async(dispatch_get_main_queue(), ^{
            MMLockFoldViewTopInTable(superview);
        });
    }
}

- (void)setFrame:(CGRect)frame {
    UIView *foldView = (UIView *)self;
    UIView *tableView = foldView.superview;
    if (tableView && [NSStringFromClass([tableView class]) isEqualToString:@"MainFrameTableView"] && MMIsHomeTableContext(tableView)) {
        MMRememberOriginalFoldFrame(foldView);
        CGRect original = MMOriginalFoldFrame(foldView);

        if (fabs(frame.origin.y - original.origin.y) > 0.5) {
            frame.origin.x = original.origin.x;
            frame.origin.y = original.origin.y;
            frame.size.width = original.size.width;
        }
    }
    %orig(frame);
}

%end
