#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 920001;
static NSInteger const kLGStrokeTag = 920002;
static NSInteger const kLGCloneWrapTag = 920003;
static NSInteger const kLGHighlightTag = 920004;
static NSInteger const kLGTapBaseTag = 921000;
static NSInteger const kLGSnapshotBaseTag = 922000;

@interface MMTabBar : UITabBar
@end

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
- (void)lg_refreshLater;
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

    CGRect frame = [tabBar.superview convertRect:tabBar.frame toView:self.view];
    CGFloat viewH = CGRectGetHeight(self.view.bounds);
    if (CGRectGetMinY(frame) < viewH - 140.0) return NO;

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (buttons.count < 2) return NO;

    return YES;
}

%new
- (UIVisualEffectView *)lg_glassBar {
    UITabBar *tabBar = [self lg_realTabBar];
    if (!tabBar || !tabBar.superview) return nil;

    UIVisualEffectView *glass = (UIVisualEffectView *)[tabBar.superview viewWithTag:kLGGlassTag];
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

    [tabBar.superview addSubview:glass];
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
            sub.hidden = NO;
        }
    }

    for (UIControl *btn in [self lg_tabButtons]) {
        btn.alpha = 0.01;
        btn.hidden = NO;
    }
}

%new
- (void)lg_hideFloatingBar {
    UIVisualEffectView *glass = [self lg_glassBar];
    UIView *highlight = [self lg_highlightView];
    if (!glass) return;
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

    NSArray *existing = [wrap.subviews copy];
    for (UIView *v in existing) {
        if (v.tag >= kLGSnapshotBaseTag || v.tag >= kLGTapBaseTag) {
            [v removeFromSuperview];
        }
    }

    for (NSInteger i = 0; i < count; i++) {
        UIView *snap = [buttons[i] snapshotViewAfterScreenUpdates:YES];
        if (!snap) {
            snap = [[UIView alloc] initWithFrame:buttons[i].bounds];
            snap.backgroundColor = UIColor.clearColor;
        }
        snap.tag = kLGSnapshotBaseTag + i;
        snap.userInteractionEnabled = NO;
        [wrap addSubview:snap];

        UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
        tap.tag = kLGTapBaseTag + i;
        tap.backgroundColor = UIColor.clearColor;
        [tap addTarget:self action:@selector(lg_handleCloneTap:) forControlEvents:UIControlEventTouchUpInside];
        [wrap addSubview:tap];
    }
}

%new
- (void)lg_layoutFloatingBarAnimated:(BOOL)animated {
    UIVisualEffectView *glass = [self lg_glassBar];
    if (!glass) return;

    UIView *wrap = [self lg_cloneWrap];
    UIView *stroke = [self lg_strokeView];
    UIView *highlight = [self lg_highlightView];

    if (![self lg_shouldShowFloatingBar]) {
        [self lg_hideFloatingBar];
        return;
    }

    [self lg_prepareTabBarCarrier];

    UITabBar *tabBar = [self lg_realTabBar];
    CGRect tabFrame = [tabBar.superview convertRect:tabBar.frame toView:self.view];

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
    if (buttons.count == 0) {
        [self lg_hideFloatingBar];
        return;
    }

    [self lg_rebuildSnapshotsIfNeeded];

    CGFloat itemW = CGRectGetWidth(wrap.bounds) / MAX((NSInteger)buttons.count, 1);

    for (NSInteger i = 0; i < (NSInteger)buttons.count; i++) {
        UIView *snapshot = [wrap viewWithTag:kLGSnapshotBaseTag + i];
        UIButton *tap = (UIButton *)[wrap viewWithTag:kLGTapBaseTag + i];

        CGRect sourceInGlass = [wrap convertRect:buttons[i].frame fromView:buttons[i].superview];
        CGRect slotFrame = CGRectMake(i * itemW, 0.0, itemW, CGRectGetHeight(wrap.bounds));

        tap.frame = slotFrame;

        if (snapshot) {
            CGFloat dx = CGRectGetMidX(slotFrame) - CGRectGetMidX(sourceInGlass);
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

    [glass.superview bringSubviewToFront:glass];
}

%new
- (void)lg_refreshLater {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self lg_layoutFloatingBarAnimated:NO];
    });
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self lg_layoutFloatingBarAnimated:NO];
    [self lg_refreshLater];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self lg_layoutFloatingBarAnimated:NO];
    [self lg_refreshLater];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    [self lg_layoutFloatingBarAnimated:YES];
    [self lg_refreshLater];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    [self lg_layoutFloatingBarAnimated:NO];
    [self lg_refreshLater];
}

%end

%hook MMTabBar

- (void)layoutSubviews {
    %orig;

    UIResponder *responder = self.nextResponder;
    while (responder) {
        if ([responder isKindOfClass:%c(MMTabBarController)]) {
            [(MMTabBarController *)responder lg_layoutFloatingBarAnimated:NO];
            [(MMTabBarController *)responder lg_refreshLater];
            break;
        }
        responder = responder.nextResponder;
    }
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBarAnimated:NO];
        [(MMTabBarController *)tab lg_refreshLater];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBarAnimated:NO];
        [(MMTabBarController *)tab lg_refreshLater];
    }
    return ret;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBarAnimated:NO];
        [(MMTabBarController *)tab lg_refreshLater];
    }
    return ret;
}

%end
