#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface MainTabBarViewController : UIViewController
@end

static NSInteger const kMMBackdropTag = 996000;
static NSInteger const kMMBackdropBlurTag = 996001;
static NSInteger const kMMBackdropTintTag = 996002;
static NSInteger const kMMGlassTag = 996003;
static NSInteger const kMMGlassBlurTag = 996004;
static NSInteger const kMMGlassTintTag = 996005;
static NSInteger const kMMGlassBorderTag = 996006;
static NSInteger const kMMGlassShineTag = 996007;
static NSInteger const kMMCapsuleTag = 996008;
static NSInteger const kMMCapsuleBlurTag = 996009;
static NSInteger const kMMCapsuleTintTag = 996010;
static NSInteger const kMMCapsuleBorderTag = 996011;
static NSInteger const kMMSearchHostTag = 996012;
static NSInteger const kMMSearchBlurTag = 996013;
static NSInteger const kMMSearchTintTag = 996014;
static NSInteger const kMMSearchIconTag = 996015;
static NSInteger const kMMSearchButtonTag = 996016;

static BOOL kMMUpdating = NO;

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
    if (!vc) return nil;
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

static UIViewController *MMFindHomeController(UIViewController *vc) {
    if (!vc) return nil;
    NSString *name = NSStringFromClass([vc class]);
    if ([name isEqualToString:@"NewMainFrameViewController"]) return vc;

    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        for (UIViewController *child in nav.viewControllers) {
            UIViewController *found = MMFindHomeController(child);
            if (found) return found;
        }
    }

    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *found = MMFindHomeController(child);
        if (found) return found;
    }

    id vcs = nil;
    @try { vcs = [vc valueForKey:@"viewControllers"]; } @catch (__unused NSException *e) {
    }
    if ([vcs isKindOfClass:[NSArray class]]) {
        for (UIViewController *child in (NSArray *)vcs) {
            UIViewController *found = MMFindHomeController(child);
            if (found) return found;
        }
    }
    return nil;
}

static UIView *MMFindSearchBarInView(UIView *root) {
    if (!root) return nil;
    NSString *name = NSStringFromClass([root class]);
    if ([name containsString:@"WCSearchBar"]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = MMFindSearchBarInView(sub);
        if (found) return found;
    }
    return nil;
}

static UIView *MMFindLabelContainingText(UIView *root, NSString *text) {
    if (!root || ![text length]) return nil;
    if ([root isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)root;
        if ([label.text containsString:text]) return label;
    }
    for (UIView *sub in root.subviews) {
        UIView *found = MMFindLabelContainingText(sub, text);
        if (found) return found;
    }
    return nil;
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

static NSArray *MMItemViews(UITabBar *tabBar) {
    NSMutableArray *result = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"UITabBarButton"]) {
            [result addObject:sub];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return result;
}

static UIView *MMEnsureBackdrop(UIView *root) {
    UIView *view = [root viewWithTag:kMMBackdropTag];
    if (!view) {
        view = [UIView new];
        view.tag = kMMBackdropTag;
        view.userInteractionEnabled = NO;
        view.backgroundColor = [UIColor clearColor];
        [root addSubview:view];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMBackdropBlurTag;
        blur.userInteractionEnabled = NO;
        [view addSubview:blur];

        UIView *tint = [UIView new];
        tint.tag = kMMBackdropTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    return view;
}

static UIView *MMEnsureGlass(UIView *root) {
    UIView *glass = [root viewWithTag:kMMGlassTag];
    if (!glass) {
        glass = [UIView new];
        glass.tag = kMMGlassTag;
        glass.userInteractionEnabled = NO;
        glass.backgroundColor = [UIColor clearColor];
        glass.clipsToBounds = NO;
        [root addSubview:glass];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMGlassBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [glass addSubview:blur];

        UIView *tint = [UIView new];
        tint.tag = kMMGlassTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];

        UIView *border = [UIView new];
        border.tag = kMMGlassBorderTag;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        [glass addSubview:border];

        UIView *shine = [UIView new];
        shine.tag = kMMGlassShineTag;
        shine.userInteractionEnabled = NO;
        shine.backgroundColor = [UIColor clearColor];
        shine.clipsToBounds = YES;
        [glass addSubview:shine];

        UIView *capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.clipsToBounds = YES;
        [glass addSubview:capsule];

        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *capsuleBlur = [[UIVisualEffectView alloc] initWithEffect:nil];
            capsuleBlur.tag = kMMCapsuleBlurTag;
            capsuleBlur.userInteractionEnabled = NO;
            capsuleBlur.clipsToBounds = YES;
            [capsule addSubview:capsuleBlur];
        }

        UIView *capsuleTint = [UIView new];
        capsuleTint.tag = kMMCapsuleTintTag;
        capsuleTint.userInteractionEnabled = NO;
        [capsule addSubview:capsuleTint];

        UIView *capsuleBorder = [UIView new];
        capsuleBorder.tag = kMMCapsuleBorderTag;
        capsuleBorder.userInteractionEnabled = NO;
        capsuleBorder.backgroundColor = [UIColor clearColor];
        [capsule addSubview:capsuleBorder];
    }
    return glass;
}

static UIView *MMEnsureSearchHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMSearchHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMSearchHostTag;
        host.userInteractionEnabled = YES;
        host.backgroundColor = [UIColor clearColor];
        host.clipsToBounds = NO;
        [root addSubview:host];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMSearchBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];

        UIView *tint = [UIView new];
        tint.tag = kMMSearchTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];

        UIImageView *icon = [UIImageView new];
        icon.tag = kMMSearchIconTag;
        icon.userInteractionEnabled = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [host addSubview:icon];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = kMMSearchButtonTag;
        button.backgroundColor = [UIColor clearColor];
        [host addSubview:button];
    }
    return host;
}

static void MMOpenSearch(UIButton *sender) {
    UIResponder *r = sender;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                UIViewController *home = MMFindHomeController(vc);
                if (!home) home = vc;
                if ([home respondsToSelector:@selector(onTapOnSearchButton)]) {
                    ((void (*)(id, SEL))objc_msgSend)(home, @selector(onTapOnSearchButton));
                }
                break;
            }
        }
    }
}

static void MMHandleSearchTap(id selfObj, SEL _cmd, UIButton *sender) {
    MMOpenSearch(sender);
}

static CGRect MMComputeGlassFrame(UIViewController *vc, UITabBar *tabBar, BOOL showSearch) {
    UIView *root = vc.view;
    CGFloat screenW = CGRectGetWidth(root.bounds);
    CGFloat screenH = CGRectGetHeight(root.bounds);
    CGFloat safeBottom = root.safeAreaInsets.bottom;
    CGFloat glassHeight = 64.0;
    CGFloat searchSize = 64.0;
    CGFloat margin = 16.0;
    CGFloat gap = 10.0;

    CGFloat y = screenH - safeBottom - glassHeight - 14.0;

    UIView *label = MMFindLabelContainingText(root, @"折叠置顶聊天");
    if (label) {
        UIView *banner = label.superview ?: label;
        UIView *ref = banner.superview ?: root;
        CGRect bannerRect = [ref convertRect:banner.frame toView:root];
        CGFloat minY = CGRectGetMaxY(bannerRect) + 1.0;
        if (y < minY) y = minY;
    }

    CGFloat width = screenW - margin * 2.0 - (showSearch ? (searchSize + gap) : 0.0);
    (void)tabBar;
    return CGRectMake(margin, y, width, glassHeight);
}

static void MMStyleBackdrop(UIView *backdrop) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[backdrop viewWithTag:kMMBackdropBlurTag];
    blur.frame = backdrop.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(backdrop.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }

    UIView *tint = [blur.contentView viewWithTag:kMMBackdropTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(backdrop.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.02] : [UIColor colorWithWhite:1.0 alpha:0.05];

    CAGradientLayer *mask = nil;
    if ([backdrop.layer.mask isKindOfClass:[CAGradientLayer class]]) {
        mask = (CAGradientLayer *)backdrop.layer.mask;
    } else {
        mask = [CAGradientLayer layer];
        backdrop.layer.mask = mask;
    }
    mask.frame = backdrop.bounds;
    mask.startPoint = CGPointMake(0.5, 0.0);
    mask.endPoint = CGPointMake(0.5, 1.0);
    mask.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.20].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor
    ];
    mask.locations = @[@0.0, @0.25, @1.0];
}

static void MMStyleGlass(UIView *glass) {
    MMSetRadius(glass, CGRectGetHeight(glass.bounds) * 0.5);

    UIVisualEffectView *blur = (UIVisualEffectView *)[glass viewWithTag:kMMGlassBlurTag];
    blur.frame = glass.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, CGRectGetHeight(glass.bounds) * 0.5);

    UIView *tint = [blur.contentView viewWithTag:kMMGlassTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.05] : [UIColor colorWithWhite:1.0 alpha:0.10];

    glass.layer.shadowColor = [UIColor blackColor].CGColor;
    glass.layer.shadowOpacity = MMIsDark(glass.traitCollection) ? 0.12 : 0.08;
    glass.layer.shadowRadius = 18.0;
    glass.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    glass.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:glass.bounds cornerRadius:CGRectGetHeight(glass.bounds) * 0.5].CGPath;

    UIView *border = [glass viewWithTag:kMMGlassBorderTag];
    border.frame = glass.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.16 : 0.26)].CGColor;
    MMSetRadius(border, CGRectGetHeight(border.bounds) * 0.5);

    UIView *shine = [glass viewWithTag:kMMGlassShineTag];
    shine.frame = CGRectInset(glass.bounds, 1.0, 1.0);
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
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.12 : 0.18)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.03].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    g.locations = @[@0.0, @0.20, @0.45];
    g.cornerRadius = CGRectGetHeight(shine.bounds) * 0.5;
}

static void MMStyleCapsule(UIView *capsule, UIView *glass) {
    MMSetRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *capsuleBlur = [capsule viewWithTag:kMMCapsuleBlurTag];
    if ([capsuleBlur isKindOfClass:[UIVisualEffectView class]]) {
        capsuleBlur.frame = capsule.bounds;
        ((UIVisualEffectView *)capsuleBlur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        MMSetRadius(capsuleBlur, CGRectGetHeight(capsule.bounds) * 0.5);
    }

    UIView *capsuleTint = [capsule viewWithTag:kMMCapsuleTintTag];
    capsuleTint.frame = capsule.bounds;
    capsuleTint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.16];
    MMSetRadius(capsuleTint, CGRectGetHeight(capsuleTint.bounds) * 0.5);

    UIView *capsuleBorder = [capsule viewWithTag:kMMCapsuleBorderTag];
    capsuleBorder.frame = capsule.bounds;
    capsuleBorder.layer.borderWidth = 0.8;
    capsuleBorder.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.18 : 0.30)].CGColor;
    MMSetRadius(capsuleBorder, CGRectGetHeight(capsuleBorder.bounds) * 0.5);
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
        if ([name containsString:@"BarBackground"] || [name containsString:@"_UIBarBackground"] || [name containsString:@"Backdrop"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.userInteractionEnabled = NO;
        } else {
            sub.hidden = NO;
            sub.alpha = 1.0;
            sub.userInteractionEnabled = YES;
            sub.backgroundColor = [UIColor clearColor];
        }
    }
}

static void MMUpdateSearchHost(UIViewController *vc, CGRect glassFrame) {
    UIView *root = vc.view;
    UIViewController *home = MMFindHomeController(vc);
    UIView *searchBar = home ? MMFindSearchBarInView(home.view) : nil;
    UIView *host = MMEnsureSearchHost(root);

    if (!searchBar) {
        host.hidden = YES;
        host.alpha = 0.0;
        return;
    }

    CGFloat size = 64.0;
    CGFloat gap = 10.0;
    host.frame = CGRectMake(CGRectGetMaxX(glassFrame) + gap, CGRectGetMinY(glassFrame), size, size);
    host.hidden = NO;
    host.alpha = 1.0;

    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMSearchBlurTag];
    blur.frame = host.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, size * 0.5);

    UIView *tint = [blur.contentView viewWithTag:kMMSearchTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithWhite:1.0 alpha:0.10];

    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = MMIsDark(host.traitCollection) ? 0.12 : 0.08;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    host.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:host.bounds cornerRadius:size * 0.5].CGPath;
    MMSetRadius(host, size * 0.5);

    UIImageView *icon = (UIImageView *)[host viewWithTag:kMMSearchIconTag];
    icon.frame = CGRectMake(floor((size - 26.0) * 0.5), floor((size - 26.0) * 0.5), 26.0, 26.0);
    icon.tintColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        icon.image = nil;
    }

    UIButton *button = (UIButton *)[host viewWithTag:kMMSearchButtonTag];
    button.frame = host.bounds;

    Class cls = object_getClass(button);
    SEL action = @selector(_mm_handleSearchTap:);
    if (![cls instancesRespondToSelector:action]) {
        class_addMethod(cls, action, (IMP)MMHandleSearchTap, "v@:@");
    }
    [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:button action:action forControlEvents:UIControlEventTouchUpInside];

    [root bringSubviewToFront:host];
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdating) return;
    kMMUpdating = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    UIView *backdrop = MMEnsureBackdrop(root);
    UIView *glass = MMEnsureGlass(root);
    UIView *searchHost = MMEnsureSearchHost(root);

    if (!root || !tabBar || !MMShouldShowFloatingBar(vc)) {
        backdrop.hidden = YES;
        glass.hidden = YES;
        searchHost.hidden = YES;
        kMMUpdating = NO;
        return;
    }

    UIViewController *home = MMFindHomeController(vc);
    BOOL showSearch = MMFindSearchBarInView(home.view) != nil;
    CGRect glassFrame = MMComputeGlassFrame(vc, tabBar, showSearch);

    backdrop.frame = CGRectMake(0.0, CGRectGetMinY(glassFrame) - 4.0, CGRectGetWidth(root.bounds), CGRectGetHeight(root.bounds) - CGRectGetMinY(glassFrame) + 4.0);
    backdrop.hidden = NO;
    backdrop.alpha = 1.0;
    MMStyleBackdrop(backdrop);

    glass.frame = glassFrame;
    glass.hidden = NO;
    glass.alpha = 1.0;
    MMStyleGlass(glass);

    MMMakeTabBarTransparent(tabBar);

    UIView *tabBarRef = tabBar.superview ?: root;
    CGRect tabFrameInRoot = [tabBarRef convertRect:tabBar.frame toView:root];
    CGFloat targetY = CGRectGetMinY(glassFrame) - ((CGRectGetHeight(tabFrameInRoot) - CGRectGetHeight(glassFrame)) * 0.5);
    CGRect newTabFrame = CGRectMake(CGRectGetMinX(tabFrameInRoot), targetY, CGRectGetWidth(tabFrameInRoot), CGRectGetHeight(tabFrameInRoot));
    if (tabBar.superview != root) {
        newTabFrame = [root convertRect:newTabFrame toView:tabBar.superview];
    }
    tabBar.frame = newTabFrame;
    [tabBar setNeedsLayout];
    [tabBar layoutIfNeeded];

    NSArray *itemViews = MMItemViews(tabBar);
    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    UIView *capsule = [glass viewWithTag:kMMCapsuleTag];
    if (selectedIndex >= 0 && selectedIndex < (NSInteger)[itemViews count]) {
        UIView *selectedView = [itemViews objectAtIndex:selectedIndex];
        CGRect itemRect = [selectedView.superview convertRect:selectedView.frame toView:root];
        CGFloat capH = CGRectGetHeight(glassFrame) - 10.0;
        CGFloat capW = MIN(CGRectGetWidth(itemRect) * 0.62, 62.0);
        CGFloat capX = CGRectGetMidX(itemRect) - capW * 0.5 - CGRectGetMinX(glassFrame);
        CGFloat capY = (CGRectGetHeight(glassFrame) - capH) * 0.5;
        if (capX < 4.0) capX = 4.0;
        if (capX + capW > CGRectGetWidth(glassFrame) - 4.0) capX = CGRectGetWidth(glassFrame) - 4.0 - capW;
        capsule.frame = CGRectMake(capX, capY, capW, capH);
        capsule.hidden = NO;
        MMStyleCapsule(capsule, glass);
    } else {
        capsule.hidden = YES;
    }

    MMUpdateSearchHost(vc, glassFrame);

    [root bringSubviewToFront:backdrop];
    [root bringSubviewToFront:glass];
    [root bringSubviewToFront:tabBar];
    if (!searchHost.hidden) [root bringSubviewToFront:searchHost];

    kMMUpdating = NO;
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    %orig(selectedViewController);
    MMUpdateFloatingBar((UIViewController *)self);
}

%end
