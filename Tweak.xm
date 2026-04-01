#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 90001;
static NSInteger const kLGStrokeTag = 90002;
static NSInteger const kLGHighlightTag = 90003;

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBarController (LiquidGlass)
- (BOOL)lg_isInChatPage;
- (BOOL)lg_shouldShowFloatingBar;
- (NSArray<UIView *> *)lg_visualItemViews;
- (UIVisualEffectView *)lg_glass;
- (UIView *)lg_stroke;
- (UIView *)lg_highlight;
- (void)lg_cleanSystemBackground;
- (void)lg_layoutFloatingBarAnimated:(BOOL)animated;
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
        if (nav.viewControllers.count > 1) {
            return YES;
        }
        UIViewController *top = nav.topViewController;
        if (top && top.hidesBottomBarWhenPushed) {
            return YES;
        }
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
    if (CGRectGetWidth(self.tabBar.bounds) < 10.0 || CGRectGetHeight(self.tabBar.bounds) < 10.0) return NO;
    if ([self lg_isInChatPage]) return NO;
    return YES;
}

%new
- (NSArray<UIView *> *)lg_visualItemViews {
    NSMutableArray<UIView *> *itemViews = [NSMutableArray array];

    for (UIView *v in self.tabBar.subviews) {
        NSString *cls = NSStringFromClass(v.class);
        if ([cls containsString:@"MMTabBarItemView"] &&
            CGRectGetWidth(v.frame) > 60.0 &&
            CGRectGetHeight(v.frame) > 60.0) {
            [itemViews addObject:v];
        }
    }

    if (itemViews.count == 0) {
        for (UIView *v in self.tabBar.subviews) {
            if ([v isKindOfClass:[UIControl class]] &&
                CGRectGetWidth(v.frame) > 60.0 &&
                CGRectGetHeight(v.frame) > 60.0) {
                [itemViews addObject:v];
            }
        }
    }

    [itemViews sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return itemViews;
}

%new
- (UIVisualEffectView *)lg_glass {
    UIVisualEffectView *glass = (UIVisualEffectView *)[self.tabBar viewWithTag:kLGGlassTag];
    if (glass) return glass;

    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemUltraThinMaterialLight;

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

    UIView *highlight = [[UIView alloc] init];
    highlight.tag = kLGHighlightTag;
    highlight.userInteractionEnabled = NO;
    highlight.hidden = YES;
    [glass.contentView addSubview:highlight];

    [self.tabBar insertSubview:glass atIndex:0];
    return glass;
}

%new
- (UIView *)lg_stroke {
    return [[self lg_glass].contentView viewWithTag:kLGStrokeTag];
}

%new
- (UIView *)lg_highlight {
    return [[self lg_glass].contentView viewWithTag:kLGHighlightTag];
}

%new
- (void)lg_cleanSystemBackground {
    self.tabBar.backgroundImage = UIImage.new;
    self.tabBar.shadowImage = UIImage.new;
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
        if (v.tag == kLGGlassTag) continue;

        NSString *cls = NSStringFromClass(v.class);

        if ([cls containsString:@"_UIBarBackground"] ||
            [cls containsString:@"_UIVisualEffectBackdropView"] ||
            [cls containsString:@"_UIVisualEffectSubview"] ||
            [cls containsString:@"_UIVisualEffectContentView"]) {
            v.alpha = 0.0;
        }
    }
}

%new
- (void)lg_layoutFloatingBarAnimated:(BOOL)animated {
    UIVisualEffectView *glass = [self lg_glass];
    UIView *highlight = [self lg_highlight];

    if (![self lg_shouldShowFloatingBar]) {
        glass.hidden = YES;
        glass.alpha = 0.0;
        highlight.hidden = YES;
        return;
    }

    [self lg_cleanSystemBackground];

    NSArray<UIView *> *items = [self lg_visualItemViews];
    if (items.count == 0) {
        glass.hidden = YES;
        glass.alpha = 0.0;
        highlight.hidden = YES;
        return;
    }

    CGFloat margin = 20.0;
    CGFloat height = 62.0;
    CGFloat y = 4.0;
    CGFloat width = CGRectGetWidth(self.tabBar.bounds) - margin * 2.0;

    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemUltraThinMaterialLight;

    glass.hidden = NO;
    glass.alpha = 1.0;
    glass.effect = [UIBlurEffect effectWithStyle:style];
    glass.frame = CGRectMake(margin, y, width, height);
    glass.layer.cornerRadius = height * 0.5;

    UIView *stroke = [self lg_stroke];
    stroke.frame = glass.contentView.bounds;
    stroke.layer.cornerRadius = glass.layer.cornerRadius;
    stroke.layer.borderWidth = 0.6;
    stroke.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.10]
        : [UIColor colorWithWhite:1.0 alpha:0.22]).CGColor;

    [self.tabBar sendSubviewToBack:glass];

    for (UIView *item in items) {
        [self.tabBar bringSubviewToFront:item];
    }

    NSUInteger idx = self.selectedIndex;
    if (idx >= items.count) {
        highlight.hidden = YES;
        return;
    }

    UIView *selectedItem = items[idx];
    CGRect r = [glass.contentView convertRect:selectedItem.frame fromView:selectedItem.superview];

    CGFloat pillW = MIN(66.0, MAX(50.0, CGRectGetWidth(r) - 24.0));
    CGFloat pillH = 40.0;
    CGRect target = CGRectMake(CGRectGetMidX(r) - pillW * 0.5, 6.0, pillW, pillH);

    highlight.backgroundColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : [UIColor colorWithWhite:1.0 alpha:0.20];
    highlight.layer.cornerRadius = pillH * 0.5;
    highlight.layer.borderWidth = 0.6;
    highlight.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.12]
        : [UIColor colorWithWhite:1.0 alpha:0.24]).CGColor;

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
