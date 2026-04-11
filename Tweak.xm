#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface MainTabBarViewController : UIViewController
- (void)setSelectedIndex:(NSUInteger)index;
@end

@interface MMFloatingActionProxy : NSObject
- (void)handleTabTap:(UIButton *)sender;
- (void)handleSearchTap:(UIButton *)sender;
@end

static MMFloatingActionProxy *MMSharedActionProxy(void);

static NSInteger const kMMFloatingBackdropTag = 991000;
static NSInteger const kMMFloatingBarTag = 991001;
static NSInteger const kMMFloatingBarBlurTag = 991002;
static NSInteger const kMMFloatingBarTintTag = 991003;
static NSInteger const kMMFloatingBarBorderTag = 991004;
static NSInteger const kMMFloatingBarShineTag = 991005;
static NSInteger const kMMFloatingCapsuleTag = 991006;
static NSInteger const kMMFloatingCapsuleBlurTag = 991007;
static NSInteger const kMMFloatingCapsuleTintTag = 991008;
static NSInteger const kMMFloatingCapsuleBorderTag = 991009;
static NSInteger const kMMFloatingButtonsHostTag = 991010;
static NSInteger const kMMFloatingSearchHostTag = 991011;
static NSInteger const kMMFloatingSearchBlurTag = 991012;
static NSInteger const kMMFloatingSearchTintTag = 991013;
static NSInteger const kMMFloatingSearchIconTag = 991014;
static NSInteger const kMMFloatingSearchButtonTag = 991015;

static BOOL kMMUpdating = NO;

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

static void MMSetContinuousRadius(UIView *view, CGFloat radius) {
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
    @try { vcs = [vc valueForKey:@"viewControllers"]; } @catch (__unused NSException *e) {}
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

static void MMOpenSearchFromMainTab(UIViewController *vc) {
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

static UIView *MMEnsureBackdrop(UIView *root) {
    UIView *view = [root viewWithTag:kMMFloatingBackdropTag];
    if (!view) {
        view = [UIView new];
        view.tag = kMMFloatingBackdropTag;
        view.userInteractionEnabled = NO;
        view.backgroundColor = [UIColor clearColor];
        [root addSubview:view];
    }
    return view;
}

static UIView *MMEnsureBar(UIView *root) {
    UIView *bar = [root viewWithTag:kMMFloatingBarTag];
    if (!bar) {
        bar = [UIView new];
        bar.tag = kMMFloatingBarTag;
        bar.userInteractionEnabled = YES;
        bar.backgroundColor = [UIColor clearColor];
        bar.clipsToBounds = NO;
        [root addSubview:bar];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingBarBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [bar addSubview:blur];

        UIView *tint = [UIView new];
        tint.tag = kMMFloatingBarTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];

        UIView *border = [UIView new];
        border.tag = kMMFloatingBarBorderTag;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        [bar addSubview:border];

        UIView *shine = [UIView new];
        shine.tag = kMMFloatingBarShineTag;
        shine.userInteractionEnabled = NO;
        shine.backgroundColor = [UIColor clearColor];
        shine.clipsToBounds = YES;
        [bar addSubview:shine];

        UIView *capsule = [UIView new];
        capsule.tag = kMMFloatingCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.clipsToBounds = YES;
        [bar addSubview:capsule];

        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *capsuleBlur = [[UIVisualEffectView alloc] initWithEffect:nil];
            capsuleBlur.tag = kMMFloatingCapsuleBlurTag;
            capsuleBlur.userInteractionEnabled = NO;
            capsuleBlur.clipsToBounds = YES;
            [capsule addSubview:capsuleBlur];
        }

        UIView *capsuleTint = [UIView new];
        capsuleTint.tag = kMMFloatingCapsuleTintTag;
        capsuleTint.userInteractionEnabled = NO;
        [capsule addSubview:capsuleTint];

        UIView *capsuleBorder = [UIView new];
        capsuleBorder.tag = kMMFloatingCapsuleBorderTag;
        capsuleBorder.userInteractionEnabled = NO;
        capsuleBorder.backgroundColor = [UIColor clearColor];
        [capsule addSubview:capsuleBorder];

        UIView *buttonsHost = [UIView new];
        buttonsHost.tag = kMMFloatingButtonsHostTag;
        buttonsHost.userInteractionEnabled = YES;
        buttonsHost.backgroundColor = [UIColor clearColor];
        [bar addSubview:buttonsHost];
    }
    return bar;
}

static UIView *MMEnsureSearchHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMFloatingSearchHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMFloatingSearchHostTag;
        host.userInteractionEnabled = YES;
        host.backgroundColor = [UIColor clearColor];
        host.clipsToBounds = NO;
        [root addSubview:host];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingSearchBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];

        UIView *tint = [UIView new];
        tint.tag = kMMFloatingSearchTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];

        UIImageView *icon = [UIImageView new];
        icon.tag = kMMFloatingSearchIconTag;
        icon.userInteractionEnabled = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [host addSubview:icon];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = kMMFloatingSearchButtonTag;
        button.backgroundColor = [UIColor clearColor];
        [button addTarget:MMSharedActionProxy() action:@selector(handleSearchTap:) forControlEvents:UIControlEventTouchUpInside];
        [host addSubview:button];
    }
    return host;
}

static void MMStyleBackdrop(UIView *backdrop) {
    backdrop.backgroundColor = [UIColor clearColor];
    CAGradientLayer *g = nil;
    if (backdrop.layer.sublayers.count > 0 && [backdrop.layer.sublayers.firstObject isKindOfClass:[CAGradientLayer class]]) {
        g = (CAGradientLayer *)backdrop.layer.sublayers.firstObject;
    } else {
        g = [CAGradientLayer layer];
        [backdrop.layer insertSublayer:g atIndex:0];
    }
    g.frame = backdrop.bounds;
    g.startPoint = CGPointMake(0.5, 0.0);
    g.endPoint = CGPointMake(0.5, 1.0);
    g.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.10].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor
    ];
    g.locations = @[@0.0, @0.55, @1.0];
}

static void MMStyleBar(UIView *bar) {
    MMSetRadius(bar, CGRectGetHeight(bar.bounds) * 0.5);
    bar.layer.shadowColor = [UIColor blackColor].CGColor;
    bar.layer.shadowOpacity = MMIsDark(bar.traitCollection) ? 0.14 : 0.10;
    bar.layer.shadowRadius = 22.0;
    bar.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    bar.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bar.bounds cornerRadius:CGRectGetHeight(bar.bounds) * 0.5].CGPath;

    UIVisualEffectView *blur = (UIVisualEffectView *)[bar viewWithTag:kMMFloatingBarBlurTag];
    blur.frame = bar.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(bar.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, CGRectGetHeight(bar.bounds) * 0.5);

    UIView *tint = [blur.contentView viewWithTag:kMMFloatingBarTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(bar.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.05] : [UIColor colorWithWhite:1.0 alpha:0.12];

    UIView *border = [bar viewWithTag:kMMFloatingBarBorderTag];
    border.frame = bar.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(bar.traitCollection) ? 0.16 : 0.28)].CGColor;
    MMSetContinuousRadius(border, CGRectGetHeight(border.bounds) * 0.5);

    UIView *shine = [bar viewWithTag:kMMFloatingBarShineTag];
    shine.frame = CGRectInset(bar.bounds, 1.0, 1.0);
    MMSetContinuousRadius(shine, CGRectGetHeight(shine.bounds) * 0.5);

    CAGradientLayer *g = nil;
    if (shine.layer.sublayers.count > 0 && [shine.layer.sublayers.firstObject isKindOfClass:[CAGradientLayer class]]) {
        g = (CAGradientLayer *)shine.layer.sublayers.firstObject;
    } else {
        g = [CAGradientLayer layer];
        [shine.layer addSublayer:g];
    }
    g.frame = shine.bounds;
    g.startPoint = CGPointMake(0.5, 0.0);
    g.endPoint = CGPointMake(0.5, 1.0);
    g.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(bar.traitCollection) ? 0.14 : 0.22)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.03].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    g.locations = @[@0.0, @0.20, @0.45];
    g.cornerRadius = CGRectGetHeight(shine.bounds) * 0.5;
}

static void MMStyleCapsule(UIView *capsule, UIView *bar) {
    MMSetContinuousRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *capsuleBlur = [capsule viewWithTag:kMMFloatingCapsuleBlurTag];
    if ([capsuleBlur isKindOfClass:[UIVisualEffectView class]]) {
        capsuleBlur.frame = capsule.bounds;
        ((UIVisualEffectView *)capsuleBlur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(bar.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        MMSetContinuousRadius(capsuleBlur, CGRectGetHeight(capsule.bounds) * 0.5);
    }

    UIView *capsuleTint = [capsule viewWithTag:kMMFloatingCapsuleTintTag];
    capsuleTint.frame = capsule.bounds;
    capsuleTint.backgroundColor = MMIsDark(bar.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.18];
    MMSetContinuousRadius(capsuleTint, CGRectGetHeight(capsuleTint.bounds) * 0.5);

    UIView *capsuleBorder = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    capsuleBorder.frame = capsule.bounds;
    capsuleBorder.layer.borderWidth = 0.8;
    capsuleBorder.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(bar.traitCollection) ? 0.18 : 0.34)].CGColor;
    MMSetContinuousRadius(capsuleBorder, CGRectGetHeight(capsuleBorder.bounds) * 0.5);
}

static void MMHideOriginalTabBar(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 0.001;
    tabBar.userInteractionEnabled = NO;
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
    for (UIView *sub in tabBar.subviews) {
        sub.hidden = YES;
        sub.alpha = 0.0;
        sub.userInteractionEnabled = NO;
    }
}

static CGRect MMComputeFloatingFrame(UIViewController *vc, UITabBar *tabBar, BOOL showSearch) {
    UIView *root = vc.view;
    CGFloat margin = 16.0;
    CGFloat gap = 10.0;
    CGFloat searchSize = 72.0;
    CGFloat height = 72.0;

    CGRect originalFrame = tabBar.frame;
    CGFloat y = CGRectGetMinY(originalFrame) - 3.0;

    UIView *label = MMFindLabelContainingText(root, @"折叠置顶聊天");
    if (label) {
        UIView *banner = label.superview ?: label;
        UIView *ref = banner.superview ?: root;
        CGRect bannerRect = [ref convertRect:banner.frame toView:root];
        CGFloat minY = CGRectGetMaxY(bannerRect) + 8.0;
        if (y < minY) y = minY;
    }

    CGFloat width = CGRectGetWidth(root.bounds) - margin * 2.0 - (showSearch ? (searchSize + gap) : 0.0);
    return CGRectMake(margin, y, width, height);
}

static UIButton *MMEnsureTabButton(UIView *host, NSInteger index) {
    UIButton *button = (UIButton *)[host viewWithTag:8000 + index];
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = 8000 + index;
        button.backgroundColor = [UIColor clearColor];
        button.adjustsImageWhenHighlighted = NO;
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.6;
        [button addTarget:MMSharedActionProxy() action:@selector(handleTabTap:) forControlEvents:UIControlEventTouchUpInside];
        [host addSubview:button];
    }
    return button;
}

static void MMConfigureButtonLayout(UIButton *button, CGFloat width, CGFloat height) {
    CGFloat iconSize = 24.0;
    CGFloat titleH = 14.0;
    CGFloat gap = 2.0;
    CGFloat totalH = iconSize + gap + titleH;
    CGFloat top = floor((height - totalH) * 0.5);
    if (top < 4.0) top = 4.0;
    button.imageEdgeInsets = UIEdgeInsetsMake(top, (width - iconSize) * 0.5 - button.imageView.frame.origin.x, height - top - iconSize, 0.0);
    button.titleEdgeInsets = UIEdgeInsetsMake(top + iconSize + gap, -button.imageView.image.size.width, height - (top + iconSize + gap + titleH), 0.0);
}

static void MMUpdateButtons(UIViewController *vc, UITabBar *tabBar, UIView *bar) {
    UIView *host = MMEnsureButtonsHost(bar);
    NSArray *items = tabBar.items;
    NSInteger count = [items count];
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    CGFloat sideInset = 12.0;
    CGFloat interGap = 4.0;
    CGFloat usableW = CGRectGetWidth(host.bounds) - sideInset * 2.0 - interGap * (count - 1);
    CGFloat slotW = floor(usableW / count);
    CGFloat slotH = CGRectGetHeight(host.bounds);

    NSMutableSet *validTags = [NSMutableSet set];
    NSArray *fallbackTitles = count == 4 ? @[@"微信", @"通讯录", @"发现", @"我"] : nil;

    for (NSInteger i = 0; i < count; i++) {
        UIButton *button = MMEnsureTabButton(host, i);
        [validTags addObject:@(button.tag)];

        CGFloat x = sideInset + i * (slotW + interGap);
        CGFloat w = (i == count - 1) ? (CGRectGetWidth(host.bounds) - sideInset - x) : slotW;
        button.frame = CGRectMake(x, 0.0, w, slotH);

        UITabBarItem *item = [items objectAtIndex:i];
        UIImage *image = (i == selectedIndex && item.selectedImage) ? item.selectedImage : item.image;
        [button setImage:(image ? [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil) forState:UIControlStateNormal];

        NSString *title = item.title;
        if (![title length] && fallbackTitles && i < (NSInteger)[fallbackTitles count]) {
            title = [fallbackTitles objectAtIndex:i];
        }
        [button setTitle:title ?: @"" forState:UIControlStateNormal];

        UIColor *normalColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
        UIColor *selectedColor = [UIColor colorWithRed:0.00 green:0.76 blue:0.30 alpha:1.0];
        UIColor *color = (i == selectedIndex) ? selectedColor : normalColor;
        [button setTitleColor:color forState:UIControlStateNormal];
        button.tintColor = color;
        button.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightRegular)];

        MMConfigureButtonLayout(button, w, slotH);
    }

    for (UIView *sub in [[host subviews] copy]) {
        if (![validTags containsObject:@(sub.tag)]) {
            [sub removeFromSuperview];
        }
    }

    UIView *capsule = MMEnsureCapsule(bar);
    if (selectedIndex >= 0 && selectedIndex < count) {
        UIButton *selectedButton = (UIButton *)[host viewWithTag:8000 + selectedIndex];
        CGFloat capH = CGRectGetHeight(bar.bounds) - 10.0;
        CGFloat capW = MIN(CGRectGetWidth(selectedButton.frame) + 8.0, 68.0);
        CGFloat capX = CGRectGetMidX(selectedButton.frame) - capW * 0.5;
        CGFloat capY = (CGRectGetHeight(bar.bounds) - capH) * 0.5;
        if (capX < 4.0) capX = 4.0;
        if (capX + capW > CGRectGetWidth(bar.bounds) - 4.0) capX = CGRectGetWidth(bar.bounds) - 4.0 - capW;
        capsule.frame = CGRectMake(capX, capY, capW, capH);
        capsule.hidden = NO;
        MMStyleCapsule(capsule, bar);
    } else {
        capsule.hidden = YES;
    }

    [bar bringSubviewToFront:capsule];
    [bar bringSubviewToFront:host];
    (void)vc;
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

    UIVisualEffectView *blur = (UIVisualEffectView *)[searchHost viewWithTag:kMMFloatingSearchBlurTag];
    blur.frame = searchHost.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(searchHost.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetContinuousRadius(blur, size * 0.5);

    UIView *tint = [blur.contentView viewWithTag:kMMFloatingSearchTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(searchHost.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithWhite:1.0 alpha:0.12];

    searchHost.layer.shadowColor = [UIColor blackColor].CGColor;
    searchHost.layer.shadowOpacity = MMIsDark(searchHost.traitCollection) ? 0.12 : 0.10;
    searchHost.layer.shadowRadius = 20.0;
    searchHost.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    searchHost.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:searchHost.bounds cornerRadius:size * 0.5].CGPath;
    MMSetContinuousRadius(searchHost, size * 0.5);

    UIImageView *icon = (UIImageView *)[searchHost viewWithTag:kMMFloatingSearchIconTag];
    icon.frame = CGRectMake(floor((size - 28.0) * 0.5), floor((size - 28.0) * 0.5), 28.0, 28.0);
    icon.tintColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        icon.image = nil;
    }

    UIButton *button = (UIButton *)[searchHost viewWithTag:kMMFloatingSearchButtonTag];
    button.frame = searchHost.bounds;

    [root bringSubviewToFront:searchHost];
}

static void MMSetVisible(UIView *view, BOOL visible) {
    if (!view) return;
    view.hidden = !visible;
    view.alpha = visible ? 1.0 : 0.0;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdating) return;
    kMMUpdating = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    UIView *backdrop = MMEnsureBackdrop(root);
    UIView *bar = MMEnsureBar(root);
    UIView *searchHost = MMEnsureSearchHost(root);

    if (!root || !tabBar || !MMShouldShowFloatingBar(vc)) {
        MMSetVisible(backdrop, NO);
        MMSetVisible(bar, NO);
        MMSetVisible(searchHost, NO);
        kMMUpdating = NO;
        return;
    }

    UIViewController *homeVC = MMFindHomeController(vc);
    UIView *searchBar = homeVC ? MMFindSearchBarInView(homeVC.view) : nil;
    BOOL showSearch = (searchBar != nil);

    CGRect barFrame = MMComputeFloatingFrame(vc, tabBar, showSearch);

    backdrop.frame = CGRectMake(CGRectGetMinX(barFrame) - 6.0, CGRectGetMinY(barFrame) - 6.0, CGRectGetWidth(root.bounds) - (CGRectGetMinX(barFrame) - 6.0) * 2.0, CGRectGetHeight(barFrame) + 10.0);
    MMStyleBackdrop(backdrop);

    bar.frame = barFrame;
    MMStyleBar(bar);

    MMHideOriginalTabBar(tabBar);
    MMUpdateButtons(vc, tabBar, bar);
    MMUpdateSearchButton(vc, root, barFrame);

    [root bringSubviewToFront:backdrop];
    [root bringSubviewToFront:bar];
    [root bringSubviewToFront:searchHost];

    MMSetVisible(backdrop, YES);
    MMSetVisible(bar, YES);

    kMMUpdating = NO;
}

static void MMRequestRefresh(UIViewController *vc) {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar(vc);
    });
}

@implementation MMFloatingActionProxy

- (void)handleTabTap:(UIButton *)sender {
    NSInteger index = sender.tag - 8000;
    UIResponder *r = sender;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                UITabBar *tabBar = MMFindTabBar(vc);
                if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
                    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(vc, @selector(setSelectedIndex:), (NSUInteger)index);
                }
                if (tabBar && index >= 0 && index < (NSInteger)tabBar.items.count) {
                    tabBar.selectedItem = tabBar.items[index];
                }
                MMRequestRefresh(vc);
                break;
            }
        }
    }
}

- (void)handleSearchTap:(UIButton *)sender {
    UIResponder *r = sender;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMOpenSearchFromMainTab(vc);
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
