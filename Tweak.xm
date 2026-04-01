#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kLGFloatingBarTag = 970001;
static NSInteger const kLGStrokeTag = 970002;
static NSInteger const kLGHighlightTag = 970003;

@interface MMTabBar : UITabBar
- (NSArray *)tabBarItemViews;
- (UIView *)backgroundView;
- (void)relayoutTabBarItems;
@end

@interface MMTabBarController : UITabBarController
- (void)selectIndex:(NSUInteger)index;
@end

@interface MMTabBar (LiquidGlass)
- (BOOL)lg_isInChatPage;
- (MMTabBarController *)lg_tabBarController;
- (NSArray<UIView *> *)lg_itemViews;
- (UIVisualEffectView *)lg_floatingBar;
- (UIView *)lg_strokeView;
- (UIView *)lg_highlightView;
- (void)lg_hideFloatingBar;
- (void)lg_layoutFloatingBar;
@end

static const void *kLGLayoutingKey = &kLGLayoutingKey;

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

    MMTabBarController *tabVC = [self lg_tabBarController];
    if (!tabVC) return NO;

    UIViewController *selected = tabVC.selectedViewController;
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
- (MMTabBarController *)lg_tabBarController {
    UIResponder *r = self.nextResponder;
    while (r) {
        if ([r isKindOfClass:%c(MMTabBarController)]) {
            return (MMTabBarController *)r;
        }
        r = r.nextResponder;
    }
    return nil;
}

%new
- (NSArray<UIView *> *)lg_itemViews {
    NSArray *views = nil;

    if ([self respondsToSelector:@selector(tabBarItemViews)]) {
        views = [self tabBarItemViews];
    }

    NSMutableArray<UIView *> *arr = [NSMutableArray array];

    if ([views isKindOfClass:[NSArray class]] && views.count > 0) {
        for (UIView *v in views) {
            if (![v isKindOfClass:[UIView class]]) continue;
            if (CGRectGetWidth(v.frame) < 40.0 || CGRectGetHeight(v.frame) < 40.0) continue;
            [arr addObject:v];
        }
    }

    if (arr.count == 0) {
        for (UIView *v in self.subviews) {
            NSString *cls = NSStringFromClass(v.class);
            if ([cls containsString:@"MMTabBarItemView"] &&
                CGRectGetWidth(v.frame) > 40.0 &&
                CGRectGetHeight(v.frame) > 40.0) {
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
    UIVisualEffectView *bar = (UIVisualEffectView *)[self viewWithTag:kLGFloatingBarTag];
    if (bar) return bar;

    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemThinMaterialLight;

    bar = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
    bar.tag = kLGFloatingBarTag;
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
    highlight.userInteractionEnabled = NO;
    highlight.hidden = YES;
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
    if (bar) {
        bar.hidden = YES;
        bar.alpha = 0.0;
    }
    if (highlight) {
        highlight.hidden = YES;
    }
}

%new
- (void)lg_layoutFloatingBar {
    NSNumber *layouting = objc_getAssociatedObject(self, kLGLayoutingKey);
    if (layouting.boolValue) return;
    objc_setAssociatedObject(self, kLGLayoutingKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    @try {
        if (self.hidden || self.alpha < 0.01 || CGRectGetWidth(self.bounds) < 10.0 || CGRectGetHeight(self.bounds) < 10.0) {
            [self lg_hideFloatingBar];
            objc_setAssociatedObject(self, kLGLayoutingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        if ([self lg_isInChatPage]) {
            [self lg_hideFloatingBar];
            objc_setAssociatedObject(self, kLGLayoutingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        NSArray<UIView *> *items = [self lg_itemViews];
        if (items.count < 2) {
            [self lg_hideFloatingBar];
            objc_setAssociatedObject(self, kLGLayoutingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        self.backgroundImage = [UIImage new];
        self.shadowImage = [UIImage new];
        self.backgroundColor = UIColor.clearColor;
        self.barTintColor = UIColor.clearColor;
        self.translucent = YES;
        self.opaque = NO;
        self.clipsToBounds = NO;

        if ([self respondsToSelector:@selector(backgroundView)]) {
            UIView *bg = [self backgroundView];
            if (bg) bg.alpha = 0.0;
        }

        for (UIView *v in self.subviews) {
            NSString *cls = NSStringFromClass(v.class);
            if ([cls containsString:@"_UIBarBackground"] ||
                [cls containsString:@"UIImageView"]) {
                v.alpha = 0.0;
            }
        }

        UIVisualEffectView *bar = [self lg_floatingBar];
        UIView *stroke = [self lg_strokeView];
        UIView *highlight = [self lg_highlightView];

        CGFloat margin = 20.0;
        CGFloat height = 62.0;
        CGFloat y = 4.0;
        CGFloat width = CGRectGetWidth(self.bounds) - margin * 2.0;

        UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIBlurEffectStyleSystemUltraThinMaterialDark
            : UIBlurEffectStyleSystemThinMaterialLight;

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
            : [UIColor colorWithWhite:1.0 alpha:0.24]).CGColor;

        [self sendSubviewToBack:bar];
        for (UIView *item in items) {
            [self bringSubviewToFront:item];
        }

        MMTabBarController *tabVC = [self lg_tabBarController];
        NSUInteger idx = tabVC ? tabVC.selectedIndex : 0;
        if (idx >= items.count) {
            highlight.hidden = YES;
            objc_setAssociatedObject(self, kLGLayoutingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }

        UIView *selectedItem = items[idx];
        CGRect r = [bar.contentView convertRect:selectedItem.frame fromView:selectedItem.superview];

        CGFloat pillW = MIN(66.0, MAX(50.0, CGRectGetWidth(r) - 24.0));
        CGFloat pillH = 40.0;

        highlight.hidden = NO;
        highlight.alpha = 1.0;
        highlight.frame = CGRectMake(CGRectGetMidX(r) - pillW * 0.5, 6.0, pillW, pillH);
        highlight.backgroundColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.14]
            : [UIColor colorWithWhite:1.0 alpha:0.20];
        highlight.layer.cornerRadius = pillH * 0.5;
        highlight.layer.borderWidth = 0.6;
        highlight.layer.borderColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithWhite:1.0 alpha:0.22]).CGColor;
    } @catch (__unused NSException *e) {
    }

    objc_setAssociatedObject(self, kLGLayoutingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
