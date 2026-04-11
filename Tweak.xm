#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface MainTabBarViewController : UIViewController
@end

@interface MMFloatingActionProxy : NSObject
- (void)handleSearchTap:(UIButton *)sender;
@end

static MMFloatingActionProxy *MMSharedActionProxy(void);
static void MMRequestRefresh(UIViewController *vc);

static NSInteger const kMMBackdropTag = 990201;
static NSInteger const kMMBackdropBlurTag = 990202;
static NSInteger const kMMGlassTag = 990203;
static NSInteger const kMMGlassBlurTag = 990204;
static NSInteger const kMMGlassEdgeTag = 990205;
static NSInteger const kMMGlassShineTag = 990206;
static NSInteger const kMMCapsuleTag = 990207;
static NSInteger const kMMCapsuleBlurTag = 990208;
static NSInteger const kMMCapsuleTintTag = 990209;
static NSInteger const kMMCapsuleBorderTag = 990210;
static NSInteger const kMMSearchHostTag = 990211;
static NSInteger const kMMSearchBlurTag = 990212;
static NSInteger const kMMSearchIconTag = 990213;
static NSInteger const kMMSearchButtonTag = 990214;

static BOOL kMMUpdatingLayout = NO;

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
        if ([name containsString:@"UITabBarButton"] || [name containsString:@"MMTabBarItemView"]) {
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
    @try { vcs = [vc valueForKey:@"viewControllers"]; } @catch (__unused NSException *e) {}
    if ([vcs isKindOfClass:[NSArray class]]) {
        for (UIViewController *child in (NSArray *)vcs) {
            UIViewController *found = MMFindHomeController(child);
            if (found) return found;
        }
    }

    return nil;
}

static void MMOpenSearch(UIViewController *vc) {
    UIViewController *home = MMFindHomeController(vc);
    if (!home) home = vc;
    if ([home respondsToSelector:@selector(onTapOnSearchButton)]) {
        ((void (*)(id, SEL))objc_msgSend)(home, @selector(onTapOnSearchButton));
    }
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

static UIView *MMEnsureBackdrop(UIView *root) {
    UIView *backdrop = [root viewWithTag:kMMBackdropTag];
    if (!backdrop) {
        backdrop = [UIView new];
        backdrop.tag = kMMBackdropTag;
        backdrop.userInteractionEnabled = NO;
        backdrop.backgroundColor = [UIColor clearColor];
        [root addSubview:backdrop];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMBackdropBlurTag;
        blur.userInteractionEnabled = NO;
        [backdrop addSubview:blur];
    }
    return backdrop;
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
    }
    return glass;
}

static UIView *MMEnsureCapsule(UIView *glass) {
    UIView *capsule = [glass viewWithTag:kMMCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.clipsToBounds = YES;
        [glass addSubview:capsule];

        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
            blur.tag = kMMCapsuleBlurTag;
            blur.userInteractionEnabled = NO;
            blur.clipsToBounds = YES;
            [capsule addSubview:blur];
        }

        UIView *tint = [UIView new];
        tint.tag = kMMCapsuleTintTag;
        tint.userInteractionEnabled = NO;
        [capsule addSubview:tint];

        UIView *border = [UIView new];
        border.tag = kMMCapsuleBorderTag;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        [capsule addSubview:border];
    }
    return capsule;
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

        UIImageView *icon = [UIImageView new];
        icon.tag = kMMSearchIconTag;
        icon.userInteractionEnabled = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [host addSubview:icon];
    }
    return host;
}

static void MMStyleBackdrop(UIView *backdrop) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[backdrop viewWithTag:kMMBackdropBlurTag];
    blur.frame = backdrop.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(backdrop.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }

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
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.24].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:1.0].CGColor
    ];
    mask.locations = @[@0.0, @0.24, @1.0];
}

static void MMStyleGlass(UIView *glass) {
    MMSetRadius(glass, CGRectGetHeight(glass.bounds) * 0.5);
    glass.layer.shadowColor = [UIColor blackColor].CGColor;
    glass.layer.shadowOpacity = MMIsDark(glass.traitCollection) ? 0.12 : 0.09;
    glass.layer.shadowRadius = 18.0;
    glass.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    glass.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:glass.bounds cornerRadius:CGRectGetHeight(glass.bounds) * 0.5].CGPath;

    UIVisualEffectView *blur = (UIVisualEffectView *)[glass viewWithTag:kMMGlassBlurTag];
    blur.frame = glass.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, CGRectGetHeight(glass.bounds) * 0.5);

    UIView *tint = [blur.contentView viewWithTag:991001];
    if (!tint) {
        tint = [UIView new];
        tint.tag = 991001;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithWhite:1.0 alpha:0.13];

    UIView *edge = [glass viewWithTag:kMMGlassEdgeTag];
    if (!edge) {
        edge = [UIView new];
        edge.tag = kMMGlassEdgeTag;
        edge.userInteractionEnabled = NO;
        edge.backgroundColor = [UIColor clearColor];
        [glass addSubview:edge];
    }
    edge.frame = glass.bounds;
    MMSetRadius(edge, CGRectGetHeight(glass.bounds) * 0.5);
    edge.layer.borderWidth = 0.8;
    edge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.16 : 0.28)].CGColor;

    UIView *shine = [glass viewWithTag:kMMGlassShineTag];
    if (!shine) {
        shine = [UIView new];
        shine.tag = kMMGlassShineTag;
        shine.userInteractionEnabled = NO;
        shine.backgroundColor = [UIColor clearColor];
        shine.clipsToBounds = YES;
        [glass addSubview:shine];
    }
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
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.15 : 0.25)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.04 : 0.06)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    g.locations = @[@0.0, @0.18, @0.44];
    g.cornerRadius = CGRectGetHeight(shine.bounds) * 0.5;
}

static void MMStyleCapsule(UIView *capsule, UIView *glass) {
    MMSetRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *blur = [capsule viewWithTag:kMMCapsuleBlurTag];
    if ([blur isKindOfClass:[UIVisualEffectView class]]) {
        blur.frame = capsule.bounds;
        ((UIVisualEffectView *)blur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        MMSetRadius(blur, CGRectGetHeight(capsule.bounds) * 0.5);
    }

    UIView *tint = [capsule viewWithTag:kMMCapsuleTintTag];
    tint.frame = capsule.bounds;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:1.0 alpha:0.18];
    MMSetRadius(tint, CGRectGetHeight(tint.bounds) * 0.5);

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.18 : 0.34)].CGColor;
    MMSetRadius(border, CGRectGetHeight(border.bounds) * 0.5);
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
            sub.backgroundColor = [UIColor clearColor];
        }
    }
}

static CGRect MMBarFrameForRoot(UIViewController *vc, BOOL showSearch) {
    UIView *root = vc.view;
    CGFloat inset = MMBottomInset(root);
    CGFloat margin = 16.0;
    CGFloat gap = 10.0;
    CGFloat searchSize = 72.0;
    CGFloat height = 72.0;

    CGFloat homeIndicatorTop = CGRectGetHeight(root.bounds) - inset - 8.0;
    CGFloat bottomLimit = homeIndicatorTop - height - 10.0;

    UIView *label = MMFindLabelContainingText(root, @"折叠置顶聊天");
    CGFloat minY = 0.0;
    if (label) {
        UIView *banner = label.superview ?: label;
        UIView *ref = banner.superview ?: root;
        CGRect bannerRect = [ref convertRect:banner.frame toView:root];
        minY = CGRectGetMaxY(bannerRect) + 8.0;
    }

    CGFloat y = bottomLimit;
    if (y < minY) y = minY;

    CGFloat width = CGRectGetWidth(root.bounds) - margin * 2.0 - (showSearch ? (searchSize + gap) : 0.0);
    return CGRectMake(margin, y, width, height);
}

static void MMUpdateSearchButton(UIViewController *vc, UIView *root, CGRect barFrame) {
    UIViewController *homeVC = MMFindHomeController(vc);
    UIView *searchBar = homeVC ? MMFindSearchBarInView(homeVC.view) : nil;
    UIView *searchHost = MMEnsureSearchHost(root);

    if (!searchBar) {
        searchHost.hidden = YES;
        searchHost.alpha = 0.0;
        return;
    }

    CGFloat size = CGRectGetHeight(barFrame);
    CGFloat gap = 10.0;
    CGFloat x = CGRectGetMaxX(barFrame) + gap;
    CGFloat y = CGRectGetMinY(barFrame);

    searchHost.frame = CGRectMake(x, y, size, size);
    searchHost.hidden = NO;
    searchHost.alpha = 1.0;

    UIVisualEffectView *blur = (UIVisualEffectView *)[searchHost viewWithTag:kMMSearchBlurTag];
    blur.frame = searchHost.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(searchHost.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, size * 0.5);

    UIView *tint = [blur.contentView viewWithTag:991002];
    if (!tint) {
        tint = [UIView new];
        tint.tag = 991002;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(searchHost.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithWhite:1.0 alpha:0.13];

    searchHost.layer.shadowColor = [UIColor blackColor].CGColor;
    searchHost.layer.shadowOpacity = MMIsDark(searchHost.traitCollection) ? 0.12 : 0.09;
    searchHost.layer.shadowRadius = 18.0;
    searchHost.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    searchHost.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:searchHost.bounds cornerRadius:size * 0.5].CGPath;
    MMSetRadius(searchHost, size * 0.5);

    UIImageView *icon = (UIImageView *)[searchHost viewWithTag:kMMSearchIconTag];
    icon.frame = CGRectMake(floor((size - 28.0) * 0.5), floor((size - 28.0) * 0.5), 28.0, 28.0);
    icon.tintColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        icon.image = nil;
    }

    UIButton *button = (UIButton *)[searchHost viewWithTag:kMMSearchButtonTag];
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = kMMSearchButtonTag;
        button.backgroundColor = [UIColor clearColor];
        [button addTarget:MMSharedActionProxy() action:@selector(handleSearchTap:) forControlEvents:UIControlEventTouchUpInside];
        [searchHost addSubview:button];
    }
    button.frame = searchHost.bounds;

    [root bringSubviewToFront:searchHost];
}

static void MMSetVisible(UIView *view, BOOL visible) {
    if (!view) return;
    view.hidden = !visible;
    view.alpha = visible ? 1.0 : 0.0;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    UIView *backdrop = MMEnsureBackdrop(root);
    UIView *glass = MMEnsureGlass(root);
    UIView *searchHost = MMEnsureSearchHost(root);

    if (!root || !tabBar || !MMShouldShowFloatingBar(vc)) {
        MMSetVisible(backdrop, NO);
        MMSetVisible(glass, NO);
        MMSetVisible(searchHost, NO);
        kMMUpdatingLayout = NO;
        return;
    }

    UIViewController *homeVC = MMFindHomeController(vc);
    UIView *searchBar = homeVC ? MMFindSearchBarInView(homeVC.view) : nil;
    BOOL showSearch = (searchBar != nil);

    CGRect barFrame = MMBarFrameForRoot(vc, showSearch);

    CGFloat inset = MMBottomInset(root);
    backdrop.frame = CGRectMake(CGRectGetMinX(barFrame) - 6.0, CGRectGetMinY(barFrame) - 8.0, CGRectGetWidth(root.bounds) - (CGRectGetMinX(barFrame) - 6.0) * 2.0, CGRectGetHeight(barFrame) + inset + 6.0);
    MMStyleBackdrop(backdrop);

    glass.frame = barFrame;
    MMStyleGlass(glass);

    MMMakeTabBarTransparent(tabBar);
    tabBar.frame = barFrame;
    [tabBar setNeedsLayout];
    [tabBar layoutIfNeeded];

    NSArray *itemViews = MMOriginalItemViews(tabBar);
    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    UIView *capsule = MMEnsureCapsule(glass);
    if (selectedIndex >= 0 && selectedIndex < (NSInteger)[itemViews count]) {
        UIView *itemView = [itemViews objectAtIndex:selectedIndex];
        CGRect itemRect = [tabBar convertRect:itemView.frame toView:glass];
        CGFloat capH = CGRectGetHeight(glass.bounds) - 10.0;
        CGFloat capW = MIN(CGRectGetWidth(itemRect) + 8.0, 68.0);
        CGFloat capX = CGRectGetMidX(itemRect) - capW * 0.5;
        CGFloat capY = (CGRectGetHeight(glass.bounds) - capH) * 0.5;
        if (capX < 4.0) capX = 4.0;
        if (capX + capW > CGRectGetWidth(glass.bounds) - 4.0) capX = CGRectGetWidth(glass.bounds) - 4.0 - capW;
        capsule.frame = CGRectMake(capX, capY, capW, capH);
        capsule.hidden = NO;
        MMStyleCapsule(capsule, glass);
    } else {
        capsule.hidden = YES;
    }

    for (UIView *itemView in itemViews) {
        itemView.hidden = NO;
        itemView.alpha = 1.0;
        itemView.userInteractionEnabled = YES;
    }

    [root bringSubviewToFront:backdrop];
    [root bringSubviewToFront:glass];
    [root bringSubviewToFront:tabBar];
    MMUpdateSearchButton(vc, root, barFrame);

    MMSetVisible(backdrop, YES);
    MMSetVisible(glass, YES);

    kMMUpdatingLayout = NO;
}

static void MMRequestRefresh(UIViewController *vc) {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar(vc);
    });
}

@implementation MMFloatingActionProxy

- (void)handleSearchTap:(UIButton *)sender {
    UIResponder *r = sender;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMOpenSearch(vc);
                break;
            }
        }
    }
}

@end

static MMFloatingActionProxy *MMSharedActionProxy(void) {
    static MMFloatingActionProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMFloatingActionProxy new];
    });
    return proxy;
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    MMRequestRefresh((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMRequestRefresh((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMRequestRefresh((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMRequestRefresh((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    MMRequestRefresh((UIViewController *)self);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    %orig(selectedViewController);
    MMRequestRefresh((UIViewController *)self);
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
                MMRequestRefresh(vc);
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
                MMRequestRefresh(vc);
                break;
            }
        }
    }
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
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
                MMRequestRefresh(vc);
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
                MMRequestRefresh(vc);
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
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

%end
