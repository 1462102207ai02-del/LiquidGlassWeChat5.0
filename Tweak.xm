#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 730001;
static NSInteger const kLGStrokeTag = 730002;
static NSInteger const kLGHighlightTag = 730003;

@interface MainTabBarViewController : UIViewController
@end

@interface MMTabBarController : UITabBarController
@end

@interface MainTabBarViewController (LiquidGlass)
- (MMTabBarController *)lg_tabController;
- (UITabBar *)lg_realTabBar;
- (UINavigationController *)lg_selectedNavigationController;
- (UIVisualEffectView *)lg_glassBar;
- (UIView *)lg_strokeView;
- (UIView *)lg_highlightView;
- (NSArray<UIControl *> *)lg_tabButtons;
- (UIBlurEffectStyle)lg_blurStyle;
- (UIColor *)lg_strokeColor;
- (UIColor *)lg_highlightColor;
- (BOOL)lg_shouldShowFloatingBar;
- (void)lg_prepareTabBar;
- (void)lg_layoutGlassBar;
- (void)lg_updateSelectionHighlightAnimated:(BOOL)animated;
- (void)lg_hideFloatingBar;
- (void)lg_refreshFloatingBarAnimated:(BOOL)animated;
@end

%hook MainTabBarViewController

%new
- (MMTabBarController *)lg_tabController {
    for (UIViewController *vc in self.childViewControllers) {
        if ([vc isKindOfClass:%c(MMTabBarController)]) {
            return (MMTabBarController *)vc;
        }
        for (UIViewController *child in vc.childViewControllers) {
            if ([child isKindOfClass:%c(MMTabBarController)]) {
                return (MMTabBarController *)child;
            }
        }
    }

    for (UIView *sub in self.view.subviews) {
        UIResponder *responder = sub.nextResponder;
        while (responder) {
            if ([responder isKindOfClass:%c(MMTabBarController)]) {
                return (MMTabBarController *)responder;
            }
            responder = [responder nextResponder];
        }
    }

    return nil;
}

%new
- (UITabBar *)lg_realTabBar {
    MMTabBarController *tabVC = [self lg_tabController];
    if (tabVC && tabVC.tabBar) {
        return tabVC.tabBar;
    }

    for (UIView *sub in self.view.subviews) {
        if ([sub isKindOfClass:[UITabBar class]]) {
            return (UITabBar *)sub;
        }
        for (UIView *child in sub.subviews) {
            if ([child isKindOfClass:[UITabBar class]]) {
                return (UITabBar *)child;
            }
        }
    }

    return nil;
}

%new
- (UINavigationController *)lg_selectedNavigationController {
    MMTabBarController *tabVC = [self lg_tabController];
    if (!tabVC) return nil;

    UIViewController *selected = tabVC.selectedViewController;
    if ([selected isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)selected;
    }

    if (selected.navigationController) {
        return selected.navigationController;
    }

    NSMutableArray<UIViewController *> *stack = [NSMutableArray array];
    if (selected) [stack addObject:selected];

    while (stack.count > 0) {
        UIViewController *vc = stack.firstObject;
        [stack removeObjectAtIndex:0];

        if ([vc isKindOfClass:[UINavigationController class]]) {
            return (UINavigationController *)vc;
        }

        if (vc.navigationController) {
            return vc.navigationController;
        }

        for (UIViewController *child in vc.childViewControllers) {
            [stack addObject:child];
        }
    }

    return nil;
}

%new
- (UIBlurEffectStyle)lg_blurStyle {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemThinMaterialLight;
}

%new
- (UIColor *)lg_strokeColor {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.10]
        : [UIColor colorWithWhite:1.0 alpha:0.26];
}

%new
- (UIColor *)lg_highlightColor {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : [UIColor colorWithWhite:1.0 alpha:0.20];
}

%new
- (UIVisualEffectView *)lg_glassBar {
    UITabBar *tabBar = [self lg_realTabBar];
    if (!tabBar) return nil;

    UIVisualEffectView *glass = (UIVisualEffectView *)[tabBar viewWithTag:kLGGlassTag];
    if (glass) return glass;

    glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self lg_blurStyle]]];
    glass.tag = kLGGlassTag;
    glass.userInteractionEnabled = NO;
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
    highlight.userInteractionEnabled = NO;
    highlight.hidden = YES;
    [glass.contentView addSubview:highlight];

    [tabBar insertSubview:glass atIndex:0];
    return glass;
}

%new
- (UIView *)lg_strokeView {
    return [[self lg_glassBar].contentView viewWithTag:kLGStrokeTag];
}

%new
- (UIView *)lg_highlightView {
    return [[self lg_glassBar].contentView viewWithTag:kLGHighlightTag];
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
- (BOOL)lg_shouldShowFloatingBar {
    MMTabBarController *tabVC = [self lg_tabController];
    UITabBar *tabBar = [self lg_realTabBar];
    if (!tabVC || !tabBar) return NO;
    if (!self.isViewLoaded) return NO;
    if (!self.view.window) return NO;
    if (tabBar.hidden) return NO;
    if (tabBar.alpha < 0.01) return NO;
    if (CGRectGetWidth(tabBar.bounds) < 10.0 || CGRectGetHeight(tabBar.bounds) < 10.0) return NO;

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (buttons.count < 2) return NO;

    UINavigationController *nav = [self lg_selectedNavigationController];
    if (nav) {
        if (nav.viewControllers.count > 1) return NO;
        UIViewController *top = nav.topViewController;
        if (top && top.hidesBottomBarWhenPushed) return NO;
    } else {
        UIViewController *selected = tabVC.selectedViewController;
        if (selected && selected.hidesBottomBarWhenPushed) return NO;
    }

    CGRect frame = [tabBar.superview convertRect:tabBar.frame toView:self.view];
    CGFloat viewH = CGRectGetHeight(self.view.bounds);
    if (CGRectGetMinY(frame) < viewH - 120.0) return NO;

    return YES;
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
- (void)lg_prepareTabBar {
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
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"_UIBarBackground"]) {
            sub.alpha = 0.0;
        }
    }
}

%new
- (void)lg_layoutGlassBar {
    UITabBar *tabBar = [self lg_realTabBar];
    UIVisualEffectView *glass = [self lg_glassBar];
    if (!tabBar || !glass) return;

    if (![self lg_shouldShowFloatingBar]) {
        [self lg_hideFloatingBar];
        return;
    }

    CGFloat margin = 20.0;
    CGFloat height = 62.0;
    CGFloat width = CGRectGetWidth(tabBar.bounds) - margin * 2.0;
    CGFloat y = 5.0;

    glass.hidden = NO;
    glass.alpha = 1.0;
    glass.effect = [UIBlurEffect effectWithStyle:[self lg_blurStyle]];
    glass.frame = CGRectMake(margin, y, width, height);
    glass.layer.cornerRadius = height * 0.5;

    UIView *stroke = [self lg_strokeView];
    stroke.frame = glass.contentView.bounds;
    stroke.layer.cornerRadius = glass.layer.cornerRadius;
    stroke.layer.borderWidth = 0.6;
    stroke.layer.borderColor = [self lg_strokeColor].CGColor;

    UIView *highlight = [self lg_highlightView];
    highlight.backgroundColor = [self lg_highlightColor];

    [tabBar sendSubviewToBack:glass];

    for (UIControl *btn in [self lg_tabButtons]) {
        [tabBar bringSubviewToFront:btn];
    }
}

%new
- (void)lg_updateSelectionHighlightAnimated:(BOOL)animated {
    UIView *highlight = [self lg_highlightView];
    UIVisualEffectView *glass = [self lg_glassBar];
    MMTabBarController *tabVC = [self lg_tabController];
    if (!highlight || !glass || !tabVC) return;

    if (![self lg_shouldShowFloatingBar]) {
        highlight.hidden = YES;
        return;
    }

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (buttons.count == 0 || tabVC.selectedIndex >= buttons.count) {
        highlight.hidden = YES;
        return;
    }

    UIControl *selectedButton = buttons[tabVC.selectedIndex];
    CGRect r = [glass.contentView convertRect:selectedButton.frame fromView:selectedButton.superview];

    CGFloat pillW = MIN(64.0, MAX(50.0, CGRectGetWidth(r) - 28.0));
    CGFloat pillH = 40.0;
    CGRect target = CGRectMake(CGRectGetMidX(r) - pillW * 0.5, 6.0, pillW, pillH);

    highlight.layer.cornerRadius = pillH * 0.5;
    highlight.layer.borderWidth = 0.6;
    highlight.layer.borderColor = [self lg_strokeColor].CGColor;

    void (^changes)(void) = ^{
        highlight.hidden = NO;
        highlight.frame = target;
        highlight.alpha = 1.0;
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
}

%new
- (void)lg_refreshFloatingBarAnimated:(BOOL)animated {
    [self lg_prepareTabBar];
    [self lg_layoutGlassBar];
    [self lg_updateSelectionHighlightAnimated:animated];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self lg_refreshFloatingBarAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self lg_refreshFloatingBarAnimated:NO];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    [self lg_refreshFloatingBarAnimated:NO];
}

%end

%hook MMTabBarController

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    UIViewController *parent = self.parentViewController;
    if ([parent isKindOfClass:%c(MainTabBarViewController)]) {
        [(MainTabBarViewController *)parent lg_refreshFloatingBarAnimated:YES];
    }
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab.parentViewController isKindOfClass:%c(MainTabBarViewController)]) {
        [(MainTabBarViewController *)tab.parentViewController lg_refreshFloatingBarAnimated:NO];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab.parentViewController isKindOfClass:%c(MainTabBarViewController)]) {
        [(MainTabBarViewController *)tab.parentViewController lg_refreshFloatingBarAnimated:NO];
    }
    return ret;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab.parentViewController isKindOfClass:%c(MainTabBarViewController)]) {
        [(MainTabBarViewController *)tab.parentViewController lg_refreshFloatingBarAnimated:NO];
    }
    return ret;
}

%end
