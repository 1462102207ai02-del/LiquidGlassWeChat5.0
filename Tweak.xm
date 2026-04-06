#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingCapsuleTag = 990203;
static NSInteger const kMMFloatingCapsuleBorderTag = 990204;
static NSInteger const kMMFloatingCapsuleGlowTag = 990205;
static NSInteger const kMMFloatingButtonsTag = 990206;

static BOOL kMMUpdatingLayout = NO;
static BOOL kMMSettingsPresented = NO;

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static CGFloat MMClamp(CGFloat value, CGFloat min, CGFloat max) {
    return value < min ? min : (value > max ? max : value);
}

static CGFloat MMUserFloat(NSString *key, CGFloat fallback) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id obj = [defaults objectForKey:key];
    if (!obj) return fallback;
    return MMClamp([defaults floatForKey:key], 0.0, 1.0);
}

static CGFloat MMBackgroundAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserFloat(@"mm_bg_alpha_dark", 0.05) : MMUserFloat(@"mm_bg_alpha_light", 0.13);
}

static CGFloat MMCapsuleAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserFloat(@"mm_capsule_alpha_dark", 0.10) : MMUserFloat(@"mm_capsule_alpha_light", 0.24);
}

static CGFloat MMGlowTopAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserFloat(@"mm_glow_top_alpha_dark", 0.10) : MMUserFloat(@"mm_glow_top_alpha_light", 0.10);
}

static CGFloat MMGlowMidAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserFloat(@"mm_glow_mid_alpha_dark", 0.03) : MMUserFloat(@"mm_glow_mid_alpha_light", 0.03);
}

static CGFloat MMHostBorderAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserFloat(@"mm_host_border_alpha_dark", 0.12) : MMUserFloat(@"mm_host_border_alpha_light", 0.22);
}

static CGFloat MMCapsuleBorderAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserFloat(@"mm_capsule_border_alpha_dark", 0.12) : MMUserFloat(@"mm_capsule_border_alpha_light", 0.24);
}

static UIColor *MMSelectedColor(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMRGBA(0, 216, 95, 1.0) : MMRGBA(0, 190, 80, 1.0);
}

static UIColor *MMNormalColor(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMRGBA(255, 255, 255, 0.82) : MMRGBA(60, 60, 67, 0.82);
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

static void MMUpdateFloatingBar(UIViewController *vc);

static void MMSaveAlphaValue(NSString *key, CGFloat value) {
    [[NSUserDefaults standardUserDefaults] setFloat:MMClamp(value, 0.0, 1.0) forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void MMShowSettingsAlert(UIViewController *vc) {
    if (!vc || kMMSettingsPresented) return;
    kMMSettingsPresented = YES;

    BOOL dark = MMIsDark(vc.traitCollection);
    NSString *bgKey = dark ? @"mm_bg_alpha_dark" : @"mm_bg_alpha_light";
    NSString *capsuleKey = dark ? @"mm_capsule_alpha_dark" : @"mm_capsule_alpha_light";
    NSString *title = dark ? @"底栏设置（深色模式）" : @"底栏设置（浅色模式）";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:@"输入 0 到 1 之间的小数" preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"背景透明度";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = [NSString stringWithFormat:@"%.2f", MMUserFloat(bgKey, dark ? 0.05 : 0.13)];
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"胶囊透明度";
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = [NSString stringWithFormat:@"%.2f", MMUserFloat(capsuleKey, dark ? 0.10 : 0.24)];
    }];

    __weak UIViewController *weakVC = vc;

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        kMMSettingsPresented = NO;
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        if (dark) {
            MMSaveAlphaValue(@"mm_bg_alpha_dark", 0.05);
            MMSaveAlphaValue(@"mm_capsule_alpha_dark", 0.10);
        } else {
            MMSaveAlphaValue(@"mm_bg_alpha_light", 0.13);
            MMSaveAlphaValue(@"mm_capsule_alpha_light", 0.24);
        }
        kMMSettingsPresented = NO;
        if (weakVC) MMUpdateFloatingBar(weakVC);
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UITextField *bgField = alert.textFields.count > 0 ? alert.textFields[0] : nil;
        UITextField *capsuleField = alert.textFields.count > 1 ? alert.textFields[1] : nil;

        CGFloat bgValue = bgField.text.length ? [bgField.text doubleValue] : (dark ? 0.05 : 0.13);
        CGFloat capsuleValue = capsuleField.text.length ? [capsuleField.text doubleValue] : (dark ? 0.10 : 0.24);

        MMSaveAlphaValue(bgKey, bgValue);
        MMSaveAlphaValue(capsuleKey, capsuleValue);

        kMMSettingsPresented = NO;
        if (weakVC) MMUpdateFloatingBar(weakVC);
    }]];

    [vc presentViewController:alert animated:YES completion:nil];
}

@interface MMGestureProxy : NSObject
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation MMGestureProxy
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIResponder *r = gesture.view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            MMShowSettingsAlert((UIViewController *)r);
            break;
        }
    }
}
@end

static MMGestureProxy *MMSharedGestureProxy(void) {
    static MMGestureProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMGestureProxy new];
    });
    return proxy;
}

static UIView *MMHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMFloatingHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMFloatingHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = YES;
        host.clipsToBounds = NO;
        [root addSubview:host];
    }

    BOOL hasLongPress = NO;
    for (UIGestureRecognizer *g in host.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
            hasLongPress = YES;
            break;
        }
    }
    if (!hasLongPress) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:MMSharedGestureProxy() action:@selector(handleLongPress:)];
        [host addGestureRecognizer:press];
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
    blur.backgroundColor = MMRGBA(255, 255, 255, MMBackgroundAlpha(host.traitCollection));
    MMSetRadius(blur, host.bounds.size.height * 0.5);
    blur.layer.masksToBounds = YES;
    blur.clipsToBounds = YES;
    return blur;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMFloatingCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMFloatingCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.clipsToBounds = YES;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    if (!border) {
        border = [UIView new];
        border.tag = kMMFloatingCapsuleBorderTag;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        border.clipsToBounds = YES;
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMFloatingCapsuleGlowTag];
    if (!glow) {
        glow = [UIView new];
        glow.tag = kMMFloatingCapsuleGlowTag;
        glow.userInteractionEnabled = NO;
        glow.backgroundColor = [UIColor clearColor];
        glow.clipsToBounds = YES;
        [capsule addSubview:glow];
    }

    return capsule;
}

static UIView *MMButtonsContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMFloatingButtonsTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMFloatingButtonsTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = YES;
        container.clipsToBounds = NO;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    return container;
}

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, host.bounds.size.height * 0.5);
    host.layer.borderWidth = 0.42;
    host.layer.borderColor = MMRGBA(255,255,255,MMHostBorderAlpha(host.traitCollection)).CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(host.traitCollection) ? 0.24 : 0.12)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0, 8);
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

static void MMStyleCapsule(UIView *host, NSInteger selectedIndex, NSInteger count) {
    if (count <= 0) return;

    UIView *capsule = MMCapsule(host);
    CGRect frame = MMCapsuleFrame(host, selectedIndex, count);
    capsule.frame = frame;
    capsule.backgroundColor = MMRGBA(255,255,255,MMCapsuleAlpha(host.traitCollection));
    MMSetRadius(capsule, frame.size.height * 0.5);
    capsule.clipsToBounds = YES;
    capsule.layer.masksToBounds = YES;

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.55;
    border.layer.borderColor = MMRGBA(255,255,255,MMCapsuleBorderAlpha(host.traitCollection)).CGColor;
    MMSetRadius(border, border.bounds.size.height * 0.5);
    border.clipsToBounds = YES;
    border.layer.masksToBounds = YES;

    UIView *glow = [capsule viewWithTag:kMMFloatingCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    MMSetRadius(glow, glow.bounds.size.height * 0.5);
    glow.clipsToBounds = YES;
    glow.layer.masksToBounds = YES;

    CAGradientLayer *grad = nil;
    for (CALayer *layer in glow.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            grad = (CAGradientLayer *)layer;
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
        (__bridge id)MMRGBA(255,255,255,MMGlowTopAlpha(host.traitCollection)).CGColor,
        (__bridge id)MMRGBA(255,255,255,MMGlowMidAlpha(host.traitCollection)).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.0).CGColor
    ];
}

@interface MMFloatingTabButton : UIControl
@property (nonatomic, strong) UIImageView *mm_imageView;
@property (nonatomic, strong) UILabel *mm_titleLabel;
@property (nonatomic, strong) UILabel *mm_badgeLabel;
@property (nonatomic, assign) NSInteger mm_index;
@end

@implementation MMFloatingTabButton
@end

static MMFloatingTabButton *MMEnsureButton(UIView *container, NSInteger index) {
    MMFloatingTabButton *button = (MMFloatingTabButton *)[container viewWithTag:6000 + index];
    if (!button) {
        button = [MMFloatingTabButton new];
        button.tag = 6000 + index;
        button.backgroundColor = [UIColor clearColor];
        button.opaque = NO;
        button.clipsToBounds = NO;

        UIImageView *imageView = [UIImageView new];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.opaque = NO;
        button.mm_imageView = imageView;
        [button addSubview:imageView];

        UILabel *titleLabel = [UILabel new];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.72;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.opaque = NO;
        button.mm_titleLabel = titleLabel;
        [button addSubview:titleLabel];

        UILabel *badgeLabel = [UILabel new];
        badgeLabel.textAlignment = NSTextAlignmentCenter;
        badgeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        badgeLabel.textColor = [UIColor whiteColor];
        badgeLabel.backgroundColor = MMRGBA(255, 83, 83, 1.0);
        badgeLabel.clipsToBounds = YES;
        badgeLabel.hidden = YES;
        button.mm_badgeLabel = badgeLabel;
        [button addSubview:badgeLabel];

        [container addSubview:button];
    }
    return button;
}

static NSArray<UIView *> *MMOriginalItemViews(UITabBar *tabBar) {
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

static void MMSelectIndex(UIView *view, NSInteger index) {
    UIResponder *r = view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                UITabBar *tabBar = MMFindTabBar(vc);
                if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
                    @try { [(id)vc setSelectedIndex:index]; } @catch (__unused NSException *e) {}
                }
                if (tabBar && index >= 0 && index < (NSInteger)tabBar.items.count) {
                    @try { tabBar.selectedItem = tabBar.items[index]; } @catch (__unused NSException *e) {}
                }
                break;
            }
        }
    }
}

static void MMUpdateButtons(UIViewController *vc, UITabBar *tabBar, UIView *host) {
    UIView *container = MMButtonsContainer(host);
    NSArray<UITabBarItem *> *items = tabBar.items;
    NSArray<UIView *> *originalItemViews = MMOriginalItemViews(tabBar);
    NSInteger count = items.count;
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    MMStyleCapsule(host, selectedIndex, count);

    NSMutableSet *validTags = [NSMutableSet set];
    for (NSInteger i = 0; i < count; i++) {
        [validTags addObject:@(6000 + i)];
        MMFloatingTabButton *button = MMEnsureButton(container, i);
        button.mm_index = i;
        [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            MMSelectIndex(button, button.mm_index);
        }] forControlEvents:UIControlEventTouchUpInside];

        CGRect frame = (i == selectedIndex) ? MMCapsuleFrame(host, i, count) : MMSlotFrame(host, i, count);
        button.frame = frame;
        button.backgroundColor = [UIColor clearColor];
        button.layer.backgroundColor = [UIColor clearColor].CGColor;

        UITabBarItem *item = items[i];
        UIView *sourceItemView = (i < (NSInteger)originalItemViews.count) ? originalItemViews[i] : nil;
        UIImageView *sourceImageView = MMKVC(sourceItemView, @"_imageView");
        UIImage *img = nil;
        if ([sourceImageView isKindOfClass:[UIImageView class]] && sourceImageView.image) {
            img = sourceImageView.image;
        } else if (i == selectedIndex && item.selectedImage) {
            img = item.selectedImage;
        } else {
            img = item.image;
        }

        if (img) {
            img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            button.mm_imageView.hidden = NO;
            button.mm_imageView.image = img;
        } else {
            button.mm_imageView.hidden = YES;
            button.mm_imageView.image = nil;
        }

        UIColor *titleColor = (i == selectedIndex) ? MMSelectedColor(host.traitCollection) : MMNormalColor(host.traitCollection);
        button.mm_imageView.tintColor = titleColor;
        button.mm_titleLabel.text = item.title ?: @"";
        button.mm_titleLabel.textColor = titleColor;
        button.mm_titleLabel.font = [UIFont systemFontOfSize:11 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightRegular)];

        NSString *badge = item.badgeValue;
        if (badge.length > 0) {
            button.mm_badgeLabel.hidden = NO;
            button.mm_badgeLabel.text = badge;
        } else {
            button.mm_badgeLabel.hidden = YES;
            button.mm_badgeLabel.text = nil;
        }

        CGFloat bw = button.bounds.size.width;
        CGFloat bh = button.bounds.size.height;
        CGFloat iconSize = 27.0;
        CGFloat titleH = 14.0;
        CGFloat spacing = 4.0;
        CGFloat totalH = (button.mm_imageView.hidden ? titleH : (iconSize + spacing + titleH));
        CGFloat startY = floor((bh - totalH) * 0.5);
        if (startY < 4.0) startY = 4.0;

        if (!button.mm_imageView.hidden) {
            button.mm_imageView.frame = CGRectMake(floor((bw - iconSize) * 0.5), startY, iconSize, iconSize);
            button.mm_titleLabel.frame = CGRectMake(0.0, startY + iconSize + spacing, bw, titleH);
        } else {
            button.mm_titleLabel.frame = CGRectMake(0.0, floor((bh - titleH) * 0.5), bw, titleH);
        }

        CGFloat badgeW = MAX(18.0, MIN(28.0, 10.0 + badge.length * 8.0));
        if (!button.mm_imageView.hidden) {
            button.mm_badgeLabel.frame = CGRectMake(CGRectGetMaxX(button.mm_imageView.frame) - 2.0, CGRectGetMinY(button.mm_imageView.frame) - 4.0, badgeW, 18.0);
        }
        MMSetRadius(button.mm_badgeLabel, 9.0);
    }

    for (UIView *sub in [container.subviews copy]) {
        if (![validTags containsObject:@(sub.tag)]) {
            [sub removeFromSuperview];
        }
    }
}

static void MMHideOriginalTabBarVisuals(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 0.01;
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
    MMUpdateButtons(vc, tabBar, host);

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
