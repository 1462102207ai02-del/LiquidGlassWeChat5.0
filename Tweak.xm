#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 910001;
static NSInteger const kLGStrokeTag = 910002;
static NSInteger const kLGCloneWrapTag = 910003;
static NSInteger const kLGHighlightTag = 910004;
static NSInteger const kLGTapBaseTag = 911000;
static NSInteger const kLGSnapshotBaseTag = 912000;

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBarController (LiquidGlass)
- (UITabBar *)lg_realTabBar;
- (NSArray<UIControl *> *)lg_tabButtons;
- (BOOL)lg_isInChatPage;
- (BOOL)lg_shouldShowFloatingBar;
- (UIVisualEffectView *)lg_glassBar;
- (UIView *)lg_strokeView;
- (UIView *)lg_cloneWrap;
- (UIView *)lg_highlightView;
- (void)lg_prepareTabBarCarrier;
- (void)lg_hideFloatingBar;
- (void)lg_handleCloneTap:(UIButton *)sender;
- (void)lg_rebuildSnapshotsIfNeeded;
- (void)lg_layoutFloatingBarAnimated:(BOOL)animated;
@end

%hook MMTabBarController

%new
- (UITabBar *)lg_realTabBar {
    if (self.tabBar) return self.tabBar;

    for (UIView *sub in self.view.subviews) {
        if ([sub isKindOfClass:[UITabBar class]]) {
            return (UITabBar *)sub;
        }
    }

    return nil;
}

%new
- (NSArray<UIControl *> *)lg_tabButtons {
    UITabBar *tabBar = [self lg_realTabBar];
    NSMutableArray<UIControl *> *arr = [NSMutableArray array];
    if (!tabBar) return arr;

    for (UIView *sub in tabBar.subviews) {
        if (![sub isKindOfClass:[UIControl class]]) continue;
        if (CGRectGetWidth(sub.frame) < 60.0 || CGRectGetHeight(sub.frame) < 60.0) continue;
        [arr addObject:(UIControl *)sub];
    }

    [arr sortUsingComparator:^NSComparisonResult(UIControl *a, UIControl *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return arr;
}

%new
- (BOOL)lg_isInChatPage {
    for (UIWindow *win in UIApplication.sharedApplication.windows) {
        for (UIView *sub in win.subviews) {
            NSString *cls = NSStringFromClass(sub.class);
            if ([cls containsString:@"MinimizeBaseView"]) {
                return YES;
            }
        }
    }

    UIViewController *selected = self.selectedViewController;
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        if (nav.viewControllers.count > 1) return YES;
        UIViewController *top = nav.topViewController;
        if (top && top.hidesBottomBarWhenPushed) return YES;
    } else if (selected && selected.hidesBottomBarWhenPushed) {
        return YES;
    }

    return NO;
}

%new
- (BOOL)lg_shouldShowFloatingBar {
    UITabBar *tabBar = [self lg_realTabBar];
    if (!tabBar) return NO;
    if (!self.isViewLoaded) return NO;
    if (!self.view.window) return NO;
    if ([self lg_isInChatPage]) return NO;
    if (tabBar.hidden) return NO;
    if (CGRectGetWidth(tabBar.bounds) < 10.0 || CGRectGetHeight(tabBar.bounds) < 10.0) return NO;

    CGRect frame = [self.view convertRect:tabBar.frame fromView:tabBar.superview];
    CGFloat viewH = CGRectGetHeight(self.view.bounds);
    if (CGRectGetMinY(frame) < viewH - 140.0) return NO;

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (buttons.count < 2) return NO;

    return YES;
}

%new
- (UIVisualEffectView *)lg_glassBar {
    UIVisualEffectView *glass = (UIVisualEffectView *)[self.view viewWithTag:kLGGlassTag];
    if (glass) return glass;

    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemThinMaterialLight;

    glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
    glass.tag = kLGGlassTag;
    glass.userInteractionEnabled = YES;
    glass.clipsToBounds = YES;
    glass.layer.masksToBounds = YES;
    glass.hidden = YES;
    glass.alpha = 0.0;

    UIView *stroke = [[UIView alloc] init];
    stroke.tag = kLGStrokeTag;
    stroke.userInteractionEnabled = NO;
    stroke.backgroundColor = UIColor.clearColor;
    [glass.contentView addSubview:stroke];

    UIView *highlight = [[UIView alloc] init];
    highlight.tag = kLGHighlightTag;
    highlight.hidden = YES;
    highlight.userInteractionEnabled = NO;
    [glass.contentView addSubview:highlight];

    UIView *wrap = [[UIView alloc] init];
    wrap.tag = kLGCloneWrapTag;
    wrap.backgroundColor = UIColor.clearColor;
    [glass.contentView addSubview:wrap];

    [self.view addSubview:glass];
    return glass;
}

%new
- (UIView *)lg_strokeView {
    return [[self lg_glassBar].contentView viewWithTag:kLGStrokeTag];
}

%new
- (UIView *)lg_cloneWrap {
    return [[self lg_glassBar].contentView viewWithTag:kLGCloneWrapTag];
}

%new
- (UIView *)lg_highlightView {
    return [[self lg_glassBar].contentView viewWithTag:kLGHighlightTag];
}

%new
- (void)lg_prepareTabBarCarrier {
    UITabBar *tabBar = [self lg_realTabBar];
    if (!tabBar) return;

    tabBar.hidden = NO;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = UIColor.clearColor;
    tabBar.barTintColor = UIColor.clearColor;
    tabBar.translucent = YES;
    tabBar.opaque = NO;
    tabBar.clipsToBounds = NO;

    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    tabBar.standardAppearance = appearance;

    for (UIView *sub in tabBar.subviews) {
        NSString *cls = NSStringFromClass(sub.class);
        if ([cls containsString:@"_UIBarBackground"] ||
            [cls containsString:@"_UIVisualEffectBackdropView"] ||
            [cls containsString:@"_UIVisualEffectSubview"] ||
            [cls containsString:@"_UIVisualEffectContentView"] ||
            [cls containsString:@"UIImageView"]) {
            sub.alpha = 0.0;
        }
    }

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    for (UIControl *btn in buttons) {
        btn.alpha = 0.01;
    }
}

%new
- (void)lg_hideFloatingBar {
    UIVisualEffectView *glass = [self lg_glassBar];
    UIView *highlight = [self lg_highlightView];
    glass.hidden = YES;
    glass.alpha = 0.0;
    highlight.hidden = YES;
}

%new
- (void)lg_handleCloneTap:(UIButton *)sender {
    NSInteger idx = sender.tag - kLGTapBaseTag;
    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (idx < 0 || idx >= (NSInteger)buttons.count) return;

    if (self.selectedIndex != (NSUInteger)idx) {
        self.selectedIndex = (NSUInteger)idx;
    }

    [self lg_layoutFloatingBarAnimated:YES];
}

%new
- (void)lg_rebuildSnapshotsIfNeeded {
    UIView *wrap = [self lg_cloneWrap];
    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    NSInteger count = buttons.count;

    while (wrap.subviews.count > count * 2) {
        [wrap.subviews.lastObject removeFromSuperview];
    }

    for (NSInteger i = 0; i < count; i++) {
        UIView *snapshot = [wrap viewWithTag:kLGSnapshotBaseTag + i];
        UIButton *tap = (UIButton *)[wrap viewWithTag:kLGTapBaseTag + i];

        if (!snapshot) {
            UIView *snap = [buttons[i] snapshotViewAfterScreenUpdates:YES];
            if (!snap) {
                snap = [[UIView alloc] initWithFrame:buttons[i].bounds];
                snap.backgroundColor = UIColor.clearColor;
            }
            snap.tag = kLGSnapshotBaseTag + i;
            snap.userInteractionEnabled = NO;
            [wrap addSubview:snap];
            snapshot = snap;
        }

        if (!tap) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.tag = kLGTapBaseTag + i;
            btn.backgroundColor = UIColor.clearColor;
            [btn addTarget:self action:@selector(lg_handleCloneTap:) forControlEvents:UIControlEventTouchUpInside];
            [wrap addSubview:btn];
            tap = btn;
        }

        UIView *fresh = [buttons[i] snapshotViewAfterScreenUpdates:YES];
        if (fresh) {
            fresh.frame = snapshot.frame;
            fresh.tag = snapshot.tag;
            fresh.userInteractionEnabled = NO;
            [snapshot removeFromSuperview];
            [wrap addSubview:fresh];
            snapshot = fresh;
        }

        [wrap bringSubviewToFront:tap];
    }
}

%new
- (void)lg_layoutFloatingBarAnimated:(BOOL)animated {
    UIVisualEffectView *glass = [self lg_glassBar];
    UIView *wrap = [self lg_cloneWrap];
    UIView *stroke = [self lg_strokeView];
    UIView *highlight = [self lg_highlightView];

    if (![self lg_shouldShowFloatingBar]) {
        [self lg_hideFloatingBar];
        return;
    }

    [self lg_prepareTabBarCarrier];

    UITabBar *tabBar = [self lg_realTabBar];
    CGRect tabFrame = [self.view convertRect:tabBar.frame fromView:tabBar.superview];

    CGFloat margin = 20.0;
    CGFloat height = 62.0;
    CGFloat lift = 12.0;
    CGFloat width = CGRectGetWidth(self.view.bounds) - margin * 2.0;
    CGFloat y = CGRectGetMinY(tabFrame) + (CGRectGetHeight(tabFrame) - height) * 0.5 - lift;

    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemThinMaterialLight;

    glass.hidden = NO;
    glass.alpha = 1.0;
    glass.effect = [UIBlurEffect effectWithStyle:style];
    glass.frame = CGRectMake(margin, y, width, height);
    glass.layer.cornerRadius = height * 0.5;

    stroke.frame = glass.contentView.bounds;
    stroke.layer.cornerRadius = glass.layer.cornerRadius;
    stroke.layer.borderWidth = 0.6;
    stroke.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.12]
        : [UIColor colorWithWhite:1.0 alpha:0.28]).CGColor;

    wrap.frame = glass.contentView.bounds;

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    [self lg_rebuildSnapshotsIfNeeded];

    if (buttons.count == 0) {
        [self lg_hideFloatingBar];
        return;
    }

    CGFloat itemW = CGRectGetWidth(wrap.bounds) / MAX((NSInteger)buttons.count, 1);

    for (NSInteger i = 0; i < (NSInteger)buttons.count; i++) {
        UIView *snapshot = [wrap viewWithTag:kLGSnapshotBaseTag + i];
        UIButton *tap = (UIButton *)[wrap viewWithTag:kLGTapBaseTag + i];

        CGRect sourceInGlass = [wrap convertRect:buttons[i].frame fromView:buttons[i].superview];
        CGRect frame = CGRectMake(i * itemW, 0.0, itemW, CGRectGetHeight(wrap.bounds));

        tap.frame = frame;

        if (snapshot) {
            CGFloat dx = CGRectGetMidX(frame) - CGRectGetMidX(sourceInGlass);
            CGFloat dy = -4.0;
            snapshot.frame = CGRectOffset(sourceInGlass, dx, dy);
        }

        [wrap bringSubviewToFront:tap];
    }

    if (self.selectedIndex < buttons.count) {
        CGRect selectedInGlass = [wrap convertRect:buttons[self.selectedIndex].frame fromView:buttons[self.selectedIndex].superview];
        CGFloat pillW = MIN(66.0, MAX(50.0, CGRectGetWidth(selectedInGlass) - 22.0));
        CGFloat pillH = 40.0;
        CGRect target = CGRectMake(CGRectGetMidX(selectedInGlass) - pillW * 0.5, 6.0, pillW, pillH);

        highlight.backgroundColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.14]
            : [UIColor colorWithWhite:1.0 alpha:0.22];
        highlight.layer.cornerRadius = pillH * 0.5;
        highlight.layer.borderWidth = 0.6;
        highlight.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithWhite:1.0 alpha:0.26]).CGColor;

        void (^changes)(void) = ^{
            highlight.hidden = NO;
            highlight.alpha = 1.0;
            highlight.frame = target;
        };

        if (animated) {
            [UIView animateWithDuration:0.24
                                  delay:0.0
                 usingSpringWithDamping:0.84
                  initialSpringVelocity:0.0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                             animations:changes
                             completion:nil];
        } else {
            changes();
        }
    } else {
        highlight.hidden = YES;
    }

    [self.view bringSubviewToFront:glass];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self lg_layoutFloatingBarAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self lg_layoutFloatingBarAnimated:NO];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    [self lg_layoutFloatingBarAnimated:YES];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    [self lg_layoutFloatingBarAnimated:NO];
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBarAnimated:NO];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBarAnimated:NO];
    }
    return ret;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBarAnimated:NO];
    }
    return ret;
}

%end
