#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 730001;
static NSInteger const kLGStrokeTag = 730002;
static NSInteger const kLGHighlightTag = 730003;

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBarController (LiquidGlass)
- (UIVisualEffectView *)lg_glassBar;
- (UIView *)lg_strokeView;
- (UIView *)lg_highlightView;
- (NSArray<UIControl *> *)lg_tabButtons;
- (UINavigationController *)lg_selectedNavigationController;
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

%hook MMTabBarController

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
        : [UIColor colorWithWhite:1.0 alpha:0.28];
}

%new
- (UIColor *)lg_highlightColor {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : [UIColor colorWithWhite:1.0 alpha:0.22];
}

%new
- (UIVisualEffectView *)lg_glassBar {
    UIVisualEffectView *glass = (UIVisualEffectView *)[self.tabBar viewWithTag:kLGGlassTag];
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

    [self.tabBar insertSubview:glass atIndex:0];
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
    NSMutableArray<UIControl *> *arr = [NSMutableArray array];

    for (UIView *sub in self.tabBar.subviews) {
        if (![sub isKindOfClass:[UIControl class]]) continue;
        if (CGRectGetWidth(sub.frame) < 40.0 || CGRectGetHeight(sub.frame) < 40.0) continue;
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
- (UINavigationController *)lg_selectedNavigationController {
    UIViewController *selected = self.selectedViewController;
    if ([selected isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)selected;
    }

    if (selected.navigationController) {
        return selected.navigationController;
    }

    for (UIViewController *child in selected.childViewControllers) {
        if ([child isKindOfClass:[UINavigationController class]]) {
            return (UINavigationController *)child;
        }
        if (child.navigationController) {
            return child.navigationController;
        }
    }

    return nil;
}

%new
- (BOOL)lg_shouldShowFloatingBar {
    if (!self.isViewLoaded) return NO;
    if (!self.view.window) return NO;
    if (!self.tabBar) return NO;
    if (self.tabBar.hidden) return NO;
    if (self.tabBar.alpha < 0.01) return NO;
    if (CGRectGetWidth(self.tabBar.bounds) < 10.0 || CGRectGetHeight(self.tabBar.bounds) < 10.0) return NO;

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (buttons.count < 2) return NO;

    UINavigationController *nav = [self lg_selectedNavigationController];
    if (nav) {
        if (nav.viewControllers.count > 1) return NO;
        UIViewController *top = nav.topViewController;
        if (top && top.hidesBottomBarWhenPushed) return NO;
    } else {
        UIViewController *selected = self.selectedViewController;
        if (selected && selected.hidesBottomBarWhenPushed) return NO;
    }

    CGRect frame = [self.tabBar.superview convertRect:self.tabBar.frame toView:self.view];
    CGFloat viewH = CGRectGetHeight(self.view.bounds);
    if (CGRectGetMinY(frame) < viewH - 140.0) return NO;

    return YES;
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
- (void)lg_prepareTabBar {
    self.tabBar.hidden = NO;
    self.tabBar.backgroundImage = [UIImage new];
    self.tabBar.shadowImage = [UIImage new];
    self.tabBar.backgroundColor = UIColor.clearColor;
    self.tabBar.barTintColor = UIColor.clearColor;
    self.tabBar.translucent = YES;
    self.tabBar.opaque = NO;
    self.tabBar.clipsToBounds = NO;

    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    self.tabBar.standardAppearance = appearance;

    for (UIView *sub in self.tabBar.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"_UIBarBackground"]) {
            sub.alpha = 0.0;
        }
    }
}

%new
- (void)lg_layoutGlassBar {
    UIVisualEffectView *glass = [self lg_glassBar];
    if (![self lg_shouldShowFloatingBar]) {
        [self lg_hideFloatingBar];
        return;
    }

    CGFloat margin = 20.0;
    CGFloat height = 62.0;
    CGFloat y = 5.0;
    CGFloat width = CGRectGetWidth(self.tabBar.bounds) - margin * 2.0;

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

    [self.tabBar sendSubviewToBack:glass];

    for (UIControl *btn in [self lg_tabButtons]) {
        [self.tabBar bringSubviewToFront:btn];
    }
}

%new
- (void)lg_updateSelectionHighlightAnimated:(BOOL)animated {
    UIView *highlight = [self lg_highlightView];

    if (![self lg_shouldShowFloatingBar]) {
        highlight.hidden = YES;
        return;
    }

    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (buttons.count == 0 || self.selectedIndex >= buttons.count) {
        highlight.hidden = YES;
        return;
    }

    UIControl *selectedButton = buttons[self.selectedIndex];
    UIVisualEffectView *glass = [self lg_glassBar];
    CGRect r = [glass.contentView convertRect:selectedButton.frame fromView:selectedButton.superview];

    CGFloat pillW = MIN(66.0, MAX(50.0, CGRectGetWidth(r) - 24.0));
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

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    [self lg_refreshFloatingBarAnimated:YES];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    [self lg_refreshFloatingBarAnimated:NO];
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_refreshFloatingBarAnimated:NO];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_refreshFloatingBarAnimated:NO];
    }
    return ret;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_refreshFloatingBarAnimated:NO];
    }
    return ret;
}

%end
