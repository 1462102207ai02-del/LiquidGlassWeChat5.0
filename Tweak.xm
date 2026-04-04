#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kMMGlassHostTag = 990001;
static NSInteger const kMMGlassViewTag = 990002;
static NSInteger const kMMCapsuleTag = 990003;
static NSInteger const kMMCapsuleBorderTag = 990004;
static NSInteger const kMMCapsuleGlowTag = 990005;

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

static UIColor *MMSelectedColor(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMRGBA(255, 255, 255, 1.0) : MMRGBA(24, 24, 27, 0.96);
}

static UIColor *MMNormalColor(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMRGBA(255, 255, 255, 0.76) : MMRGBA(82, 82, 91, 0.78);
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

static UIViewController *MMFindVC(UIView *view) {
    UIResponder *r = view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
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

static UIView *MMHost(UIView *container) {
    UIView *host = [container viewWithTag:kMMGlassHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMGlassHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = NO;
        host.clipsToBounds = NO;
        [container addSubview:host];
    }
    return host;
}

static UIVisualEffectView *MMGlass(UIView *host) {
    UIVisualEffectView *glass = (UIVisualEffectView *)[host viewWithTag:kMMGlassViewTag];
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        glass.tag = kMMGlassViewTag;
        glass.userInteractionEnabled = NO;
        [host addSubview:glass];
    }

    glass.frame = host.bounds;
    glass.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.05) : MMRGBA(255, 255, 255, 0.13);
    MMSetRadius(glass, host.bounds.size.height / 2.0);
    glass.layer.masksToBounds = YES;

    CAGradientLayer *shine = MMFindGradient(glass.contentView.layer, @"mmHostShine");
    if (!shine) {
        shine = [CAGradientLayer layer];
        shine.name = @"mmHostShine";
        [glass.contentView.layer addSublayer:shine];
    }
    shine.frame = CGRectMake(0, 0, glass.bounds.size.width, glass.bounds.size.height * 0.52);
    shine.startPoint = CGPointMake(0.5, 0.0);
    shine.endPoint = CGPointMake(0.5, 1.0);
    shine.colors = @[
        (__bridge id)MMRGBA(255, 255, 255, 0.14).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.05).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.00).CGColor
    ];

    return glass;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.clipsToBounds = NO;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    if (!border) {
        border = [UIView new];
        border.tag = kMMCapsuleBorderTag;
        border.userInteractionEnabled = NO;
        border.clipsToBounds = YES;
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    if (!glow) {
        glow = [UIView new];
        glow.tag = kMMCapsuleGlowTag;
        glow.userInteractionEnabled = NO;
        glow.clipsToBounds = YES;
        [capsule addSubview:glow];
    }

    return capsule;
}

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, host.bounds.size.height / 2.0);
    host.layer.borderWidth = 0.42;
    host.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.12) : MMRGBA(255, 255, 255, 0.22)).CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(host.traitCollection) ? 0.24 : 0.12)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0, 8);
}

static CGRect MMSlotFrameForIndex(UIView *host, NSInteger idx, NSInteger count) {
    CGFloat side = 18.0;
    CGFloat top = 7.0;
    CGFloat totalW = host.bounds.size.width - side * 2.0;
    CGFloat slotW = floor(totalW / count);
    CGFloat slotH = host.bounds.size.height - top * 2.0;
    CGFloat x = side + slotW * idx;
    CGFloat w = (idx == count - 1) ? (host.bounds.size.width - side - x) : slotW;
    return CGRectMake(x, top, w, slotH);
}

static CGRect MMCapsuleFrameForIndex(UIView *host, NSInteger idx, NSInteger count) {
    CGRect slot = MMSlotFrameForIndex(host, idx, count);
    return CGRectInset(slot, 5.0, 1.0);
}

static void MMStyleCapsule(UIView *host, NSInteger selectedIndex, NSInteger count) {
    if (count <= 0) return;

    UIView *capsule = MMCapsule(host);
    CGRect frame = MMCapsuleFrameForIndex(host, selectedIndex, count);
    capsule.frame = frame;
    capsule.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.10) : MMRGBA(255, 255, 255, 0.24);
    MMSetRadius(capsule, frame.size.height / 2.0);

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.55;
    border.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.12) : MMRGBA(255, 255, 255, 0.24)).CGColor;
    MMSetRadius(border, border.bounds.size.height / 2.0);

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    MMSetRadius(glow, glow.bounds.size.height / 2.0);

    CAGradientLayer *grad = MMFindGradient(glow.layer, @"mmCapsuleGlow");
    if (!grad) {
        grad = [CAGradientLayer layer];
        grad.name = @"mmCapsuleGlow";
        [glow.layer addSublayer:grad];
    }
    grad.frame = glow.bounds;
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint = CGPointMake(0.5, 1.0);
    grad.colors = @[
        (__bridge id)MMRGBA(255, 255, 255, 0.10).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.03).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.00).CGColor
    ];
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

    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"Background"] || [name containsString:@"BarBackground"] || [name containsString:@"Shadow"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
    }
}

static NSArray<UIView *> *MMItemViews(UITabBar *tabBar) {
    NSMutableArray<UIView *> *result = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBarItemView"]) {
            [result addObject:sub];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat x1 = CGRectGetMinX(a.frame);
        CGFloat x2 = CGRectGetMinX(b.frame);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return result;
}

static void MMApplyColorRecursively(UIView *view, UIColor *color) {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        if (iv.image) {
            iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            iv.tintColor = color;
        }
    } else if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        label.textColor = color;
    }
    for (UIView *sub in view.subviews) {
        MMApplyColorRecursively(sub, color);
    }
}

static void MMHideDuplicateLayers(UIView *item) {
    @try {
        id customContent = [item valueForKey:@"_customContentView"];
        if (customContent && [customContent respondsToSelector:@selector(view)]) {
            UIView *customView = [customContent view];
            if ([customView isKindOfClass:[UIView class]]) {
                customView.hidden = YES;
                customView.alpha = 0.0;
                customView.userInteractionEnabled = NO;
            }
        }
    } @catch (__unused NSException *e) {
    }
}

static void MMLayoutItemInternals(UIView *item) {
    UIImageView *imageView = nil;
    UILabel *textLabel = nil;
    UIView *badgeView = nil;

    @try { imageView = [item valueForKey:@"_imageView"]; } @catch (__unused NSException *e) {}
    @try { textLabel = [item valueForKey:@"_textLabel"]; } @catch (__unused NSException *e) {}
    @try { badgeView = [item valueForKey:@"_badgeView"]; } @catch (__unused NSException *e) {}

    if (![imageView isKindOfClass:[UIImageView class]] || ![textLabel isKindOfClass:[UILabel class]]) return;

    CGFloat bw = item.bounds.size.width;
    CGFloat bh = item.bounds.size.height;
    CGFloat iconSize = 27.0;
    CGFloat titleH = 14.0;
    CGFloat spacing = 4.0;
    CGFloat totalH = iconSize + spacing + titleH;
    CGFloat startY = floor((bh - totalH) * 0.5);
    if (startY < 4.0) startY = 4.0;

    imageView.frame = CGRectMake(floor((bw - iconSize) * 0.5), startY, iconSize, iconSize);
    imageView.contentMode = UIViewContentModeScaleAspectFit;

    textLabel.frame = CGRectMake(0.0, startY + iconSize + spacing, bw, titleH);
    textLabel.textAlignment = NSTextAlignmentCenter;
    textLabel.adjustsFontSizeToFitWidth = YES;
    textLabel.minimumScaleFactor = 0.72;

    if ([badgeView isKindOfClass:[UIView class]]) {
        CGRect bf = badgeView.frame;
        bf.origin.x = CGRectGetMaxX(imageView.frame) - 2.0;
        bf.origin.y = CGRectGetMinY(imageView.frame) - 2.0;
        badgeView.frame = bf;
    }
}

static void MMLayoutItems(UITabBar *tabBar) {
    NSArray<UIView *> *items = MMItemViews(tabBar);
    NSInteger count = items.count;
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    for (NSInteger i = 0; i < count; i++) {
        UIView *item = items[i];
        CGRect target = (i == selectedIndex) ? MMCapsuleFrameForIndex(tabBar, i, count) : MMSlotFrameForIndex(tabBar, i, count);
        item.frame = target;
        item.hidden = NO;
        item.alpha = 1.0;
        item.userInteractionEnabled = YES;
        item.backgroundColor = [UIColor clearColor];
        item.opaque = NO;
        item.clipsToBounds = NO;
        item.layer.zPosition = 20;

        MMHideDuplicateLayers(item);
        MMLayoutItemInternals(item);
        MMApplyColorRecursively(item, (i == selectedIndex) ? MMSelectedColor(tabBar.traitCollection) : MMNormalColor(tabBar.traitCollection));
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

    UIView *host = MMHost(root);
    host.hidden = NO;
    tabBar.hidden = NO;

    CGFloat inset = MMBottomInset(root);
    CGFloat height = 83.0;
    CGFloat margin = 18.0;
    CGFloat targetY = CGRectGetHeight(root.bounds) - inset - height - 10.0;

    host.frame = CGRectMake(margin, targetY, CGRectGetWidth(root.bounds) - margin * 2.0, height);
    MMStyleHost(host);
    MMGlass(host);

    tabBar.transform = CGAffineTransformIdentity;
    tabBar.frame = host.frame;
    tabBar.alpha = 1.0;
    tabBar.userInteractionEnabled = YES;
    MMPrepareTabBar(tabBar);

    NSArray<UIView *> *items = MMItemViews(tabBar);
    MMStyleCapsule(host, tabBar.selectedItem ? [tabBar.items indexOfObject:tabBar.selectedItem] : 0, items.count);
    MMLayoutItems(tabBar);

    [root bringSubviewToFront:host];
    [root bringSubviewToFront:tabBar];

    kMMUpdatingLayout = NO;
}

%hook MMTabBarItemView

- (void)layoutSubviews {
    %orig;
    MMHideDuplicateLayers((UIView *)self);
    MMLayoutItemInternals((UIView *)self);
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

%hook UITabBar

- (void)setSelectedItem:(UITabBarItem *)item {
    %orig(item);
    UIViewController *vc = MMFindVC(self);
    if (vc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MMUpdate(vc);
        });
    }
}

%end
