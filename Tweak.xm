#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMGlassHostTag = 980001;
static NSInteger const kMMGlassViewTag = 980002;
static NSInteger const kMMButtonsContainerTag = 980003;
static NSInteger const kMMHitContainerTag = 980004;
static NSInteger const kMMCapsuleTag = 980005;
static NSInteger const kMMCapsuleBorderTag = 980006;
static NSInteger const kMMCapsuleGlowTag = 980007;

static const void *kMMStoredItemViewsKey = &kMMStoredItemViewsKey;
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

static UIViewController *MMFindVC(UIView *view) {
    UIResponder *r = view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    }
    return nil;
}

static NSInteger MMSelectedIndex(UITabBar *tabBar) {
    if (!tabBar || tabBar.items.count == 0) return 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) return idx;
    }
    return 0;
}

static void MMCollectItemViewsRecursive(UIView *view, NSMutableArray<UIView *> *result) {
    NSString *name = NSStringFromClass([view class]);
    if ([name containsString:@"MMTabBarItemView"]) {
        [result addObject:view];
        return;
    }
    for (UIView *sub in view.subviews) {
        MMCollectItemViewsRecursive(sub, result);
    }
}

static NSArray<UIView *> *MMItemViews(UITabBar *tabBar) {
    NSArray *stored = objc_getAssociatedObject(tabBar, kMMStoredItemViewsKey);
    if ([stored isKindOfClass:[NSArray class]] && stored.count > 0) {
        return stored;
    }

    NSMutableArray<UIView *> *result = [NSMutableArray array];
    MMCollectItemViewsRecursive(tabBar, result);

    [result sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat x1 = CGRectGetMinX(a.frame);
        CGFloat x2 = CGRectGetMinX(b.frame);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    if (result.count > 0) {
        objc_setAssociatedObject(tabBar, kMMStoredItemViewsKey, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return result;
}

static void MMSetItemSelected(UIView *itemView, BOOL selected) {
    SEL sel = @selector(setSelected:);
    if ([itemView respondsToSelector:sel]) {
        IMP imp = [itemView methodForSelector:sel];
        void (*func)(id, SEL, BOOL) = (void *)imp;
        func(itemView, sel, selected);
    }
}

static void MMClearTabBar(UITabBar *tabBar) {
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
        if ([name containsString:@"Background"] || [name containsString:@"Shadow"] || [name containsString:@"BarBackground"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
    }
}

static UIView *MMHost(UIView *container) {
    UIView *host = [container viewWithTag:kMMGlassHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMGlassHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = YES;
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
    glass.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.06) : MMRGBA(255, 255, 255, 0.14);
    MMSetRadius(glass, host.bounds.size.height / 2.0);
    glass.layer.masksToBounds = YES;
    return glass;
}

static UIView *MMButtonsContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMButtonsContainerTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMButtonsContainerTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = YES;
        container.clipsToBounds = NO;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    return container;
}

static UIView *MMHitContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMHitContainerTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMHitContainerTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = YES;
        container.clipsToBounds = NO;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    return container;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.userInteractionEnabled = NO;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    if (!border) {
        border = [UIView new];
        border.tag = kMMCapsuleBorderTag;
        border.backgroundColor = [UIColor clearColor];
        border.userInteractionEnabled = NO;
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    if (!glow) {
        glow = [UIView new];
        glow.tag = kMMCapsuleGlowTag;
        glow.backgroundColor = [UIColor clearColor];
        glow.userInteractionEnabled = NO;
        [capsule addSubview:glow];
    }

    return capsule;
}

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, host.bounds.size.height / 2.0);
    host.layer.borderWidth = 0.6;
    host.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.16) : MMRGBA(255, 255, 255, 0.30)).CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(host.traitCollection) ? 0.32 : 0.16)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 22.0;
    host.layer.shadowOffset = CGSizeMake(0, 10);

    CAGradientLayer *top = MMFindGradient(host.layer, @"topGloss");
    if (!top) {
        top = [CAGradientLayer layer];
        top.name = @"topGloss";
        [host.layer insertSublayer:top atIndex:0];
    }
    top.frame = CGRectMake(0, 0, host.bounds.size.width, host.bounds.size.height * 0.55);
    top.startPoint = CGPointMake(0.5, 0.0);
    top.endPoint = CGPointMake(0.5, 1.0);
    top.colors = @[
        (__bridge id)MMRGBA(255, 255, 255, 0.20).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.08).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.00).CGColor
    ];
}

static void MMCapsuleLayout(UIView *host, NSInteger idx, NSInteger cnt) {
    if (cnt <= 0) return;

    UIView *capsule = MMCapsule(host);

    CGFloat side = 8.0;
    CGFloat top = 6.0;
    CGFloat slotW = (host.bounds.size.width - side * 2.0) / cnt;
    CGFloat slotH = host.bounds.size.height - top * 2.0;

    CGRect target = CGRectMake(side + slotW * idx + 2.0, top, slotW - 4.0, slotH);

    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        capsule.frame = target;
        capsule.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.12) : MMRGBA(255, 255, 255, 0.30);
        MMSetRadius(capsule, target.size.height / 2.0);
    } completion:nil];

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.7;
    border.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.16) : MMRGBA(255, 255, 255, 0.36)).CGColor;
    MMSetRadius(border, border.bounds.size.height / 2.0);

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    MMSetRadius(glow, glow.bounds.size.height / 2.0);

    CAGradientLayer *grad = MMFindGradient(glow.layer, @"capsuleGlow");
    if (!grad) {
        grad = [CAGradientLayer layer];
        grad.name = @"capsuleGlow";
        [glow.layer addSublayer:grad];
    }
    grad.frame = glow.bounds;
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint = CGPointMake(0.5, 1.0);
    grad.colors = @[
        (__bridge id)MMRGBA(255, 255, 255, 0.16).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.05).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.01).CGColor
    ];
}

static void MMSwitchToIndex(UIView *view, NSInteger idx) {
    UIViewController *vc = MMFindVC(view);
    if (!vc) return;

    if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
        @try {
            [(id)vc setSelectedIndex:idx];
            return;
        } @catch (__unused NSException *e) {
        }
    }

    UITabBar *tb = MMFindTabBar(vc);
    if (tb && idx >= 0 && idx < (NSInteger)tb.items.count) {
        @try {
            tb.selectedItem = tb.items[idx];
        } @catch (__unused NSException *e) {
        }
    }
}

@interface MMHitButton : UIControl
@end

@implementation MMHitButton
- (void)mmTap {
    NSInteger idx = self.tag - 2000;
    MMSwitchToIndex(self, idx);
}
@end

static void MMLayoutItemViews(UITabBar *tabBar, UIView *host) {
    UIView *container = MMButtonsContainer(host);
    NSArray<UIView *> *itemViews = MMItemViews(tabBar);
    NSInteger cnt = itemViews.count;
    if (cnt == 0) return;

    NSInteger sel = MMSelectedIndex(tabBar);

    CGFloat side = 8.0;
    CGFloat slotW = (container.bounds.size.width - side * 2.0) / cnt;
    CGFloat itemH = 87.0;
    CGFloat itemY = floor((container.bounds.size.height - itemH) * 0.5);

    MMCapsuleLayout(host, sel, cnt);

    for (NSInteger i = 0; i < cnt; i++) {
        UIView *item = itemViews[i];
        if (item.superview != container) {
            [item removeFromSuperview];
            [container addSubview:item];
        }

        CGFloat x = side + slotW * i;
        CGFloat w = (i == cnt - 1) ? (container.bounds.size.width - side - x) : slotW;

        item.frame = CGRectMake(x, itemY, w, itemH);
        item.hidden = NO;
        item.alpha = 1.0;
        item.userInteractionEnabled = NO;
        item.backgroundColor = [UIColor clearColor];
        item.layer.zPosition = 10;

        MMSetItemSelected(item, i == sel);
    }

    [host bringSubviewToFront:[host viewWithTag:kMMCapsuleTag]];
    [host bringSubviewToFront:container];
}

static void MMLayoutHitButtons(UITabBar *tabBar, UIView *host) {
    UIView *container = MMHitContainer(host);
    for (UIView *sub in [container.subviews copy]) {
        [sub removeFromSuperview];
    }

    NSArray<UIView *> *itemViews = MMItemViews(tabBar);
    NSInteger cnt = itemViews.count;
    if (cnt == 0) return;

    CGFloat side = 8.0;
    CGFloat top = 6.0;
    CGFloat slotW = (container.bounds.size.width - side * 2.0) / cnt;
    CGFloat slotH = container.bounds.size.height - top * 2.0;

    for (NSInteger i = 0; i < cnt; i++) {
        CGFloat x = side + slotW * i;
        CGFloat w = (i == cnt - 1) ? (container.bounds.size.width - side - x) : slotW;

        MMHitButton *button = [MMHitButton new];
        button.frame = CGRectMake(x, top, w, slotH);
        button.tag = 2000 + i;
        button.backgroundColor = [UIColor clearColor];
        [button addTarget:button action:@selector(mmTap) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:button];
    }

    [host bringSubviewToFront:container];
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

    CGFloat inset = MMBottomInset(root);
    CGFloat height = 64.0;
    CGFloat margin = 16.0;
    CGRect frame = CGRectMake(margin, root.bounds.size.height - inset - height - 10.0, root.bounds.size.width - margin * 2.0, height);

    UIView *host = MMHost(root);
    host.frame = frame;
    MMStyleHost(host);
    MMGlass(host);

    MMClearTabBar(tabBar);

    tabBar.frame = CGRectMake(0, root.bounds.size.height + 200.0, 1.0, 1.0);
    tabBar.userInteractionEnabled = NO;
    tabBar.hidden = NO;
    tabBar.alpha = 0.01;

    MMLayoutItemViews(tabBar, host);
    MMLayoutHitButtons(tabBar, host);

    [root bringSubviewToFront:host];

    kMMUpdatingLayout = NO;
}

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
