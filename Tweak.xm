#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kMMGlassHostTag = 950001;
static NSInteger const kMMGlassViewTag = 950002;
static NSInteger const kMMButtonsContainerTag = 950003;
static NSInteger const kMMCapsuleTag = 950004;
static NSInteger const kMMCapsuleBorderTag = 950005;
static NSInteger const kMMCapsuleGlowTag = 950006;

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

static void MMSetContinuousRadius(UIView *view, CGFloat radius) {
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

static UIViewController *MMFindParentViewController(UIView *view) {
    UIResponder *responder = view;
    while (responder) {
        responder = [responder nextResponder];
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
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

static NSArray<UIView *> *MMNativeTabButtons(UITabBar *tabBar) {
    NSMutableArray *arr = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBarItemView"] || [name containsString:@"UITabBarButton"]) {
            [arr addObject:sub];
        }
    }
    [arr sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return arr;
}

static UIImage *MMSnapshotView(UIView *view) {
    CGSize size = view.bounds.size;
    if (size.width <= 0.0 || size.height <= 0.0) return nil;

    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        UIGraphicsEndImageContext();
        return nil;
    }

    [view.layer renderInContext:ctx];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static void MMClearNativeTabBar(UITabBar *tabBar) {
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.translucent = YES;
    tabBar.clipsToBounds = NO;

    if (NSClassFromString(@"UITabBarAppearance")) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
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
        if ([name containsString:@"Background"] || [name containsString:@"BarBackground"] || [name containsString:@"ShadowView"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
    }
}

static UIView *MMEnsureGlassHost(UIView *container) {
    UIView *host = [container viewWithTag:kMMGlassHostTag];
    if (!host) {
        host = [[UIView alloc] initWithFrame:CGRectZero];
        host.tag = kMMGlassHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = YES;
        host.clipsToBounds = NO;
        [container addSubview:host];
    }
    return host;
}

static UIVisualEffectView *MMEnsureGlassView(UIView *host) {
    UIVisualEffectView *glass = (UIVisualEffectView *)[host viewWithTag:kMMGlassViewTag];
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        glass.tag = kMMGlassViewTag;
        glass.userInteractionEnabled = NO;
        [host addSubview:glass];
    }
    glass.frame = host.bounds;
    glass.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.06) : MMRGBA(255, 255, 255, 0.14);
    MMSetContinuousRadius(glass, host.bounds.size.height / 2.0);
    glass.layer.masksToBounds = YES;
    return glass;
}

static UIView *MMEnsureButtonsContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMButtonsContainerTag];
    if (!container) {
        container = [[UIView alloc] initWithFrame:CGRectZero];
        container.tag = kMMButtonsContainerTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = YES;
        container.clipsToBounds = NO;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    return container;
}

static UIView *MMEnsureCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMCapsuleTag];
    if (!capsule) {
        capsule = [[UIView alloc] initWithFrame:CGRectZero];
        capsule.tag = kMMCapsuleTag;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.userInteractionEnabled = NO;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    if (!border) {
        border = [[UIView alloc] initWithFrame:CGRectZero];
        border.tag = kMMCapsuleBorderTag;
        border.backgroundColor = [UIColor clearColor];
        border.userInteractionEnabled = NO;
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    if (!glow) {
        glow = [[UIView alloc] initWithFrame:CGRectZero];
        glow.tag = kMMCapsuleGlowTag;
        glow.backgroundColor = [UIColor clearColor];
        glow.userInteractionEnabled = NO;
        [capsule addSubview:glow];
    }

    return capsule;
}

static void MMStyleHost(UIView *host) {
    MMSetContinuousRadius(host, host.bounds.size.height / 2.0);
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

static void MMApplyCapsuleFrame(UIView *host, NSInteger selectedIndex, NSInteger count) {
    if (count <= 0) return;

    UIView *capsule = MMEnsureCapsule(host);

    CGFloat outerSide = 8.0;
    CGFloat outerTop = 7.0;
    CGFloat slotW = floor((host.bounds.size.width - outerSide * 2.0) / count);
    CGFloat slotH = host.bounds.size.height - outerTop * 2.0;

    CGRect frame = CGRectMake(outerSide + slotW * selectedIndex + 2.0, outerTop, slotW - 4.0, slotH);
    capsule.frame = frame;
    capsule.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.12) : MMRGBA(255, 255, 255, 0.32);
    capsule.layer.shadowColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.16) : MMRGBA(255, 255, 255, 0.35)).CGColor;
    capsule.layer.shadowOpacity = 1.0;
    capsule.layer.shadowRadius = 12.0;
    capsule.layer.shadowOffset = CGSizeMake(0, 2);
    MMSetContinuousRadius(capsule, frame.size.height / 2.0);

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.7;
    border.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.16) : MMRGBA(255, 255, 255, 0.38)).CGColor;
    MMSetContinuousRadius(border, border.bounds.size.height / 2.0);
    border.layer.masksToBounds = YES;

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    MMSetContinuousRadius(glow, glow.bounds.size.height / 2.0);
    glow.layer.masksToBounds = YES;

    CAGradientLayer *grad = MMFindGradient(glow.layer, @"mm_capsule_glow");
    if (!grad) {
        grad = [CAGradientLayer layer];
        grad.name = @"mm_capsule_glow";
        [glow.layer addSublayer:grad];
    }
    grad.frame = glow.bounds;
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint = CGPointMake(0.5, 1.0);
    grad.colors = @[
        (__bridge id)MMRGBA(255, 255, 255, 0.14).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.05).CGColor,
        (__bridge id)MMRGBA(255, 255, 255, 0.01).CGColor
    ];
}

static void MMSwitchToIndex(UIView *sourceView, NSInteger idx) {
    UIViewController *vc = MMFindParentViewController(sourceView);
    if (!vc) return;

    if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
        @try {
            [(id)vc setSelectedIndex:idx];
            return;
        } @catch (__unused NSException *e) {
        }
    }

    UITabBar *tabBar = MMFindTabBar(vc);
    if (tabBar && idx >= 0 && idx < (NSInteger)tabBar.items.count) {
        @try {
            tabBar.selectedItem = tabBar.items[idx];
        } @catch (__unused NSException *e) {
        }
    }
}

@interface MMFloatingSnapshotButton : UIControl
@property (nonatomic, strong) UIImageView *snapshotView;
@end

@implementation MMFloatingSnapshotButton

- (void)mmHandleTap {
    NSInteger idx = self.tag - 4000;
    MMSwitchToIndex(self, idx);
}

@end

static MMFloatingSnapshotButton *MMMakeSnapshotButton(CGRect frame, UIImage *image, NSInteger idx) {
    MMFloatingSnapshotButton *button = [[MMFloatingSnapshotButton alloc] initWithFrame:frame];
    button.tag = 4000 + idx;
    button.backgroundColor = [UIColor clearColor];

    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectInset(button.bounds, 2.0, 1.0)];
    iv.image = image;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.backgroundColor = [UIColor clearColor];
    [button addSubview:iv];
    button.snapshotView = iv;

    [button addTarget:button action:@selector(mmHandleTap) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static void MMBuildSnapshotButtons(UITabBar *tabBar, UIView *host) {
    UIView *container = MMEnsureButtonsContainer(host);
    for (UIView *sub in [container.subviews copy]) {
        [sub removeFromSuperview];
    }

    NSArray<UIView *> *nativeButtons = MMStoredButtons(tabBar);
    NSInteger count = nativeButtons.count;
    if (count == 0) return;

    NSInteger selected = MMSelectedIndex(tabBar);

    CGFloat side = 8.0;
    CGFloat top = 6.0;
    CGFloat slotW = (container.bounds.size.width - side * 2.0) / count;
    CGFloat slotH = container.bounds.size.height - top * 2.0;

    MMApplyCapsuleFrame(host, selected, count);

    for (NSInteger i = 0; i < count; i++) {
        UIView *native = nativeButtons[i];
        native.hidden = NO;
        native.alpha = 1.0;
        UIImage *snapshot = MMSnapshotView(native);

        CGFloat x = side + slotW * i;
        CGFloat w = (i == count - 1) ? (container.bounds.size.width - side - x) : slotW;
        CGRect frame = CGRectMake(x, top, w, slotH);

        MMFloatingSnapshotButton *btn = MMMakeSnapshotButton(frame, snapshot, i);
        [container addSubview:btn];
    }

    [host bringSubviewToFront:[host viewWithTag:kMMCapsuleTag]];
    [host bringSubviewToFront:container];
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    @try {
        UIView *container = vc.view;
        if (!container) {
            kMMUpdatingLayout = NO;
            return;
        }

        UITabBar *tabBar = MMFindTabBar(vc);
        if (!tabBar) {
            kMMUpdatingLayout = NO;
            return;
        }

        CGFloat bottomInset = MMBottomInset(container);
        CGFloat margin = 16.0;
        CGFloat height = 64.0;
        CGFloat bottomGap = bottomInset > 0 ? 10.0 : 14.0;

        CGRect floatingFrame = CGRectMake(
            margin,
            container.bounds.size.height - bottomInset - bottomGap - height,
            container.bounds.size.width - margin * 2.0,
            height
        );

        UIView *host = MMEnsureGlassHost(container);
        host.frame = floatingFrame;
        MMStyleHost(host);

        UIVisualEffectView *glass = MMEnsureGlassView(host);
        glass.frame = host.bounds;

        MMClearNativeTabBar(tabBar);

        MMBuildSnapshotButtons(tabBar, host);

        tabBar.frame = CGRectMake(0, container.bounds.size.height + 200.0, tabBar.bounds.size.width, tabBar.bounds.size.height);
        tabBar.alpha = 0.01;
        tabBar.hidden = NO;
        tabBar.userInteractionEnabled = NO;

        [container bringSubviewToFront:host];
    } @catch (__unused NSException *e) {
    }

    kMMUpdatingLayout = NO;
}

%hook MMTabBarController

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

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig(previousTraitCollection);
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig(selectedIndex);
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar((UIViewController *)self);
    });
}

%end

%hook UITabBar

- (void)setSelectedItem:(UITabBarItem *)selectedItem {
    %orig(selectedItem);
    UIViewController *vc = MMFindParentViewController(self);
    if (vc) {
        dispatch_async(dispatch_get_main_queue(), ^{
            MMUpdateFloatingBar(vc);
        });
    }
}

%end
