#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGBarTag = 950001;
static NSInteger const kLGStrokeTag = 950002;
static NSInteger const kLGHighlightTag = 950003;

@interface MMTabBar : UITabBar
@end

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBar (LiquidGlass)
- (BOOL)lg_isInChatPage;
- (NSArray<UIView *> *)lg_itemViews;
- (UIVisualEffectView *)lg_floatingBar;
- (UIView *)lg_strokeView;
- (UIView *)lg_highlightView;
- (void)lg_hideFloatingBar;
- (void)lg_cleanOriginalBackground;
- (void)lg_layoutFloatingBar;
@end

%hook MMTabBar

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

    UIResponder *r = self.nextResponder;
    while (r) {
        if ([r isKindOfClass:%c(MMTabBarController)]) {
            MMTabBarController *tab = (MMTabBarController *)r;
            UIViewController *selected = tab.selectedViewController;

            if ([selected isKindOfClass:[UINavigationController class]]) {
                UINavigationController *nav = (UINavigationController *)selected;
                if (nav.viewControllers.count > 1) return YES;
                UIViewController *top = nav.topViewController;
                if (top && top.hidesBottomBarWhenPushed) return YES;
            } else if (selected && selected.hidesBottomBarWhenPushed) {
                return YES;
            }

            break;
        }
        r = r.nextResponder;
    }

    return NO;
}

%new
- (NSArray<UIView *> *)lg_itemViews {
    NSMutableArray<UIView *> *arr = [NSMutableArray array];

    for (UIView *v in self.subviews) {
        NSString *cls = NSStringFromClass(v.class);
        if ([cls containsString:@"MMTabBarItemView"] &&
            CGRectGetWidth(v.frame) > 60.0 &&
            CGRectGetHeight(v.frame) > 60.0) {
            [arr addObject:v];
        }
    }

    if (arr.count == 0) {
        for (UIView *v in self.subviews) {
            if ([v isKindOfClass:[UIControl class]] &&
                CGRectGetWidth(v.frame) > 60.0 &&
                CGRectGetHeight(v.frame) > 60.0) {
                [arr addObject:v];
            }
        }
    }

    [arr sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return arr;
}

%new
- (UIVisualEffectView *)lg_floatingBar {
    UIVisualEffectView *bar = (UIVisualEffectView *)[self viewWithTag:kLGBarTag];
    if (bar) return bar;

    UIBlurEffectStyle style = UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemThinMaterialLight;

    bar = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
    bar.tag = kLGBarTag;
    bar.userInteractionEnabled = NO;
    bar.clipsToBounds = YES;
    bar.layer.masksToBounds = YES;
    bar.hidden = YES;
    bar.alpha = 0.0;

    UIView *stroke = [[UIView alloc] init];
    stroke.tag = kLGStrokeTag;
    stroke.userInteractionEnabled = NO;
    stroke.backgroundColor = UIColor.clearColor;
    [bar.contentView addSubview:stroke];

    UIView *highlight = [[UIView alloc] init];
    highlight.tag = kLGHighlightTag;
    highlight.hidden = YES;
    highlight.userInteractionEnabled = NO;
    [bar.contentView addSubview:highlight];

    [self insertSubview:bar atIndex:0];
    return bar;
}

%new
- (UIView *)lg_strokeView {
    return [[self lg_floatingBar].contentView viewWithTag:kLGStrokeTag];
}

%new
- (UIView *)lg_highlightView {
    return [[self lg_floatingBar].contentView viewWithTag:kLGHighlightTag];
}

%new
- (void)lg_hideFloatingBar {
    UIVisualEffectView *bar = [self lg_floatingBar];
    UIView *highlight = [self lg_highlightView];
    bar.hidden = YES;
    bar.alpha = 0.0;
    highlight.hidden = YES;
}

%new
- (void)lg_cleanOriginalBackground {
    self.backgroundImage = [UIImage new];
    self.shadowImage = [UIImage new];
    self.backgroundColor = UIColor.clearColor;
    self.barTintColor = UIColor.clearColor;
    self.translucent = YES;
    self.opaque = NO;
    self.clipsToBounds = NO;

    UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundEffect = nil;
    appearance.backgroundColor = UIColor.clearColor;
    appearance.shadowColor = UIColor.clearColor;
    self.standardAppearance = appearance;

    for (UIView *v in self.subviews) {
        if (v.tag == kLGBarTag) continue;

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
- (void)lg_layoutFloatingBar {
    if (self.hidden || self.alpha < 0.01 || [self lg_isInChatPage]) {
        [self lg_hideFloatingBar];
        return;
    }

    NSArray<UIView *> *items = [self lg_itemViews];
    if (items.count == 0) {
        [self lg_hideFloatingBar];
        return;
    }

    [self lg_cleanOriginalBackground];

    UIVisualEffectView *bar = [self lg_floatingBar];
    UIView *stroke = [self lg_strokeView];
    UIView *highlight = [self lg_highlightView];

    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemThinMaterialLight;

    CGFloat margin = 20.0;
    CGFloat height = 62.0;
    CGFloat y = 4.0;
    CGFloat width = CGRectGetWidth(self.bounds) - margin * 2.0;

    bar.hidden = NO;
    bar.alpha = 1.0;
    bar.effect = [UIBlurEffect effectWithStyle:style];
    bar.frame = CGRectMake(margin, y, width, height);
    bar.layer.cornerRadius = height * 0.5;

    stroke.frame = bar.contentView.bounds;
    stroke.layer.cornerRadius = bar.layer.cornerRadius;
    stroke.layer.borderWidth = 0.6;
    stroke.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.12]
        : [UIColor colorWithWhite:1.0 alpha:0.26]).CGColor;

    [self sendSubviewToBack:bar];

    UIResponder *r = self.nextResponder;
    NSUInteger selectedIndex = 0;
    while (r) {
        if ([r isKindOfClass:%c(MMTabBarController)]) {
            selectedIndex = [(MMTabBarController *)r selectedIndex];
            break;
        }
        r = r.nextResponder;
    }

    if (selectedIndex >= items.count) {
        highlight.hidden = YES;
        return;
    }

    UIView *selectedItem = items[selectedIndex];
    CGRect rct = [bar.contentView convertRect:selectedItem.frame fromView:selectedItem.superview];

    CGFloat pillW = MIN(66.0, MAX(50.0, CGRectGetWidth(rct) - 24.0));
    CGFloat pillH = 40.0;

    highlight.hidden = NO;
    highlight.alpha = 1.0;
    highlight.frame = CGRectMake(CGRectGetMidX(rct) - pillW * 0.5, 6.0, pillW, pillH);
    highlight.backgroundColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : [UIColor colorWithWhite:1.0 alpha:0.20];
    highlight.layer.cornerRadius = pillH * 0.5;
    highlight.layer.borderWidth = 0.6;
    highlight.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.12]
        : [UIColor colorWithWhite:1.0 alpha:0.24]).CGColor;

    for (UIView *item in items) {
        [self bringSubviewToFront:item];
    }
}

- (void)layoutSubviews {
    %orig;
    [self lg_layoutFloatingBar];
}

%end

%hook MMTabBarController

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    if ([self.tabBar isKindOfClass:%c(MMTabBar)]) {
        [(MMTabBar *)self.tabBar lg_layoutFloatingBar];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([self.tabBar isKindOfClass:%c(MMTabBar)]) {
        [(MMTabBar *)self.tabBar lg_layoutFloatingBar];
    }
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab.tabBar isKindOfClass:%c(MMTabBar)]) {
        [(MMTabBar *)tab.tabBar lg_layoutFloatingBar];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab.tabBar isKindOfClass:%c(MMTabBar)]) {
        [(MMTabBar *)tab.tabBar lg_layoutFloatingBar];
    }
    return ret;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *ret = %orig;
    UITabBarController *tab = self.tabBarController;
    if ([tab.tabBar isKindOfClass:%c(MMTabBar)]) {
        [(MMTabBar *)tab.tabBar lg_layoutFloatingBar];
    }
    return ret;
}

%end
