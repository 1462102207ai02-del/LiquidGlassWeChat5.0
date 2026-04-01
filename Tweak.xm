#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMFloatingHostTag = 520001;
static NSInteger const kMMLiquidGlassTag = 520002;
static NSInteger const kMMHighlightTag = 520003;
static NSInteger const kMMStrokeTag = 520004;
static NSInteger const kMMInnerGlowTag = 520005;

static CGFloat MMGetBottomSafeInset(UIView *view) {
    if (@available(iOS 11.0, *)) {
        return view.safeAreaInsets.bottom;
    }
    return 0.0;
}

static UIColor *MMColorRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static UIColor *MMGlassBorderColor(UITraitCollection *trait) {
    if (@available(iOS 13.0, *)) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:1.0 alpha:0.18];
        }
    }
    return [UIColor colorWithWhite:1.0 alpha:0.34];
}

static UIColor *MMGlassShadowColor(UITraitCollection *trait) {
    if (@available(iOS 13.0, *)) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithWhite:0.0 alpha:0.34];
        }
    }
    return [UIColor colorWithWhite:0.0 alpha:0.16];
}

static UIColor *MMCapsuleFillColor(UITraitCollection *trait) {
    if (@available(iOS 13.0, *)) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return MMColorRGBA(255, 255, 255, 0.14);
        }
    }
    return MMColorRGBA(255, 255, 255, 0.30);
}

static UIColor *MMCapsuleStrokeColor(UITraitCollection *trait) {
    if (@available(iOS 13.0, *)) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return MMColorRGBA(255, 255, 255, 0.16);
        }
    }
    return MMColorRGBA(255, 255, 255, 0.42);
}

static UIColor *MMCapsuleGlowColor(UITraitCollection *trait) {
    if (@available(iOS 13.0, *)) {
        if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return MMColorRGBA(255, 255, 255, 0.10);
        }
    }
    return MMColorRGBA(255, 255, 255, 0.20);
}

static UIVisualEffect *MMCreateBlurEffect(void) {
    if (@available(iOS 15.0, *)) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    } else if (@available(iOS 13.0, *)) {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
    } else {
        return [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
}

static NSArray<UIView *> *MMGetTabButtons(UITabBar *tabBar) {
    NSMutableArray *buttons = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"UITabBarButton"] || [name containsString:@"MMTabBarItemView"]) {
            [buttons addObject:sub];
        }
    }
    [buttons sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return buttons;
}

static NSInteger MMGetSelectedIndex(UITabBar *tabBar) {
    if (!tabBar || tabBar.items.count == 0 || !tabBar.selectedItem) return NSNotFound;
    NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
    if (idx == NSNotFound) {
        idx = tabBar.selectedItem.tag;
        if (idx < 0 || idx >= (NSInteger)tabBar.items.count) idx = 0;
    }
    return idx;
}

static void MMSetContinuousCornerRadius(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = NO;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static CAGradientLayer *MMFindGradientLayer(UIView *view, NSString *name) {
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]] && [layer.name isEqualToString:name]) {
            return (CAGradientLayer *)layer;
        }
    }
    return nil;
}

static void MMApplyIconTitleTint(UIView *button, BOOL selected) {
    UIColor *selectedColor = MMColorRGBA(255, 255, 255, 1.0);
    UIColor *normalColor = MMColorRGBA(255, 255, 255, 0.72);
    UIColor *tint = selected ? selectedColor : normalColor;
    for (UIView *sub in button.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            iv.tintColor = tint;
            iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            iv.alpha = selected ? 1.0 : 0.92;
            iv.transform = selected ? CGAffineTransformMakeScale(1.04, 1.04) : CGAffineTransformIdentity;
        } else if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lab = (UILabel *)sub;
            lab.textColor = tint;
            lab.alpha = selected ? 1.0 : 0.92;
        }
    }
}

static void MMStyleHost(UIView *host, UITraitCollection *trait) {
    MMSetContinuousCornerRadius(host, host.bounds.size.height / 2.0);
    host.backgroundColor = [UIColor clearColor];
    host.layer.shadowColor = MMGlassShadowColor(trait).CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 24.0;
    host.layer.shadowOffset = CGSizeMake(0, 10);

    host.layer.borderWidth = 0.6;
    host.layer.borderColor = MMGlassBorderColor(trait).CGColor;

    CAGradientLayer *topGloss = MMFindGradientLayer(host, @"mm_top_gloss");
    if (!topGloss) {
        topGloss = [CAGradientLayer layer];
        topGloss.name = @"mm_top_gloss";
        [host.layer insertSublayer:topGloss atIndex:0];
    }
    topGloss.frame = CGRectMake(0, 0, host.bounds.size.width, host.bounds.size.height * 0.55);
    topGloss.startPoint = CGPointMake(0.5, 0.0);
    topGloss.endPoint = CGPointMake(0.5, 1.0);
    topGloss.colors = @[
        (__bridge id)MMColorRGBA(255, 255, 255, 0.22).CGColor,
        (__bridge id)MMColorRGBA(255, 255, 255, 0.08).CGColor,
        (__bridge id)MMColorRGBA(255, 255, 255, 0.00).CGColor
    ];

    CAGradientLayer *edgeShine = MMFindGradientLayer(host, @"mm_edge_shine");
    if (!edgeShine) {
        edgeShine = [CAGradientLayer layer];
        edgeShine.name = @"mm_edge_shine";
        [host.layer addSublayer:edgeShine];
    }
    edgeShine.frame = host.bounds;
    edgeShine.startPoint = CGPointMake(0.0, 0.0);
    edgeShine.endPoint = CGPointMake(1.0, 1.0);
    edgeShine.colors = @[
        (__bridge id)MMColorRGBA(255, 255, 255, 0.12).CGColor,
        (__bridge id)MMColorRGBA(255, 255, 255, 0.03).CGColor,
        (__bridge id)MMColorRGBA(255, 255, 255, 0.10).CGColor
    ];
    edgeShine.locations = @[@0.0, @0.55, @1.0];
}

static UIView *MMEnsureFloatingHost(UIView *container) {
    UIView *host = [container viewWithTag:kMMFloatingHostTag];
    if (!host) {
        host = [[UIView alloc] initWithFrame:CGRectZero];
        host.tag = kMMFloatingHostTag;
        host.userInteractionEnabled = YES;
        host.clipsToBounds = NO;
        [container addSubview:host];
    }
    return host;
}

static UIVisualEffectView *MMEnsureGlassView(UIView *host) {
    UIVisualEffectView *glass = [host viewWithTag:kMMLiquidGlassTag];
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:MMCreateBlurEffect()];
        glass.tag = kMMLiquidGlassTag;
        glass.userInteractionEnabled = NO;
        glass.backgroundColor = MMColorRGBA(255, 255, 255, 0.05);
        [host addSubview:glass];
    }
    glass.frame = host.bounds;
    MMSetContinuousCornerRadius(glass, host.bounds.size.height / 2.0);
    glass.layer.masksToBounds = YES;
    return glass;
}

static UIView *MMEnsureCapsule(UIView *host, UITraitCollection *trait) {
    UIView *capsule = [host viewWithTag:kMMHighlightTag];
    if (!capsule) {
        capsule = [[UIView alloc] initWithFrame:CGRectZero];
        capsule.tag = kMMHighlightTag;
        capsule.userInteractionEnabled = NO;
        [host addSubview:capsule];
    }

    capsule.backgroundColor = MMCapsuleFillColor(trait);
    MMSetContinuousCornerRadius(capsule, capsule.bounds.size.height / 2.0);
    capsule.layer.shadowColor = MMCapsuleGlowColor(trait).CGColor;
    capsule.layer.shadowOpacity = 1.0;
    capsule.layer.shadowRadius = 16.0;
    capsule.layer.shadowOffset = CGSizeMake(0, 4);

    CALayer *stroke = [capsule layer].sublayers.count > 0 ? nil : nil;
    UIView *strokeView = [capsule viewWithTag:kMMStrokeTag];
    if (!strokeView) {
        strokeView = [[UIView alloc] initWithFrame:CGRectZero];
        strokeView.tag = kMMStrokeTag;
        strokeView.userInteractionEnabled = NO;
        [capsule addSubview:strokeView];
    }
    strokeView.frame = capsule.bounds;
    strokeView.backgroundColor = [UIColor clearColor];
    MMSetContinuousCornerRadius(strokeView, capsule.bounds.size.height / 2.0);
    strokeView.layer.borderWidth = 0.75;
    strokeView.layer.borderColor = MMCapsuleStrokeColor(trait).CGColor;

    UIView *glowView = [capsule viewWithTag:kMMInnerGlowTag];
    if (!glowView) {
        glowView = [[UIView alloc] initWithFrame:CGRectZero];
        glowView.tag = kMMInnerGlowTag;
        glowView.userInteractionEnabled = NO;
        [capsule addSubview:glowView];
    }
    glowView.frame = CGRectInset(capsule.bounds, 1.2, 1.2);
    glowView.backgroundColor = [UIColor clearColor];
    MMSetContinuousCornerRadius(glowView, glowView.bounds.size.height / 2.0);

    CAGradientLayer *grad = MMFindGradientLayer(glowView, @"mm_capsule_glow");
    if (!grad) {
        grad = [CAGradientLayer layer];
        grad.name = @"mm_capsule_glow";
        [glowView.layer addSublayer:grad];
    }
    grad.frame = glowView.bounds;
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint = CGPointMake(0.5, 1.0);
    grad.colors = @[
        (__bridge id)MMColorRGBA(255, 255, 255, 0.18).CGColor,
        (__bridge id)MMColorRGBA(255, 255, 255, 0.05).CGColor,
        (__bridge id)MMColorRGBA(255, 255, 255, 0.02).CGColor
    ];

    return capsule;
}

static void MMHideTabBarBackground(UITabBar *tabBar) {
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.translucent = YES;

    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];
        tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            tabBar.scrollEdgeAppearance = appearance;
        }
    }

    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"Background"] || [name containsString:@"ShadowView"] || [name containsString:@"BarBackground"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
    }
}

static void MMRelayoutTabBar(UITabBar *tabBar, UIView *host) {
    NSArray<UIView *> *buttons = MMGetTabButtons(tabBar);
    NSInteger count = buttons.count;
    if (count == 0) return;

    CGFloat hostW = host.bounds.size.width;
    CGFloat hostH = host.bounds.size.height;
    CGFloat sidePadding = 10.0;
    CGFloat topPadding = 8.0;
    CGFloat bottomPadding = 8.0;
    CGFloat availableW = hostW - sidePadding * 2.0;
    CGFloat itemW = floor(availableW / count);
    CGFloat itemH = hostH - topPadding - bottomPadding;

    for (NSInteger i = 0; i < count; i++) {
        UIView *btn = buttons[i];
        CGFloat x = sidePadding + i * itemW;
        CGFloat w = (i == count - 1) ? (hostW - sidePadding - x) : itemW;
        btn.frame = CGRectMake(x, topPadding, w, itemH);
        btn.layer.zPosition = 10;
        btn.backgroundColor = [UIColor clearColor];
    }

    NSInteger selectedIndex = MMGetSelectedIndex(tabBar);
    if (selectedIndex == NSNotFound || selectedIndex >= count) selectedIndex = 0;

    UIView *selectedButton = buttons[selectedIndex];
    UIView *capsule = MMEnsureCapsule(host, host.traitCollection);
    CGFloat capsuleInsetX = 4.0;
    CGFloat capsuleInsetY = 4.0;
    CGRect target = CGRectInset(selectedButton.frame, capsuleInsetX, capsuleInsetY);
    capsule.frame = target;
    MMSetContinuousCornerRadius(capsule, capsule.bounds.size.height / 2.0);

    UIView *strokeView = [capsule viewWithTag:kMMStrokeTag];
    if (strokeView) {
        strokeView.frame = capsule.bounds;
        MMSetContinuousCornerRadius(strokeView, strokeView.bounds.size.height / 2.0);
    }

    UIView *glowView = [capsule viewWithTag:kMMInnerGlowTag];
    if (glowView) {
        glowView.frame = CGRectInset(capsule.bounds, 1.2, 1.2);
        MMSetContinuousCornerRadius(glowView, glowView.bounds.size.height / 2.0);
        CAGradientLayer *grad = MMFindGradientLayer(glowView, @"mm_capsule_glow");
        if (grad) grad.frame = glowView.bounds;
    }

    [host bringSubviewToFront:capsule];
    for (UIView *btn in buttons) {
        [host bringSubviewToFront:btn];
    }

    for (NSInteger i = 0; i < count; i++) {
        MMApplyIconTitleTint(buttons[i], i == selectedIndex);
    }
}

static UITabBar *MMFindTabBarInContainer(UIViewController *controller, UIView *container) {
    UITabBar *found = nil;

    if ([controller respondsToSelector:@selector(tabBar)]) {
        @try {
            id tb = [controller valueForKey:@"tabBar"];
            if ([tb isKindOfClass:[UITabBar class]]) {
                found = (UITabBar *)tb;
            }
        } @catch (__unused NSException *e) {}
    }

    if (!found) {
        for (UIView *sub in container.subviews) {
            NSString *name = NSStringFromClass([sub class]);
            if ([sub isKindOfClass:[UITabBar class]] || [name containsString:@"MMTabBar"]) {
                found = (UITabBar *)sub;
                break;
            }
        }
    }

    return found;
}

static void MMUpdateFloatingTabBar(UIViewController *controller) {
    UIView *container = controller.view;
    if (!container) return;

    UITabBar *tabBar = MMFindTabBarInContainer(controller, container);
    if (!tabBar) return;

    MMHideTabBarBackground(tabBar);

    UIView *host = MMEnsureFloatingHost(container);

    CGFloat bottomInset = MMGetBottomSafeInset(container);
    CGFloat horizontalMargin = 16.0;
    CGFloat height = 64.0;
    CGFloat bottomGap = bottomInset > 0.0 ? 10.0 : 14.0;
    CGFloat width = container.bounds.size.width - horizontalMargin * 2.0;
    CGFloat y = container.bounds.size.height - bottomInset - bottomGap - height;

    host.frame = CGRectMake(horizontalMargin, y, width, height);
    MMStyleHost(host, host.traitCollection);

    UIVisualEffectView *glass = MMEnsureGlassView(host);
    glass.frame = host.bounds;
    glass.backgroundColor = MMColorRGBA(255, 255, 255, 0.05);

    if (tabBar.superview != host) {
        [tabBar removeFromSuperview];
        [host addSubview:tabBar];
    }

    tabBar.frame = host.bounds;
    tabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tabBar.hidden = NO;
    tabBar.alpha = 1.0;
    tabBar.clipsToBounds = NO;
    tabBar.layer.zPosition = 8;

    MMRelayoutTabBar(tabBar, host);
}

%hook MMTabBarController

- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingTabBar(self);
    });
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdateFloatingTabBar(self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMUpdateFloatingTabBar(self);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig(previousTraitCollection);
    MMUpdateFloatingTabBar(self);
}

%end

%hook UITabBar

- (void)layoutSubviews {
    %orig;
    UIView *superview = self.superview;
    if (superview && superview.tag == kMMFloatingHostTag) {
        MMHideTabBarBackground(self);
        MMRelayoutTabBar(self, superview);
    }
}

- (void)setSelectedItem:(UITabBarItem *)selectedItem {
    %orig(selectedItem);
    UIView *superview = self.superview;
    if (superview && superview.tag == kMMFloatingHostTag) {
        [UIView animateWithDuration:0.28 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            MMRelayoutTabBar(self, superview);
        } completion:nil];
    }
}

%end
