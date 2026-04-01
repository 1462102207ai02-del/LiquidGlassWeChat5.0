#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 940001;
static NSInteger const kLGStrokeTag = 940002;

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBarController (LiquidGlass)
- (BOOL)lg_isInChatPage;
- (BOOL)lg_shouldShowFloatingBar;
- (UIVisualEffectView *)lg_glassBar;
- (UIView *)lg_strokeView;
- (void)lg_prepareTabBarBackgroundOnly;
- (void)lg_hideFloatingBar;
- (void)lg_layoutFloatingBar;
@end

%hook MMTabBarController

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
    if (!self.isViewLoaded) return NO;
    if (!self.view.window) return NO;
    if (!self.tabBar) return NO;
    if (self.tabBar.hidden) return NO;
    if (self.tabBar.alpha < 0.01) return NO;
    if ([self lg_isInChatPage]) return NO;
    if (CGRectGetWidth(self.tabBar.bounds) < 10.0 || CGRectGetHeight(self.tabBar.bounds) < 10.0) return NO;
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

    [self.view addSubview:glass];
    return glass;
}

%new
- (UIView *)lg_strokeView {
    return [[self lg_glassBar].contentView viewWithTag:kLGStrokeTag];
}

%new
- (void)lg_prepareTabBarBackgroundOnly {
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

    for (UIView *v in self.tabBar.subviews) {
        NSString *cls = NSStringFromClass(v.class);

        if ([cls containsString:@"_UIBarBackground"] ||
            [cls containsString:@"_UIVisualEffectBackdropView"] ||
            [cls containsString:@"_UIVisualEffectSubview"] ||
            [cls containsString:@"_UIVisualEffectContentView"] ||
            [cls containsString:@"UIImageView"]) {
            v.alpha = 0.0;
        }
    }
}

%new
- (void)lg_hideFloatingBar {
    UIVisualEffectView *glass = [self lg_glassBar];
    glass.hidden = YES;
    glass.alpha = 0.0;
}

%new
- (void)lg_layoutFloatingBar {
    if (![self lg_shouldShowFloatingBar]) {
        [self lg_hideFloatingBar];
        return;
    }

    [self lg_prepareTabBarBackgroundOnly];

    CGRect tabFrame = [self.view convertRect:self.tabBar.frame fromView:self.tabBar.superview];

    CGFloat margin = 20.0;
    CGFloat height = 62.0;
    CGFloat lift = 12.0;
    CGFloat width = CGRectGetWidth(self.view.bounds) - margin * 2.0;
    CGFloat y = CGRectGetMinY(tabFrame) + (CGRectGetHeight(tabFrame) - height) * 0.5 - lift;

    UIVisualEffectView *glass = [self lg_glassBar];
    UIView *stroke = [self lg_strokeView];

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
        : [UIColor colorWithWhite:1.0 alpha:0.26]).CGColor;

    [self.view bringSubviewToFront:glass];
    [self.view bringSubviewToFront:self.tabBar];
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self lg_layoutFloatingBar];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self lg_layoutFloatingBar];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    [self lg_layoutFloatingBar];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    [self lg_layoutFloatingBar];
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBar];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBar];
    }
    return ret;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab isKindOfClass:%c(MMTabBarController)]) {
        [(MMTabBarController *)tab lg_layoutFloatingBar];
    }
    return ret;
}

%end
