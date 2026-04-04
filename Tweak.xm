#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMFloatingHostTag = 990101;
static NSInteger const kMMFloatingBlurTag = 990102;
static NSInteger const kMMFloatingCapsuleTag = 990103;
static NSInteger const kMMFloatingCapsuleBorderTag = 990104;
static NSInteger const kMMFloatingCapsuleGlowTag = 990105;
static NSInteger const kMMFloatingItemsContainerTag = 990106;

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

static id MMKVC(id obj, NSString *key) {
    @try {
        return [obj valueForKey:key];
    } @catch (__unused NSException *e) {
        return nil;
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

static BOOL MMShouldHideFloatingBar(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return YES;

    UIViewController *content = MMCurrentContentController(vc);
    NSString *name = NSStringFromClass([content class]);
    if ([name isEqualToString:@"MinimizeViewController"]) return YES;

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

static NSArray<UIView *> *MMCollectItemViews(UITabBar *tabBar) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBarItemView"]) {
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

static void MMApplyColorRecursively(UIView *view, UIColor *color) {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        if (imageView.image) {
            imageView.image = [imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            imageView.tintColor = color;
        }
    } else if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        label.textColor = color;
    }

    for (UIView *sub in view.subviews) {
        MMApplyColorRecursively(sub, color);
    }
}

static CGRect MMSlotFrame(UIView *host, NSInteger index, NSInteger count) {
    CGFloat side = 18.0;
    CGFloat top = 7.0;
    CGFloat totalW = host.bounds.size.width - side * 2.0;
    CGFloat slotW = floor(totalW / MAX(count, 1));
    CGFloat slotH = host.bounds.size.height - top * 2.0;
    CGFloat x = side + slotW * index;
    CGFloat w = (index == count - 1) ? (host.bounds.size.width - side - x) : slotW;
    return CGRectMake(x, top, w, slotH);
}

static CGRect MMCapsuleFrame(UIView *host, NSInteger index, NSInteger count) {
    return CGRectInset(MMSlotFrame(host, index, count), 5.0, 1.0);
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
        blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        blur.tag = kMMFloatingBlurTag;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];
    }
    blur.frame = host.bounds;
    blur.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.05) : MMRGBA(255, 255, 255, 0.13);
    MMSetRadius(blur, host.bounds.size.height * 0.5);
    blur.layer.masksToBounds = YES;
    return blur;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMFloatingCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMFloatingCapsuleTag;
        capsule.userInteractionEnabled = NO;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    if (!border) {
        border = [UIView new];
        border.tag = kMMFloatingCapsuleBorderTag;
        border.userInteractionEnabled = NO;
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMFloatingCapsuleGlowTag];
    if (!glow) {
        glow = [UIView new];
        glow.tag = kMMFloatingCapsuleGlowTag;
        glow.userInteractionEnabled = NO;
        [capsule addSubview:glow];
    }

    return capsule;
}

static UIView *MMItemsContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMFloatingItemsContainerTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMFloatingItemsContainerTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = NO;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    return container;
}

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, host.bounds.size.height * 0.5);
    host.layer.borderWidth = 0.42;
    host.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.12) : MMRGBA(255,255,255,0.22)).CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(host.traitCollection) ? 0.24 : 0.12)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0, 8);
}

static void MMLayoutCapsule(UIView *host, NSInteger selectedIndex, NSInteger count) {
    UIView *capsule = MMCapsule(host);
    CGRect frame = MMCapsuleFrame(host, selectedIndex, count);
    capsule.frame = frame;
    capsule.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.10) : MMRGBA(255,255,255,0.24);
    MMSetRadius(capsule, frame.size.height * 0.5);

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.55;
    border.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.12) : MMRGBA(255,255,255,0.24)).CGColor;
    MMSetRadius(border, border.bounds.size.height * 0.5);

    UIView *glow = [capsule viewWithTag:kMMFloatingCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    MMSetRadius(glow, glow.bounds.size.height * 0.5);
    CAGradientLayer *grad = nil;
    for (CALayer *sub in glow.layer.sublayers) {
        if ([sub isKindOfClass:[CAGradientLayer class]]) {
            grad = (CAGradientLayer *)sub;
            break;
        }
    }
    if (!grad) {
        grad = [CAGradientLayer layer];
        [glow.layer addSublayer:grad];
    }
    grad.frame = glow.bounds;
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint = CGPointMake(0.5, 1.0);
    grad.colors = @[
        (__bridge id)MMRGBA(255,255,255,0.10).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.03).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.00).CGColor
    ];
}

static UIView *MMDuplicateItemView(UIView *source) {
    NSData *archived = nil;
    @try {
        archived = [NSKeyedArchiver archivedDataWithRootObject:source requiringSecureCoding:NO error:nil];
    } @catch (__unused NSException *e) {
    }
    if (!archived) return nil;
    UIView *copy = nil;
    @try {
        copy = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIView class] fromData:archived error:nil];
    } @catch (__unused NSException *e) {
    }
    return copy;
}

static void MMLayoutClonedItem(UIView *item, BOOL selected, UITraitCollection *trait) {
    UIView *customView = MMKVC(item, @"_customContentView");
    if ([customView isKindOfClass:[UIView class]]) {
        customView.hidden = YES;
        customView.alpha = 0.0;
    }

    UIImageView *imageView = MMKVC(item, @"_imageView");
    UILabel *textLabel = MMKVC(item, @"_textLabel");
    UIView *badgeView = MMKVC(item, @"_badgeView");

    if (![imageView isKindOfClass:[UIImageView class]] || ![textLabel isKindOfClass:[UILabel class]]) {
        MMApplyColorRecursively(item, selected ? MMSelectedColor(trait) : MMNormalColor(trait));
        return;
    }

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

    MMApplyColorRecursively(item, selected ? MMSelectedColor(trait) : MMNormalColor(trait));
}

static void MMRefreshFloatingItems(UIViewController *vc, UITabBar *tabBar, UIView *host) {
    UIView *container = MMItemsContainer(host);
    for (UIView *sub in [container.subviews copy]) {
        [sub removeFromSuperview];
    }

    NSArray<UIView *> *originalItems = MMCollectItemViews(tabBar);
    NSInteger count = originalItems.count;
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    MMLayoutCapsule(host, selectedIndex, count);

    for (NSInteger i = 0; i < count; i++) {
        UIView *clone = MMDuplicateItemView(originalItems[i]);
        if (![clone isKindOfClass:[UIView class]]) continue;

        CGRect target = (i == selectedIndex) ? MMCapsuleFrame(host, i, count) : MMSlotFrame(host, i, count);
        clone.frame = target;
        clone.userInteractionEnabled = NO;
        clone.backgroundColor = [UIColor clearColor];
        clone.opaque = NO;
        clone.clipsToBounds = NO;
        clone.layer.zPosition = 20;

        MMLayoutClonedItem(clone, i == selectedIndex, host.traitCollection);
        [container addSubview:clone];
    }
}

static void MMHideOriginalTabBarVisuals(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 0.01;
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

    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"_UIBarBackground"] || [name containsString:@"Background"] || [name containsString:@"Shadow"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
        if ([name containsString:@"MMTabBarItemView"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.userInteractionEnabled = NO;
        }
    }
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!root || !tabBar) {
        kMMUpdatingLayout = NO;
        return;
    }

    UIView *host = MMHost(root);

    if (MMShouldHideFloatingBar(vc)) {
        host.hidden = YES;
        tabBar.hidden = YES;
        kMMUpdatingLayout = NO;
        return;
    }

    host.hidden = NO;
    tabBar.hidden = NO;

    CGFloat inset = MMBottomInset(root);
    CGFloat margin = 18.0;
    CGFloat height = 87.0;
    CGFloat y = CGRectGetHeight(root.bounds) - inset - height - 10.0;
    CGRect frame = CGRectMake(margin, y, CGRectGetWidth(root.bounds) - margin * 2.0, height);

    host.frame = frame;
    MMStyleHost(host);
    MMBlur(host);

    tabBar.transform = CGAffineTransformIdentity;
    tabBar.frame = frame;
    MMHideOriginalTabBarVisuals(tabBar);
    MMRefreshFloatingItems(vc, tabBar, host);

    [root bringSubviewToFront:host];

    kMMUpdatingLayout = NO;
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar((UIViewController *)self);
    });
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
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar((UIViewController *)self);
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
                    MMUpdateFloatingBar(vc);
                });
                break;
            }
        }
    }
}

%end
