#import <UIKit/UIKit.h>

static BOOL kMMUpdatingLayout = NO;

static UITabBar *MMFindTabBar(UIViewController *vc) {
    @try {
        id tb = [vc valueForKey:@"tabBar"];
        if ([tb isKindOfClass:[UITabBar class]]) return (UITabBar *)tb;
    } @catch (__unused NSException *e) {
    }

    for (UIView *sub in vc.view.subviews) {
        if ([sub isKindOfClass:[UITabBar class]]) return (UITabBar *)sub;
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBar"]) return (UITabBar *)sub;
    }
    return nil;
}

static UIViewController *MMCurrentContentController(UIViewController *vc) {
    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {
    }

    UIViewController *content = [selected isKindOfClass:[UIViewController class]] ? (UIViewController *)selected : vc;
    if ([content isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)content;
        UIViewController *top = nav.topViewController ?: nav.visibleViewController ?: nav.viewControllers.firstObject;
        return top ?: content;
    }
    return content;
}

static BOOL MMShouldHideFloatingTabBar(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return YES;

    UIViewController *content = MMCurrentContentController(vc);
    NSString *contentName = NSStringFromClass([content class]);
    if ([contentName isEqualToString:@"MinimizeViewController"]) return YES;

    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {
    }

    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        if (nav.viewControllers.count > 0 && nav.topViewController != nav.viewControllers.firstObject) return YES;
        if (nav.presentedViewController) return YES;
    } else if ([content isKindOfClass:[UIViewController class]]) {
        if (content.presentedViewController) return YES;
    }

    return NO;
}

static void MMPrepareTabBar(UITabBar *tabBar) {
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.translucent = YES;
    tabBar.clipsToBounds = NO;

    if (NSClassFromString(@"UITabBarAppearance")) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];
        tabBar.standardAppearance = appearance;
        if ([tabBar respondsToSelector:@selector(setScrollEdgeAppearance:)]) {
            [(id)tabBar performSelector:@selector(setScrollEdgeAppearance:) withObject:appearance];
        }
    }
}

static void MMStyleBarBackground(UITabBar *tabBar) {
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);

        if ([name containsString:@"MMTabBarItemView"]) {
            sub.hidden = NO;
            sub.alpha = 1.0;
            continue;
        }

        if ([name containsString:@"_UIBarBackground"]) {
            sub.hidden = NO;
            sub.alpha = 1.0;
            sub.frame = tabBar.bounds;
            sub.clipsToBounds = NO;
            sub.layer.cornerRadius = CGRectGetHeight(tabBar.bounds) * 0.5;
            if ([sub.layer respondsToSelector:@selector(setCornerCurve:)]) {
                sub.layer.cornerCurve = kCACornerCurveContinuous;
            }
            sub.layer.masksToBounds = NO;
            sub.layer.shadowColor = [UIColor colorWithWhite:0 alpha:0.18].CGColor;
            sub.layer.shadowOpacity = 1.0;
            sub.layer.shadowRadius = 18.0;
            sub.layer.shadowOffset = CGSizeMake(0, 8);

            for (UIView *bgSub in sub.subviews) {
                NSString *bgName = NSStringFromClass([bgSub class]);
                if ([bgName containsString:@"Shadow"]) {
                    bgSub.hidden = YES;
                    bgSub.alpha = 0.0;
                    continue;
                }
                bgSub.hidden = NO;
                bgSub.alpha = 1.0;
                bgSub.frame = sub.bounds;
                bgSub.clipsToBounds = YES;
                bgSub.layer.cornerRadius = CGRectGetHeight(sub.bounds) * 0.5;
                if ([bgSub.layer respondsToSelector:@selector(setCornerCurve:)]) {
                    bgSub.layer.cornerCurve = kCACornerCurveContinuous;
                }
            }
        } else if ([name containsString:@"Background"] || [name containsString:@"Shadow"] || [name containsString:@"BarBackground"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
    }
}

static void MMUpdateTabBarForController(UIViewController *vc) {
    if (kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UITabBar *tabBar = MMFindTabBar(vc);
    UIView *root = vc.view;
    if (!tabBar || !root) {
        kMMUpdatingLayout = NO;
        return;
    }

    if (MMShouldHideFloatingTabBar(vc)) {
        tabBar.hidden = YES;
        kMMUpdatingLayout = NO;
        return;
    }

    tabBar.hidden = NO;

    CGFloat bottomInset = 0.0;
    if ([root respondsToSelector:@selector(safeAreaInsets)]) {
        bottomInset = root.safeAreaInsets.bottom;
    }

    CGFloat margin = 18.0;
    CGFloat height = 87.0;
    CGFloat y = CGRectGetHeight(root.bounds) - bottomInset - height - 10.0;
    CGFloat width = CGRectGetWidth(root.bounds) - margin * 2.0;

    tabBar.transform = CGAffineTransformIdentity;
    tabBar.frame = CGRectMake(margin, y, width, height);
    tabBar.alpha = 1.0;
    tabBar.userInteractionEnabled = YES;

    MMPrepareTabBar(tabBar);
    MMStyleBarBackground(tabBar);

    [root bringSubviewToFront:tabBar];

    kMMUpdatingLayout = NO;
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateTabBarForController((UIViewController *)self);
    });
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdateTabBarForController((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMUpdateTabBarForController((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMUpdateTabBarForController((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateTabBarForController((UIViewController *)self);
    });
}

%end

%hook UITabBar

- (void)setSelectedItem:(UITabBarItem *)item {
    %orig(item);
    UIResponder *r = self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    MMUpdateTabBarForController(vc);
                });
                break;
            }
        }
    }
}

%end
