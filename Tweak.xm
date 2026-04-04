#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static BOOL kMMUpdatingLayout = NO;

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static CGFloat MMBottomInset(UIView *view) {
    if ([view respondsToSelector:@selector(safeAreaInsets)]) {
        return view.safeAreaInsets.bottom;
    }
    return 0.0;
}

static void MMSetRadius(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static CAGradientLayer *MMFindGradient(CALayer *layer, NSString *name) {
    for (CALayer *sub in layer.sublayers) {
        if ([sub isKindOfClass:[CAGradientLayer class]] && [sub.name isEqualToString:name]) {
            return (CAGradientLayer *)sub;
        }
    }
    return nil;
}

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

static BOOL MMShouldShowFloatingBar(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return NO;

    UIViewController *content = MMCurrentContentController(vc);

    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {
    }

    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        if (nav.viewControllers.count > 0 && nav.topViewController != nav.viewControllers.firstObject) return NO;
        if (nav.presentedViewController) return NO;
    } else if ([content isKindOfClass:[UIViewController class]]) {
        if (content.presentedViewController) return NO;
    }

    NSString *contentName = NSStringFromClass([content class]);
    if ([contentName containsString:@"Chat"] || [contentName containsString:@"Room"] || [contentName containsString:@"Message"]) {
        return NO;
    }

    return YES;
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

static void MMUpdate(UIViewController *vc) {
    if (kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!root || !tabBar) {
        kMMUpdatingLayout = NO;
        return;
    }

    if (!MMShouldShowFloatingBar(vc)) {
        tabBar.hidden = YES;
        kMMUpdatingLayout = NO;
        return;
    }

    tabBar.hidden = NO;

    CGFloat inset = MMBottomInset(root);
    CGFloat margin = 18.0;
    CGFloat height = 83.0;
    CGFloat y = CGRectGetHeight(root.bounds) - inset - height - 10.0;
    tabBar.frame = CGRectMake(margin, y, CGRectGetWidth(root.bounds) - margin * 2.0, height);
    tabBar.alpha = 1.0;
    tabBar.userInteractionEnabled = YES;
    MMPrepareTabBar(tabBar);

    [root bringSubviewToFront:tabBar];

    kMMUpdatingLayout = NO;
}

static void MMStyleBarBackgroundView(UIView *bgView) {
    UIView *bar = bgView.superview;
    if (![bar isKindOfClass:[UITabBar class]]) return;

    bgView.frame = bar.bounds;
    bgView.backgroundColor = [UIColor clearColor];
    bgView.clipsToBounds = NO;
    MMSetRadius(bgView, CGRectGetHeight(bgView.bounds) / 2.0);

    bgView.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(bgView.traitCollection) ? 0.24 : 0.12)].CGColor;
    bgView.layer.shadowOpacity = 1.0;
    bgView.layer.shadowRadius = 18.0;
    bgView.layer.shadowOffset = CGSizeMake(0, 8);

    for (UIView *sub in bgView.subviews) {
        NSString *name = NSStringFromClass([sub class]);

        if ([name containsString:@"Shadow"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            continue;
        }

        sub.frame = bgView.bounds;
        sub.hidden = NO;
        sub.alpha = 1.0;
        MMSetRadius(sub, CGRectGetHeight(bgView.bounds) / 2.0);
        sub.clipsToBounds = YES;

        if ([name containsString:@"VisualEffect"] || [name containsString:@"Effect"]) {
            sub.backgroundColor = MMIsDark(bgView.traitCollection) ? MMRGBA(255, 255, 255, 0.05) : MMRGBA(255, 255, 255, 0.13);
        }
    }

    CAGradientLayer *shine = MMFindGradient(bgView.layer, @"mmHostShine");
    if (!shine) {
        shine = [CAGradientLayer layer];
        shine.name = @"mmHostShine";
        [bgView.layer addSublayer:shine];
    }
    shine.frame = CGRectMake(0, 0, CGRectGetWidth(bgView.bounds), CGRectGetHeight(bgView.bounds) * 0.52);
    shine.startPoint = CGPointMake(0.5, 0.0);
    shine.endPoint = CGPointMake(0.5, 1.0);
    shine.colors = @[
        (__bridge id)MMRGBA(255, 255, 255, 0.14).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.05).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.00).CGColor
    ];
}

%hook _UIBarBackground

- (void)layoutSubviews {
    %orig;
    MMStyleBarBackgroundView((UIView *)self);
}

%end

%hook MMTabBarController

- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdate((UIViewController *)self);
    });
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdate((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMUpdate((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMUpdate((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)i {
    %orig(i);
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdate((UIViewController *)self);
    });
}

%end
