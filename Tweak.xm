#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMGlassHostTag = 910001;
static NSInteger const kMMGlassViewTag = 910002;
static NSInteger const kMMCapsuleTag = 910003;
static NSInteger const kMMButtonsContainerTag = 910004;
static NSInteger const kMMStrokeTag = 910005;
static NSInteger const kMMGlowTag = 910006;

static const void *kMMStoredButtonsKey = &kMMStoredButtonsKey;
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

static NSArray<UIView *> *MMFindTabButtonViewsInView(UIView *view) {
    NSMutableArray *arr = [NSMutableArray array];
    for (UIView *sub in view.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"UITabBarButton"] || [name containsString:@"MMTabBarItemView"]) {
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

static NSArray<UIView *> *MMStoredButtons(UITabBar *tabBar) {
    NSArray *arr = objc_getAssociatedObject(tabBar, kMMStoredButtonsKey);
    if ([arr isKindOfClass:[NSArray class]] && arr.count > 0) {
        return arr;
    }

    NSArray<UIView *> *found = MMFindTabButtonViewsInView(tabBar);
    if (found.count > 0) {
        objc_setAssociatedObject(tabBar, kMMStoredButtonsKey, found, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return found;
    }

    return @[];
}

static NSInteger MMSelectedIndex(UITabBar *tabBar) {
    if (!tabBar || tabBar.items.count == 0) return 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) return idx;
    }
    return 0;
}

static UITabBar *MMFindTabBar(UIViewController *vc) {
    @try {
        id tb = [vc valueForKey:@"tabBar"];
        if ([tb isKindOfClass:[UITabBar class]]) return (UITabBar *)tb;
    } @catch (__unused NSException *e) {}

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
    glass.backgroundColor = MMRGBA(255, 255, 255, MMIsDark(host.traitCollection) ? 0.06 : 0.10);
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
        capsule.userInteractionEnabled = NO;
        [host addSubview:capsule];
    }

    capsule.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.14) : MMRGBA(255,255,255,0.30);
    capsule.layer.shadowColor = MMRGBA(255,255,255,0.22).CGColor;
    capsule.layer.shadowOpacity = 1.0;
    capsule.layer.shadowRadius = 14.0;
    capsule.layer.shadowOffset = CGSizeMake(0, 3);

    UIView *stroke = [capsule viewWithTag:kMMStrokeTag];
    if (!stroke) {
        stroke = [[UIView alloc] initWithFrame:CGRectZero];
        stroke.tag = kMMStrokeTag;
        stroke.userInteractionEnabled = NO;
        [capsule addSubview:stroke];
    }
    stroke.frame = capsule.bounds;
    stroke.backgroundColor = [UIColor clearColor];
    stroke.layer.borderWidth = 0.7;
    stroke.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.18) : MMRGBA(255,255,255,0.42)).CGColor;
    MMSetContinuousRadius(stroke, capsule.bounds.size.height / 2.0);

    UIView *glow = [capsule viewWithTag:kMMGlowTag];
    if (!glow) {
        glow = [[UIView alloc] initWithFrame:CGRectZero];
        glow.tag = kMMGlowTag;
        glow.userInteractionEnabled = NO;
        [capsule addSubview:glow];
    }
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    MMSetContinuousRadius(glow, glow.bounds.size.height / 2.0);

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
        (__bridge id)MMRGBA(255,255,255,0.16).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.05).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.01).CGColor
    ];

    MMSetContinuousRadius(capsule, capsule.bounds.size.height / 2.0);
    return capsule;
}

static void MMStyleHost(UIView *host) {
    MMSetContinuousRadius(host, host.bounds.size.height / 2.0);
    host.layer.borderWidth = 0.6;
    host.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.16) : MMRGBA(255,255,255,0.30)).CGColor;
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
        (__bridge id)MMRGBA(255,255,255,0.20).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.08).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.00).CGColor
    ];
}

static void MMApplyButtonTint(UIView *button, BOOL selected) {
    UIColor *selectedColor = MMRGBA(255,255,255,1.0);
    UIColor *normalColor = MMRGBA(255,255,255,0.72);
    UIColor *color = selected ? selectedColor : normalColor;

    for (UIView *sub in button.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            iv.tintColor = color;
            if (iv.image) {
                iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            iv.alpha = selected ? 1.0 : 0.92;
            iv.transform = selected ? CGAffineTransformMakeScale(1.04, 1.04) : CGAffineTransformIdentity;
        } else if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lab = (UILabel *)sub;
            lab.textColor = color;
            lab.alpha = selected ? 1.0 : 0.92;
        }
    }
}

static void MMDetachAndMoveButtonsToHost(UITabBar *tabBar, UIView *host) {
    UIView *buttonsContainer = MMEnsureButtonsContainer(host);
    NSArray<UIView *> *buttons = MMStoredButtons(tabBar);
    if (buttons.count == 0) return;

    NSInteger count = buttons.count;
    CGFloat sidePadding = 6.0;
    CGFloat topPadding = 6.0;
    CGFloat itemW = (buttonsContainer.bounds.size.width - sidePadding * 2.0) / count;
    CGFloat itemH = buttonsContainer.bounds.size.height - topPadding * 2.0;

    NSInteger selected = MMSelectedIndex(tabBar);
    UIView *capsule = MMEnsureCapsule(host);
    CGRect capsuleFrame = CGRectMake(sidePadding + itemW * selected, topPadding, itemW, itemH);
    capsuleFrame = CGRectInset(capsuleFrame, 2.0, 0.0);

    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
        capsule.frame = capsuleFrame;
        MMSetContinuousRadius(capsule, capsule.bounds.size.height / 2.0);

        UIView *stroke = [capsule viewWithTag:kMMStrokeTag];
        if (stroke) {
            stroke.frame = capsule.bounds;
            MMSetContinuousRadius(stroke, stroke.bounds.size.height / 2.0);
        }

        UIView *glow = [capsule viewWithTag:kMMGlowTag];
        if (glow) {
            glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
            MMSetContinuousRadius(glow, glow.bounds.size.height / 2.0);
            CAGradientLayer *grad = MMFindGradient(glow.layer, @"capsuleGlow");
            if (grad) grad.frame = glow.bounds;
        }
    } completion:nil];

    for (NSInteger i = 0; i < count; i++) {
        UIView *btn = buttons[i];
        if (btn.superview != buttonsContainer) {
            [btn removeFromSuperview];
            [buttonsContainer addSubview:btn];
        }

        CGFloat x = sidePadding + i * itemW;
        CGFloat w = (i == count - 1) ? (buttonsContainer.bounds.size.width - sidePadding - x) : itemW;
        btn.frame = CGRectMake(x, topPadding, w, itemH);
        btn.hidden = NO;
        btn.alpha = 1.0;
        btn.userInteractionEnabled = YES;
        btn.backgroundColor = [UIColor clearColor];
        btn.layer.zPosition = 20;
        MMApplyButtonTint(btn, i == selected);
    }

    [host bringSubviewToFront:capsule];
    [host bringSubviewToFront:buttonsContainer];
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

        if (!objc_getAssociatedObject(tabBar, kMMStoredButtonsKey)) {
            NSArray<UIView *> *initialButtons = MMFindTabButtonViewsInView(tabBar);
            if (initialButtons.count > 0) {
                objc_setAssociatedObject(tabBar, kMMStoredButtonsKey, initialButtons, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }

        tabBar.frame = CGRectMake(0, container.bounds.size.height + 200.0, 1.0, 1.0);
        tabBar.alpha = 0.01;
        tabBar.hidden = NO;
        tabBar.userInteractionEnabled = NO;

        MMDetachAndMoveButtonsToHost(tabBar, host);

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
