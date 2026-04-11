#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface MainTabBarViewController : UIViewController
@end

static NSInteger const kHostTag = 990201;
static NSInteger const kBlurTag = 990202;
static NSInteger const kCapsuleTag = 990203;
static BOOL updating = NO;

static BOOL isDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static void setRadius(UIView *view, CGFloat radius) {
    if (!view) return;
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static UITabBar *findTabBar(UIViewController *vc) {
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

static NSArray *itemViews(UITabBar *tabBar) {
    NSMutableArray *arr = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"UITabBarButton"] || [name containsString:@"MMTabBarItemView"]) {
            [arr addObject:sub];
        }
    }
    [arr sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat x1 = CGRectGetMinX(a.frame);
        CGFloat x2 = CGRectGetMinX(b.frame);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return arr;
}

static UIView *floatingHost(UIView *root) {
    UIView *host = [root viewWithTag:kHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kHostTag;
        host.userInteractionEnabled = NO;
        host.backgroundColor = [UIColor clearColor];
        host.clipsToBounds = NO;
        [root addSubview:host];
    }
    return host;
}

static void makeTabBarTransparent(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 1.0;
    tabBar.userInteractionEnabled = YES;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.translucent = YES;
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

static UIVisualEffectView *floatingBlur(UIView *host) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kBlurTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];
    }
    blur.frame = host.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(isDark(host.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    setRadius(blur, CGRectGetHeight(host.bounds) * 0.5);

    UIView *tint = [blur.contentView viewWithTag:990301];
    if (!tint) {
        tint = [UIView new];
        tint.tag = 990301;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = isDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.07] : [UIColor colorWithWhite:1.0 alpha:0.16];
    return blur;
}

static UIView *selectionCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.clipsToBounds = YES;
        [host addSubview:capsule];

        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
            blur.tag = 990304;
            blur.userInteractionEnabled = NO;
            blur.clipsToBounds = YES;
            [capsule addSubview:blur];
        }

        UIView *tint = [UIView new];
        tint.tag = 990305;
        tint.userInteractionEnabled = NO;
        [capsule addSubview:tint];

        UIView *border = [UIView new];
        border.tag = 990306;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        [capsule addSubview:border];
    }
    return capsule;
}

static void styleHost(UIView *host) {
    setRadius(host, CGRectGetHeight(host.bounds) * 0.5);
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = isDark(host.traitCollection) ? 0.14 : 0.11;
    host.layer.shadowRadius = 20.0;
    host.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    host.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:host.bounds cornerRadius:CGRectGetHeight(host.bounds) * 0.5].CGPath;

    UIView *edge = [host viewWithTag:990302];
    if (!edge) {
        edge = [UIView new];
        edge.tag = 990302;
        edge.userInteractionEnabled = NO;
        edge.backgroundColor = [UIColor clearColor];
        [host addSubview:edge];
    }
    edge.frame = host.bounds;
    setRadius(edge, CGRectGetHeight(host.bounds) * 0.5);
    edge.layer.borderWidth = 0.8;
    edge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(isDark(host.traitCollection) ? 0.16 : 0.30)].CGColor;

    UIView *shine = [host viewWithTag:990303];
    if (!shine) {
        shine = [UIView new];
        shine.tag = 990303;
        shine.userInteractionEnabled = NO;
        shine.backgroundColor = [UIColor clearColor];
        shine.clipsToBounds = YES;
        [host addSubview:shine];
    }
    shine.frame = CGRectInset(host.bounds, 1.0, 1.0);
    setRadius(shine, CGRectGetHeight(shine.bounds) * 0.5);

    CAGradientLayer *g = nil;
    for (CALayer *layer in shine.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            g = (CAGradientLayer *)layer;
            break;
        }
    }
    if (!g) {
        g = [CAGradientLayer layer];
        [shine.layer addSublayer:g];
    }
    g.frame = shine.bounds;
    g.startPoint = CGPointMake(0.5, 0.0);
    g.endPoint = CGPointMake(0.5, 1.0);
    g.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(isDark(host.traitCollection) ? 0.16 : 0.26)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(isDark(host.traitCollection) ? 0.04 : 0.07)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    g.locations = @[@0.0, @0.18, @0.42];
    g.cornerRadius = CGRectGetHeight(shine.bounds) * 0.5;
}

static void styleCapsule(UIView *capsule, UIView *host) {
    setRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *blur = [capsule viewWithTag:990304];
    if ([blur isKindOfClass:[UIVisualEffectView class]]) {
        blur.frame = capsule.bounds;
        ((UIVisualEffectView *)blur).effect = [UIBlurEffect effectWithStyle:(isDark(host.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        setRadius(blur, CGRectGetHeight(capsule.bounds) * 0.5);
    }

    UIView *tint = [capsule viewWithTag:990305];
    tint.frame = capsule.bounds;
    tint.backgroundColor = isDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:1.0 alpha:0.20];
    setRadius(tint, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *border = [capsule viewWithTag:990306];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(isDark(host.traitCollection) ? 0.18 : 0.34)].CGColor;
    setRadius(border, CGRectGetHeight(capsule.bounds) * 0.5);
}

static BOOL shouldShowFloatingBar(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return NO;

    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {
    }

    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        UIViewController *root = nav.viewControllers.count > 0 ? [nav.viewControllers objectAtIndex:0] : nil;
        UIViewController *top = nav.topViewController ?: nav.visibleViewController;
        if (root && top && top != root) return NO;
        if (nav.presentedViewController) return NO;
    } else if ([selected isKindOfClass:[UIViewController class]]) {
        UIViewController *child = (UIViewController *)selected;
        if (child.presentedViewController) return NO;
    }

    if (vc.presentedViewController) return NO;
    return YES;
}

static NSInteger selectedIndex(UITabBar *tabBar) {
    if (!tabBar.selectedItem) return 0;
    NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
    return idx == NSNotFound ? 0 : idx;
}

static CGRect hostFrameForTabBar(UIView *root, UITabBar *tabBar) {
    CGFloat sideInset = 16.0;
    CGFloat hostHeight = 64.0;
    CGFloat y = CGRectGetMinY(tabBar.frame) - 6.0;
    return CGRectMake(sideInset, y, CGRectGetWidth(root.bounds) - sideInset * 2.0, hostHeight);
}

static CGRect capsuleFrameForItemView(UIView *itemView, UITabBar *tabBar, UIView *host) {
    CGRect itemRect = [tabBar convertRect:itemView.frame toView:host];
    CGFloat w = MIN(CGRectGetWidth(itemRect) + 16.0, 74.0);
    CGFloat h = CGRectGetHeight(host.bounds) - 12.0;
    CGFloat x = CGRectGetMidX(itemRect) - w * 0.5;
    CGFloat y = (CGRectGetHeight(host.bounds) - h) * 0.5;
    if (x < 4.0) x = 4.0;
    if (x + w > CGRectGetWidth(host.bounds) - 4.0) x = CGRectGetWidth(host.bounds) - 4.0 - w;
    return CGRectMake(x, y, w, h);
}

static void setFloatingVisible(UIView *host, BOOL visible) {
    if (!host) return;
    if (visible) {
        host.hidden = NO;
        host.alpha = 1.0;
    } else {
        host.alpha = 0.0;
        host.hidden = YES;
    }
}

static void updateFloatingBar(UIViewController *vc) {
    if (updating) return;
    updating = YES;

    UITabBar *tabBar = findTabBar(vc);
    if (!tabBar) {
        updating = NO;
        return;
    }

    UIView *root = vc.view;
    UIView *host = floatingHost(root);

    if (!shouldShowFloatingBar(vc)) {
        setFloatingVisible(host, NO);
        updating = NO;
        return;
    }

    makeTabBarTransparent(tabBar);

    host.frame = hostFrameForTabBar(root, tabBar);
    floatingBlur(host);
    styleHost(host);

    NSArray *views = itemViews(tabBar);
    NSInteger sel = selectedIndex(tabBar);
    UIView *capsule = selectionCapsule(host);

    if (sel >= 0 && sel < (NSInteger)[views count]) {
        UIView *itemView = [views objectAtIndex:sel];
        capsule.hidden = NO;
        capsule.frame = capsuleFrameForItemView(itemView, tabBar, host);
        styleCapsule(capsule, host);
    } else {
        capsule.hidden = YES;
    }

    [root insertSubview:host belowSubview:tabBar];
    [root bringSubviewToFront:tabBar];
    setFloatingVisible(host, YES);

    updating = NO;
}

static void requestRefresh(UIViewController *vc) {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        updateFloatingBar(vc);
    });
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    requestRefresh((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    requestRefresh((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    requestRefresh((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    requestRefresh((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    requestRefresh((UIViewController *)self);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    %orig(selectedViewController);
    requestRefresh((UIViewController *)self);
}

%end

%hook UITabBar

- (void)layoutSubviews {
    %orig;
    UIResponder *r = self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                requestRefresh(vc);
                break;
            }
        }
    }
}

- (void)setSelectedItem:(UITabBarItem *)item {
    %orig(item);
    UIResponder *r = self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                requestRefresh(vc);
                break;
            }
        }
    }
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig(viewController, animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                requestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                requestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
    return ret;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                requestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

%end
