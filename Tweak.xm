#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kMMGlassHostTag = 990001;
static NSInteger const kMMGlassViewTag = 990002;

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

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, host.bounds.size.height / 2.0);
    host.layer.borderWidth = 0.42;
    host.layer.borderColor = (MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.12) : MMRGBA(255, 255, 255, 0.22)).CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(host.traitCollection) ? 0.24 : 0.12)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0, 8);
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
        tabBar.hidden = YES;
        kMMUpdatingLayout = NO;
        return;
    }

    host.hidden = NO;
    tabBar.hidden = NO;

    CGFloat inset = MMBottomInset(root);
    CGFloat height = 66.0;
    CGFloat margin = 18.0;
    CGRect frame = CGRectMake(margin, root.bounds.size.height - inset - height - 10.0, root.bounds.size.width - margin * 2.0, height);

    host.frame = frame;
    MMStyleHost(host);
    MMGlass(host);

    tabBar.frame = frame;
    tabBar.alpha = 1.0;
    tabBar.userInteractionEnabled = YES;
    MMClearTabBar(tabBar);

    [root bringSubviewToFront:host];
    [root bringSubviewToFront:tabBar];

    kMMUpdatingLayout = NO;
}

%hook MMTabBarItemView

- (void)layoutSubviews {
    %orig;

    UIView *itemView = (UIView *)self;

    id customContentController = nil;
    @try {
        customContentController = [self valueForKey:@"_customContentView"];
    } @catch (__unused NSException *e) {
    }

    if (customContentController && [customContentController respondsToSelector:@selector(view)]) {
        @try {
            UIView *customView = [customContentController view];
            if ([customView isKindOfClass:[UIView class]]) {
                customView.hidden = YES;
                customView.alpha = 0.0;
            }
        } @catch (__unused NSException *e) {
        }
    }

    UIImageView *imageView = nil;
    UILabel *textLabel = nil;
    UIView *badgeView = nil;

    @try {
        imageView = [self valueForKey:@"_imageView"];
    } @catch (__unused NSException *e) {
    }

    @try {
        textLabel = [self valueForKey:@"_textLabel"];
    } @catch (__unused NSException *e) {
    }

    @try {
        badgeView = [self valueForKey:@"_badgeView"];
    } @catch (__unused NSException *e) {
    }

    if (![imageView isKindOfClass:[UIImageView class]] || ![textLabel isKindOfClass:[UILabel class]]) {
        return;
    }

    CGFloat bw = itemView.bounds.size.width;
    CGFloat bh = itemView.bounds.size.height;
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
