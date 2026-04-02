#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMGlassHostTag = 920001;
static NSInteger const kMMGlassViewTag = 920002;
static NSInteger const kMMButtonsContainerTag = 920003;
static NSInteger const kMMCapsuleTag = 920004;
static NSInteger const kMMCapsuleBorderTag = 920005;
static NSInteger const kMMCapsuleGlowTag = 920006;

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

static UIColor *MMSelectedTextColor(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMRGBA(255, 255, 255, 1.0) : MMRGBA(28, 28, 30, 0.96);
}

static UIColor *MMNormalTextColor(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMRGBA(255, 255, 255, 0.72) : MMRGBA(60, 60, 67, 0.72);
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

static UIImageView *MMFindImageViewRecursive(UIView *view) {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        if (iv.image) return iv;
    }
    for (UIView *sub in view.subviews) {
        UIImageView *found = MMFindImageViewRecursive(sub);
        if (found) return found;
    }
    return nil;
}

static UILabel *MMFindLabelRecursive(UIView *view) {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lab = (UILabel *)view;
        if (lab.text.length > 0) return lab;
    }
    for (UIView *sub in view.subviews) {
        UILabel *found = MMFindLabelRecursive(sub);
        if (found) return found;
    }
    return nil;
}

static UIImage *MMNativeImageForIndex(UITabBar *tabBar, NSInteger idx, BOOL selected) {
    NSArray<UIView *> *buttons = MMNativeTabButtons(tabBar);
    if (idx >= 0 && idx < (NSInteger)buttons.count) {
        UIImageView *iv = MMFindImageViewRecursive(buttons[idx]);
        if (iv.image) {
            return [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    }

    if (idx >= 0 && idx < (NSInteger)tabBar.items.count) {
        UITabBarItem *item = tabBar.items[idx];
        UIImage *img = selected ? (item.selectedImage ?: item.image) : (item.image ?: item.selectedImage);
        if (img) return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    return nil;
}

static NSString *MMNativeTitleForIndex(UITabBar *tabBar, NSInteger idx) {
    NSArray<UIView *> *buttons = MMNativeTabButtons(tabBar);
    if (idx >= 0 && idx < (NSInteger)buttons.count) {
        UILabel *lab = MMFindLabelRecursive(buttons[idx]);
        if (lab.text.length > 0) return lab.text;
    }

    if (idx >= 0 && idx < (NSInteger)tabBar.items.count) {
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
        } else if ([name containsString:@"UITabBarButton"] || [name containsString:@"MMTabBarItemView"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.userInteractionEnabled = NO;
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
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.clipsToBounds = NO;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    if (!border) {
        border = [[UIView alloc] initWithFrame:CGRectZero];
        border.tag = kMMCapsuleBorderTag;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    if (!glow) {
        glow = [[UIView alloc] initWithFrame:CGRectZero];
        glow.tag = kMMCapsuleGlowTag;
        glow.userInteractionEnabled = NO;
        glow.backgroundColor = [UIColor clearColor];
        [capsule addSubview:glow];
    }

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

static void MMApplyCapsuleFrame(UIView *host, NSInteger selectedIndex, NSInteger count) {
    if (count <= 0) return;

    UIView *capsule = MMEnsureCapsule(host);

    CGFloat outerSide = 8.0;
    CGFloat outerTop = 7.0;
    CGFloat slotW = floor((host.bounds.size.width - outerSide * 2.0) / count);
    CGFloat slotH = host.bounds.size.height - outerTop * 2.0;

    CGRect frame = CGRectMake(outerSide + slotW * selectedIndex + 2.0, outerTop, slotW - 4.0, slotH);
    capsule.frame = frame;
    capsule.backgroundColor = MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.12) : MMRGBA(255,255,255,0.32);
    capsule.layer.shadowColor = MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.16).CGColor : MMRGBA(255,255,255,0.35).CGColor;
    capsule.layer.shadowOpacity = 1.0;
    capsule.layer.shadowRadius = 12.0;
    capsule.layer.shadowOffset = CGSizeMake(0, 2);
    MMSetContinuousRadius(capsule, frame.size.height / 2.0);

    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.backgroundColor = [UIColor clearColor];
    border.layer.borderWidth = 0.7;
    border.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255,255,255,0.16) : MMRGBA(255,255,255,0.38)).CGColor;
    MMSetContinuousRadius(border, border.bounds.size.height / 2.0);
    border.layer.masksToBounds = YES;

    UIView *glow = [capsule viewWithTag:kMMCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    glow.backgroundColor = [UIColor clearColor];
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
        (__bridge id)MMRGBA(255,255,255,0.14).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.05).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.01).CGColor
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

@interface MMFloatingTabButton : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation MMFloatingTabButton

- (void)mmHandleTap {
    NSInteger idx = self.tag - 3000;
    MMSwitchToIndex(self, idx);
}

@end

static MMFloatingTabButton *MMMakeTabButton(CGRect frame, UIImage *image, NSString *title, UIColor *color, NSInteger idx) {
    MMFloatingTabButton *button = [[MMFloatingTabButton alloc] initWithFrame:frame];
    button.tag = 3000 + idx;
    button.backgroundColor = [UIColor clearColor];
    button.opaque = NO;

    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
    iconView.image = image;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = color;
    iconView.backgroundColor = [UIColor clearColor];
    [button addSubview:iconView];
    button.iconView = iconView;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    titleLabel.text = title ?: @"";
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightMedium];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.75;
    titleLabel.textColor = color;
    titleLabel.backgroundColor = [UIColor clearColor];
    [button addSubview:titleLabel];
    button.titleLabel = titleLabel;

    CGFloat bw = frame.size.width;
    CGFloat bh = frame.size.height;
    BOOL hasIcon = (image != nil);
    BOOL hasTitle = (title.length > 0);

    CGFloat iconSize = hasIcon ? 23.0 : 0.0;
    CGFloat titleH = hasTitle ? 12.0 : 0.0;
    CGFloat spacing = (hasIcon && hasTitle) ? 2.0 : 0.0;
    CGFloat totalH = iconSize + spacing + titleH;
    CGFloat startY = floor((bh - totalH) * 0.5) - (hasIcon && hasTitle ? 1.0 : 0.0);
    if (startY < 4.0) startY = 4.0;

    if (hasIcon) {
        iconView.frame = CGRectMake(floor((bw - iconSize) * 0.5), startY, iconSize, iconSize);
    } else {
        iconView.hidden = YES;
    }

    if (hasTitle) {
        CGFloat titleY = hasIcon ? CGRectGetMaxY(iconView.frame) + spacing : floor((bh - titleH) * 0.5);
        titleLabel.frame = CGRectMake(2.0, titleY, bw - 4.0, titleH);
    } else {
        titleLabel.hidden = YES;
    }

    [button addTarget:button action:@selector(mmHandleTap) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

static void MMBuildFloatingButtons(UITabBar *tabBar, UIView *host) {
    UIView *buttonsContainer = MMEnsureButtonsContainer(host);
    for (UIView *sub in [buttonsContainer.subviews copy]) {
        [sub removeFromSuperview];
    }

    NSInteger count = tabBar.items.count;
    if (count <= 0) count = 4;
    NSInteger selected = MMSelectedIndex(tabBar);
    if (selected < 0) selected = 0;
    if (selected >= count) selected = 0;

    CGFloat outerSide = 8.0;
    CGFloat outerTop = 7.0;
    CGFloat slotW = floor((buttonsContainer.bounds.size.width - outerSide * 2.0) / count);
    CGFloat slotH = buttonsContainer.bounds.size.height - outerTop * 2.0;

    MMApplyCapsuleFrame(host, selected, count);

    for (NSInteger i = 0; i < count; i++) {
        BOOL isSelected = (i == selected);
        UIColor *color = isSelected ? MMSelectedTextColor(host.traitCollection) : MMNormalTextColor(host.traitCollection);

        CGFloat x = outerSide + slotW * i;
        CGFloat w = (i == count - 1) ? (buttonsContainer.bounds.size.width - outerSide - x) : slotW;
        CGRect slotFrame = CGRectMake(x, outerTop, w, slotH);

        UIImage *image = MMNativeImageForIndex(tabBar, i, isSelected);
        NSString *title = MMNativeTitleForIndex(tabBar, i);

        MMFloatingTabButton *button = MMMakeTabButton(slotFrame, image, title, color, i);
        [buttonsContainer addSubview:button];
    }

    [host bringSubviewToFront:[host viewWithTag:kMMCapsuleTag]];
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
        tabBar.frame = CGRectMake(0, container.bounds.size.height + 200.0, 1.0, 1.0);
        tabBar.alpha = 0.01;
        tabBar.hidden = NO;
        tabBar.userInteractionEnabled = NO;

        MMBuildFloatingButtons(tabBar, host);

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
