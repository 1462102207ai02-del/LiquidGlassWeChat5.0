#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMGlassHostTag = 990001;
static NSInteger const kMMGlassViewTag = 990002;
static NSInteger const kMMButtonsContainerTag = 990003;
static NSInteger const kMMHitContainerTag = 990004;
static NSInteger const kMMCapsuleTag = 990005;
static NSInteger const kMMCapsuleBorderTag = 990006;
static NSInteger const kMMCapsuleGlowTag = 990007;

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
        void (*func)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))imp;
        func(itemView, sel, selected);
    }
}

static void MMClearTreeBackground(UIView *view, BOOL preserveBadge) {
    NSString *name = NSStringFromClass([view class]);

    if (!preserveBadge) {
        if ([name localizedCaseInsensitiveContainsString:@"background"]) {
            view.hidden = YES;
            view.alpha = 0.0;
        } else {
            view.backgroundColor = [UIColor clearColor];
            view.opaque = NO;
        }
    }

    BOOL childPreserveBadge = preserveBadge || [name localizedCaseInsensitiveContainsString:@"badge"];
    for (UIView *sub in view.subviews) {
        MMClearTreeBackground(sub, childPreserveBadge);
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
    glass.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.05) : MMRGBA(255, 255, 255, 0.13);
    MMSetRadius(glass, host.bounds.size.height / 2.0);
    glass.layer.masksToBounds = YES;

    CAGradientLayer *shine = MMFindGradient(glass.contentView.layer, @"hostShine");
    if (!shine) {
        shine = [CAGradientLayer layer];
        shine.name = @"hostShine";
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

static UIView *MMButtonsContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMButtonsContainerTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMButtonsContainerTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = YES;
        container.clipsToBounds = YES;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    MMSetRadius(container, host.bounds.size.height / 2.0);
    return container;
}

static UIView *MMHitContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMHitContainerTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMHitContainerTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = YES;
        container.clipsToBounds = YES;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    MMSetRadius(container, host.bounds.size.height / 2.0);
    return container;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.userInteractionEnabled = NO;
        capsule.clipsToBounds = NO;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    if (!border) {
        border = [UIView new];
        border.tag = kMMCapsuleBorderTag;
        border.backgroundColor = [UIColor clearColor];
        border.userInteractionEnabled = NO;
        border.clipsToBounds = YES;
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    if (!glow) {
        glow = [UIView new];
        glow.tag = kMMCapsuleGlowTag;
        glow.backgroundColor = [UIColor clearColor];
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
    host.backgroundColor = [UIColor clearColor];
}

static CGRect MMSlotFrameForIndex(UIView *host, NSInteger idx, NSInteger cnt) {
    CGFloat side = 10.0;
    CGFloat top = 8.0;
    CGFloat slotW = floor((host.bounds.size.width - side * 2.0) / cnt);
    CGFloat slotH = host.bounds.size.height - top * 2.0;
    CGFloat x = side + slotW * idx;
    CGFloat w = (idx == cnt - 1) ? (host.bounds.size.width - side - x) : slotW;
    return CGRectMake(x, top, w, slotH);
}

static CGRect MMCapsuleFrameForIndex(UIView *host, NSInteger idx, NSInteger cnt) {
    CGRect slot = MMSlotFrameForIndex(host, idx, cnt);
    return CGRectInset(slot, 1.5, 0.0);
}

static void MMCapsuleLayout(UIView *host, NSInteger idx, NSInteger cnt) {
    if (cnt <= 0) return;

    UIView *capsule = MMCapsule(host);
    CGRect target = MMCapsuleFrameForIndex(host, idx, cnt);

    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        capsule.frame = target;
        capsule.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.10) : MMRGBA(255, 255, 255, 0.24);
        MMSetRadius(capsule, target.size.height / 2.0);
    } completion:nil];

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.55;
    border.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.12) : MMRGBA(255, 255, 255, 0.24)).CGColor;
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
        (__bridge id)MMRGBA(255, 255, 255, 0.10).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.03).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.00).CGColor
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

static void MMApplyColorRecursively(UIView *view, UIColor *color) {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        if (iv.image) {
            iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            iv.tintColor = color;
        }
    } else if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lab = (UILabel *)view;
        lab.textColor = color;
    }

    for (UIView *sub in view.subviews) {
        MMApplyColorRecursively(sub, color);
    }
}

static void MMLayoutSingleItemView(UIView *item, BOOL selected, UITraitCollection *trait) {
    MMClearTreeBackground(item, NO);

    UIImageView *imageView = MMKVC(item, @"imageView");
    UILabel *textLabel = MMKVC(item, @"textLabel");
    UIView *badgeView = MMKVC(item, @"badgeView");
    UIView *backgroundView = MMKVC(item, @"backgroundView");

    if ([backgroundView isKindOfClass:[UIView class]]) {
        backgroundView.hidden = YES;
        backgroundView.alpha = 0.0;
    }

    MMSetItemSelected(item, selected);

    UIColor *color = selected ? MMSelectedColor(trait) : MMNormalColor(trait);

    CGFloat bw = item.bounds.size.width;
    CGFloat bh = item.bounds.size.height;

    CGFloat iconSize = 28.0;
    CGFloat titleH = 14.0;
    CGFloat spacing = 3.0;
    CGFloat totalH = iconSize + spacing + titleH;
    CGFloat startY = floor((bh - totalH) * 0.5) - 1.0;
    if (startY < 4.0) startY = 4.0;

    if ([imageView isKindOfClass:[UIImageView class]]) {
        if (imageView.image) {
            imageView.image = [imageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        imageView.tintColor = color;
        imageView.frame = CGRectMake(floor((bw - iconSize) * 0.5), startY, iconSize, iconSize);
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.opaque = NO;
    }

    if ([textLabel isKindOfClass:[UILabel class]]) {
        textLabel.frame = CGRectMake(2.0, startY + iconSize + spacing, bw - 4.0, titleH);
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.textColor = color;
        textLabel.font = [UIFont systemFontOfSize:11.0 weight:selected ? UIFontWeightSemibold : UIFontWeightRegular];
        textLabel.adjustsFontSizeToFitWidth = YES;
        textLabel.minimumScaleFactor = 0.7;
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.opaque = NO;
    }

    if ([badgeView isKindOfClass:[UIView class]] && [imageView isKindOfClass:[UIImageView class]]) {
        CGRect bf = badgeView.frame;
        bf.origin.x = CGRectGetMaxX(imageView.frame) - 1.0;
        bf.origin.y = CGRectGetMinY(imageView.frame) - 2.0;
        badgeView.frame = bf;
    }

    MMApplyColorRecursively(item, color);
}

static void MMLayoutItemViews(UITabBar *tabBar, UIView *host) {
    UIView *container = MMButtonsContainer(host);
    NSArray<UIView *> *itemViews = MMItemViews(tabBar);
    NSInteger cnt = itemViews.count;
    if (cnt == 0) return;

    NSInteger sel = MMSelectedIndex(tabBar);
    MMCapsuleLayout(host, sel, cnt);

    for (NSInteger i = 0; i < cnt; i++) {
        UIView *item = itemViews[i];
        if (item.superview != container) {
            [item removeFromSuperview];
            [container addSubview:item];
        }

        CGRect slot = MMSlotFrameForIndex(host, i, cnt);
        CGRect capsule = MMCapsuleFrameForIndex(host, i, cnt);

        CGFloat itemW = capsule.size.width - 8.0;
        CGFloat itemH = 56.0;
        CGFloat itemX = floor(CGRectGetMidX(slot) - itemW * 0.5);
        CGFloat itemY = floor(CGRectGetMidY(slot) - itemH * 0.5);

        if (i == sel) {
            itemX = floor(CGRectGetMidX(capsule) - itemW * 0.5);
            itemY = floor(CGRectGetMidY(capsule) - itemH * 0.5);
        }

        item.frame = CGRectMake(itemX, itemY, itemW, itemH);
        item.hidden = NO;
        item.alpha = 1.0;
        item.userInteractionEnabled = NO;
        item.backgroundColor = [UIColor clearColor];
        item.opaque = NO;
        item.layer.zPosition = 10;
        item.clipsToBounds = NO;

        MMLayoutSingleItemView(item, i == sel, host.traitCollection);
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

    for (NSInteger i = 0; i < cnt; i++) {
        CGRect slot = MMSlotFrameForIndex(host, i, cnt);

        MMHitButton *button = [MMHitButton new];
        button.frame = slot;
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

    UIView *host = MMHost(root);

    if (!MMShouldShowFloatingBar(vc)) {
        host.hidden = YES;
        kMMUpdatingLayout = NO;
        return;
    }

    host.hidden = NO;

    CGFloat inset = MMBottomInset(root);
    CGFloat height = 64.0;
    CGFloat margin = 16.0;
    CGRect frame = CGRectMake(margin, root.bounds.size.height - inset - height - 10.0, root.bounds.size.width - margin * 2.0, height);

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
