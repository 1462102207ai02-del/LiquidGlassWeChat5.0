#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface MainTabBarViewController : UIViewController
@end

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingCapsuleTag = 990203;
static BOOL kMMUpdatingLayout = NO;

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static void MMSetRadius(UIView *view, CGFloat radius) {
    if (!view) return;
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
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

static NSArray *MMOriginalItemViews(UITabBar *tabBar) {
    NSMutableArray *items = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBarItemView"] || [name containsString:@"UITabBarButton"]) {
            [items addObject:sub];
        }
    }
    [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat x1 = CGRectGetMinX(a.frame);
        CGFloat x2 = CGRectGetMinX(b.frame);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return items;
}

static NSInteger MMSelectedIndex(UITabBar *tabBar) {
    NSArray *items = tabBar.items;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) return idx;
    }
    return 0;
}

static BOOL MMShouldShowFloatingBar(UIViewController *vc) {
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
        UIViewController *root = nav.viewControllers.count > 0 ? nav.viewControllers.firstObject : nil;
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

static UIView *MMHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMFloatingHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMFloatingHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = NO;
        host.clipsToBounds = NO;
        [root addSubview:host];
    }
    return host;
}

static UIVisualEffectView *MMBlur(UIView *host) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMFloatingBlurTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];
    }
    blur.frame = host.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, CGRectGetHeight(host.bounds) * 0.5);

    UIView *tint = [blur.contentView viewWithTag:990301];
    if (!tint) {
        tint = [UIView new];
        tint.tag = 990301;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.07] : [UIColor colorWithWhite:1.0 alpha:0.17];
    return blur;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMFloatingCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMFloatingCapsuleTag;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.userInteractionEnabled = NO;
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

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, CGRectGetHeight(host.bounds) * 0.5);
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = MMIsDark(host.traitCollection) ? 0.12 : 0.10;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0.0, 8.0);
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
    MMSetRadius(edge, CGRectGetHeight(host.bounds) * 0.5);
    edge.layer.borderWidth = 0.8;
    edge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.16 : 0.30)].CGColor;

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
    MMSetRadius(shine, CGRectGetHeight(shine.bounds) * 0.5);

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
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.16 : 0.28)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.04 : 0.07)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    g.locations = @[@0.0, @0.16, @0.42];
    g.cornerRadius = CGRectGetHeight(shine.bounds) * 0.5;
}

static void MMStyleCapsule(UIView *capsule, UIView *host) {
    MMSetRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *selBlur = [capsule viewWithTag:990304];
    if ([selBlur isKindOfClass:[UIVisualEffectView class]]) {
        selBlur.frame = capsule.bounds;
        ((UIVisualEffectView *)selBlur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        MMSetRadius(selBlur, CGRectGetHeight(capsule.bounds) * 0.5);
    }

    UIView *tint = [capsule viewWithTag:990305];
    tint.frame = capsule.bounds;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:1.0 alpha:0.18];
    MMSetRadius(tint, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *border = [capsule viewWithTag:990306];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.18 : 0.34)].CGColor;
    MMSetRadius(border, CGRectGetHeight(capsule.bounds) * 0.5);
}

static void MMMakeTabBarTransparent(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 1.0;
    tabBar.userInteractionEnabled = YES;
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

    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"Background"] || [name containsString:@"BarBackground"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.userInteractionEnabled = NO;
        } else {
            sub.hidden = NO;
            sub.alpha = 1.0;
            sub.userInteractionEnabled = YES;
        }
    }
}

static CGRect MMHostFrameForTabBar(UIView *root, UITabBar *tabBar) {
    CGRect tabFrame = tabBar.frame;
    CGFloat sideInset = 16.0;
    CGFloat availableH = CGRectGetHeight(tabFrame) - 6.0;
    CGFloat hostH = availableH > 64.0 ? 64.0 : availableH;
    if (hostH < 58.0) hostH = availableH;
    CGFloat y = CGRectGetMinY(tabFrame) + 2.0;
    if (availableH > hostH) {
        y = CGRectGetMinY(tabFrame) + (availableH - hostH) * 0.5;
    }
    if (y + hostH > CGRectGetMaxY(tabFrame) - 2.0) {
        y = CGRectGetMaxY(tabFrame) - 2.0 - hostH;
    }
    return CGRectMake(sideInset, y, CGRectGetWidth(root.bounds) - sideInset * 2.0, hostH);
}

static CGRect MMCapsuleFrameForItemView(UIView *itemView, UITabBar *tabBar, UIView *host) {
    CGRect itemRect = [tabBar convertRect:itemView.frame toView:host];
    CGFloat capW = MIN(CGRectGetWidth(itemRect) + 12.0, 74.0);
    CGFloat capH = CGRectGetHeight(host.bounds) - 10.0;
    CGFloat x = CGRectGetMidX(itemRect) - capW * 0.5;
    CGFloat y = (CGRectGetHeight(host.bounds) - capH) * 0.5;
    if (x < 4.0) x = 4.0;
    if (x + capW > CGRectGetWidth(host.bounds) - 4.0) x = CGRectGetWidth(host.bounds) - 4.0 - capW;
    return CGRectMake(x, y, capW, capH);
}

static void MMSetFloatingVisible(UIView *host, BOOL visible) {
    if (!host) return;
    host.userInteractionEnabled = NO;
    if (visible) {
        host.hidden = NO;
        [UIView animateWithDuration:0.16 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{
            host.alpha = 1.0;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.12 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{
            host.alpha = 0.0;
        } completion:^(BOOL finished) {
            if (finished) host.hidden = YES;
        }];
    }
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    UIView *host = MMHost(root);

    if (!root || !tabBar || !MMShouldShowFloatingBar(vc)) {
        MMSetFloatingVisible(host, NO);
        kMMUpdatingLayout = NO;
        return;
    }

    MMMakeTabBarTransparent(tabBar);

    host.frame = MMHostFrameForTabBar(root, tabBar);
    MMStyleHost(host);
    MMBlur(host);

    NSArray *itemViews = MMOriginalItemViews(tabBar);
    NSInteger selectedIndex = MMSelectedIndex(tabBar);
    UIView *capsule = MMCapsule(host);

    if (selectedIndex >= 0 && selectedIndex < (NSInteger)itemViews.count) {
        UIView *itemView = [itemViews objectAtIndex:selectedIndex];
        capsule.hidden = NO;
        capsule.frame = MMCapsuleFrameForItemView(itemView, tabBar, host);
        MMStyleCapsule(capsule, host);
    } else {
        capsule.hidden = YES;
    }

    [root insertSubview:host belowSubview:tabBar];
    [root bringSubviewToFront:tabBar];
    MMSetFloatingVisible(host, YES);

    kMMUpdatingLayout = NO;
}

static void MMRequestFloatingBarRefresh(UIViewController *vc) {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar(vc);
    });
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    %orig(selectedViewController);
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig(selectedIndex);
    MMRequestFloatingBarRefresh((UIViewController *)self);
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
                MMRequestFloatingBarRefresh(vc);
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
                MMRequestFloatingBarRefresh(vc);
                break;
            }
        }
    }
}

%end

%hook UINavigationController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestFloatingBarRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig(viewController, animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestFloatingBarRefresh(vc);
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
                MMRequestFloatingBarRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
    return ret;
}

%end
