#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMGlassHostTag = 710001;
static NSInteger const kMMGlassViewTag = 710002;
static NSInteger const kMMCapsuleTag = 710003;
static NSInteger const kMMButtonsContainerTag = 710004;
static NSInteger const kMMStrokeTag = 710005;
static NSInteger const kMMGlowTag = 710006;

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

static NSArray<UIView *> *MMTabButtons(UITabBar *tabBar) {
    NSMutableArray *arr = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
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

static UIImage *MMTemplateImageFromButtonView(UIView *buttonView) {
    for (UIView *sub in buttonView.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image) {
                return [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
        }
    }
    return nil;
}

static NSString *MMTitleFromButtonView(UIView *buttonView, NSInteger idx, UITabBar *tabBar) {
    for (UIView *sub in buttonView.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lab = (UILabel *)sub;
            if (lab.text.length > 0) return lab.text;
        }
    }
    if (idx < tabBar.items.count) {
        UITabBarItem *item = tabBar.items[idx];
        if (item.title.length > 0) return item.title;
    }
    return @"";
}

static void MMClearNativeTabBar(UITabBar *tabBar) {
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.translucent = YES;

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

static void MMHideNativeTabButtons(UITabBar *tabBar) {
    NSArray<UIView *> *buttons = MMTabButtons(tabBar);
    for (UIView *btn in buttons) {
        btn.hidden = YES;
        btn.alpha = 0.0;
        btn.userInteractionEnabled = NO;
    }
    tabBar.tintColor = [UIColor clearColor];
    tabBar.unselectedItemTintColor = [UIColor clearColor];
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

static UIButton *MMBuildMirrorButton(CGRect frame, UIImage *image, NSString *title, BOOL selected, NSInteger idx) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    button.tag = idx + 1000;
    button.backgroundColor = [UIColor clearColor];
    button.adjustsImageWhenHighlighted = NO;

    UIColor *selColor = MMRGBA(255,255,255,1.0);
    UIColor *norColor = MMRGBA(255,255,255,0.72);
    UIColor *color = selected ? selColor : norColor;

    [button setImage:image forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.tintColor = color;

    button.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:selected ? UIFontWeightSemibold : UIFontWeightRegular];
    button.titleLabel.textAlignment = NSTextAlignmentCenter;

    CGFloat w = frame.size.width;
    CGFloat h = frame.size.height;
    CGFloat imageSize = 24.0;
    CGFloat titleH = 14.0;
    CGFloat imageTop = 7.0;
    CGFloat spacing = 3.0;
    CGFloat totalH = imageSize + spacing + titleH;
    CGFloat contentTop = (h - totalH) * 0.5 - 1.0;

    button.imageEdgeInsets = UIEdgeInsetsMake(contentTop, (w - imageSize) * 0.5 - imageSize * 0.5, h - contentTop - imageSize, 0);
    button.titleEdgeInsets = UIEdgeInsetsMake(contentTop + imageSize + spacing, -imageSize, h - (contentTop + imageSize + spacing + titleH), 0);

    if (selected) {
        button.transform = CGAffineTransformMakeScale(1.02, 1.02);
    }

    return button;
}

static void MMSwitchToIndex(UIView *sourceView, NSInteger idx) {
    UIViewController *vc = MMFindParentViewController(sourceView);
    if (!vc) return;

    if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
        @try {
            [(id)vc setSelectedIndex:idx];
        } @catch (__unused NSException *e) {}
    }

    UITabBar *tabBar = MMFindTabBar(vc);
    if (tabBar && idx < tabBar.items.count) {
        UITabBarItem *item = tabBar.items[idx];
        if (item) {
            tabBar.selectedItem = item;
        }
    }
}

%subclass MMMirrorTabButton : UIButton

- (void)mmTap {
    NSInteger idx = self.tag - 1000;
    MMSwitchToIndex(self, idx);
}

%end

static UIButton *MMMakeMirrorButton(CGRect frame, UIImage *image, NSString *title, BOOL selected, NSInteger idx) {
    MMMirrorTabButton *button = [MMMirrorTabButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    button.tag = idx + 1000;
    button.backgroundColor = [UIColor clearColor];
    button.adjustsImageWhenHighlighted = NO;

    UIColor *selColor = MMRGBA(255,255,255,1.0);
    UIColor *norColor = MMRGBA(255,255,255,0.72);
    UIColor *color = selected ? selColor : norColor;

    [button setImage:image forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:color forState:UIControlStateNormal];
    button.tintColor = color;

    button.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:selected ? UIFontWeightSemibold : UIFontWeightRegular];
    button.titleLabel.textAlignment = NSTextAlignmentCenter;

    CGFloat w = frame.size.width;
    CGFloat h = frame.size.height;
    CGFloat imageSize = 24.0;
    CGFloat titleH = 14.0;
    CGFloat imageTop = 7.0;
    CGFloat spacing = 3.0;
    CGFloat totalH = imageSize + spacing + titleH;
    CGFloat contentTop = (h - totalH) * 0.5 - 1.0;

    button.imageEdgeInsets = UIEdgeInsetsMake(contentTop, (w - imageSize) * 0.5 - imageSize * 0.5, h - contentTop - imageSize, 0);
    button.titleEdgeInsets = UIEdgeInsetsMake(contentTop + imageSize + spacing, -imageSize, h - (contentTop + imageSize + spacing + titleH), 0);

    if (selected) {
        button.transform = CGAffineTransformMakeScale(1.02, 1.02);
    }

    [button addTarget:button action:@selector(mmTap) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static void MMRebuildMirrorButtons(UITabBar *tabBar, UIView *host) {
    UIView *buttonsContainer = MMEnsureButtonsContainer(host);
    for (UIView *sub in [buttonsContainer.subviews copy]) {
        [sub removeFromSuperview];
    }

    NSArray<UIView *> *nativeButtons = MMTabButtons(tabBar);
    NSInteger count = nativeButtons.count;
    if (count == 0 && tabBar.items.count > 0) count = tabBar.items.count;
    if (count == 0) return;

    NSInteger selected = MMSelectedIndex(tabBar);
    CGFloat sidePadding = 6.0;
    CGFloat topPadding = 6.0;
    CGFloat itemW = (host.bounds.size.width - sidePadding * 2.0) / count;
    CGFloat itemH = host.bounds.size.height - topPadding * 2.0;

    UIView *capsule = MMEnsureCapsule(host);
    CGRect capsuleFrame = CGRectMake(sidePadding + itemW * selected, topPadding, itemW, itemH);
    capsuleFrame = CGRectInset(capsuleFrame, 2.0, 0.0);

    [UIView animateWithDuration:0.26 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        capsule.frame = capsuleFrame;
        MMSetContinuousRadius(capsule, capsule.bounds.size.height / 2.0);

        UIView *stroke = [capsule viewWithTag:kMMStrokeTag];
        if (stroke) {
            stroke.frame = capsule.bounds;
            MMSetContinuousRadius(stroke, capsule.bounds.size.height / 2.0);
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
        UIView *nativeButton = i < nativeButtons.count ? nativeButtons[i] : nil;
        UIImage *img = nativeButton ? MMTemplateImageFromButtonView(nativeButton) : nil;
        NSString *title = MMTitleFromButtonView(nativeButton, i, tabBar);
        CGRect f = CGRectMake(sidePadding + i * itemW, topPadding, itemW, itemH);
        UIButton *mirror = MMMakeMirrorButton(f, img, title, i == selected, i);
        [buttonsContainer addSubview:mirror];
    }

    [host bringSubviewToFront:capsule];
    [host bringSubviewToFront:buttonsContainer];
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    UIView *container = vc.view;
    if (!container) return;

    UITabBar *tabBar = MMFindTabBar(vc);
    if (!tabBar) return;

    MMClearNativeTabBar(tabBar);
    MMHideNativeTabButtons(tabBar);

    CGFloat bottomInset = MMBottomInset(container);
    CGFloat margin = 16.0;
    CGFloat height = 64.0;
    CGFloat bottomGap = bottomInset > 0 ? 10.0 : 14.0;

    CGRect frame = CGRectMake(
        margin,
        container.bounds.size.height - bottomInset - bottomGap - height,
        container.bounds.size.width - margin * 2.0,
        height
    );

    UIView *host = MMEnsureGlassHost(container);
    host.frame = frame;
    MMStyleHost(host);

    UIVisualEffectView *glass = MMEnsureGlassView(host);
    glass.frame = host.bounds;

    tabBar.frame = CGRectMake(0, container.bounds.size.height + 200.0, 1.0, 1.0);
    tabBar.alpha = 0.01;
    tabBar.hidden = NO;

    MMRebuildMirrorButtons(tabBar, host);

    [container bringSubviewToFront:host];
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
