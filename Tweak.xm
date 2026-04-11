#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface MainTabBarViewController : UIViewController
- (void)setSelectedIndex:(NSUInteger)index;
@end

@interface MMFloatingTabButton : UIControl
@property (nonatomic, retain) UIImageView *mm_imageView;
@property (nonatomic, retain) UILabel *mm_titleLabel;
@property (nonatomic, retain) UILabel *mm_badgeLabel;
@property (nonatomic, assign) NSInteger mm_index;
@end

@implementation MMFloatingTabButton
@end

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingCapsuleTag = 990203;
static NSInteger const kMMFloatingButtonsTag = 990204;
static NSInteger const kMMFloatingEdgeTag = 990205;
static NSInteger const kMMFloatingShineTag = 990206;
static NSInteger const kMMFloatingBackdropTag = 990207;
static NSInteger const kMMFloatingSearchHostTag = 990208;
static NSInteger const kMMFloatingSearchBlurTag = 990209;
static NSInteger const kMMFloatingSearchIconTag = 990210;
static NSInteger const kMMFloatingCapsuleBlurTag = 990211;
static NSInteger const kMMFloatingCapsuleTintTag = 990212;
static NSInteger const kMMFloatingCapsuleBorderTag = 990213;
static NSInteger const kMMFloatingSearchButtonTag = 990214;

static BOOL kMMUpdatingLayout = NO;

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static CGFloat MMBottomInset(UIView *view) {
    if ([view respondsToSelector:@selector(safeAreaInsets)]) return view.safeAreaInsets.bottom;
    return 0.0;
}

static void MMSetRadius(UIView *view, CGFloat radius) {
    if (!view) return;
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

static NSArray *MMOriginalItemViews(UITabBar *tabBar) {
    NSMutableArray *items = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBarItemView"] || [name containsString:@"UITabBarButton"]) {
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

static BOOL MMShouldShowFloatingBar(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return NO;

    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {
    }

    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        UIViewController *root = nav.viewControllers.count > 0 ? [nav.viewControllers objectAtIndex:0] : nil;
        UIViewController *top = nav.topViewController ?: nav.visibleViewController;
        if (root && top && top != root) return NO;
        if (nav.presentedViewController) return NO;
    } else if ([selected isKindOfClass:[UIViewController class]]) {
        UIViewController *child = (UIViewController *)selected;
        if (child.presentedViewController) return NO;
    }

    if (vc.presentedViewController) return NO;
    return YES;
}

static UIView *MMBackdropHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMFloatingBackdropTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMFloatingBackdropTag;
        host.userInteractionEnabled = NO;
        host.backgroundColor = [UIColor clearColor];
        [root addSubview:host];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingBlurTag + 500;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];
    }
    return host;
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
    return host;
}

static UIVisualEffectView *MMBlur(UIView *host) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMFloatingBlurTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];
    }
    blur.frame = host.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, CGRectGetHeight(host.bounds) * 0.5);

    UIView *tint = [blur.contentView viewWithTag:991000];
    if (!tint) {
        tint = [UIView new];
        tint.tag = 991000;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithWhite:1.0 alpha:0.13];
    return blur;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMFloatingCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMFloatingCapsuleTag;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.userInteractionEnabled = NO;
        capsule.clipsToBounds = YES;
        [host addSubview:capsule];

        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
            blur.tag = kMMFloatingCapsuleBlurTag;
            blur.userInteractionEnabled = NO;
            blur.clipsToBounds = YES;
            [capsule addSubview:blur];
        }

        UIView *tint = [UIView new];
        tint.tag = kMMFloatingCapsuleTintTag;
        tint.userInteractionEnabled = NO;
        [capsule addSubview:tint];

        UIView *border = [UIView new];
        border.tag = kMMFloatingCapsuleBorderTag;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        [capsule addSubview:border];
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
        [host addSubview:container];
    }
    container.frame = host.bounds;
    return container;
}

static UIView *MMSearchHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMFloatingSearchHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMFloatingSearchHostTag;
        host.userInteractionEnabled = YES;
        host.backgroundColor = [UIColor clearColor];
        host.clipsToBounds = NO;
        [root addSubview:host];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingSearchBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];

        UIImageView *icon = [UIImageView new];
        icon.tag = kMMFloatingSearchIconTag;
        icon.userInteractionEnabled = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [host addSubview:icon];
    }
    return host;
}

static void MMStyleBackdrop(UIView *backdrop) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[backdrop viewWithTag:kMMFloatingBlurTag + 500];
    blur.frame = backdrop.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(backdrop.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight)];
    }

    CAGradientLayer *mask = nil;
    if ([backdrop.layer.mask isKindOfClass:[CAGradientLayer class]]) {
        mask = (CAGradientLayer *)backdrop.layer.mask;
    } else {
        mask = [CAGradientLayer layer];
        backdrop.layer.mask = mask;
    }
    mask.frame = backdrop.bounds;
    mask.startPoint = CGPointMake(0.5, 0.0);
    mask.endPoint = CGPointMake(0.5, 1.0);
    mask.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.30].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor
    ];
    mask.locations = @[@0.0, @0.22, @1.0];
}

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, CGRectGetHeight(host.bounds) * 0.5);
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = MMIsDark(host.traitCollection) ? 0.12 : 0.09;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    host.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:host.bounds cornerRadius:CGRectGetHeight(host.bounds) * 0.5].CGPath;

    UIView *edge = [host viewWithTag:kMMFloatingEdgeTag];
    if (!edge) {
        edge = [UIView new];
        edge.tag = kMMFloatingEdgeTag;
        edge.userInteractionEnabled = NO;
        edge.backgroundColor = [UIColor clearColor];
        [host addSubview:edge];
    }
    edge.frame = host.bounds;
    MMSetRadius(edge, CGRectGetHeight(host.bounds) * 0.5);
    edge.layer.borderWidth = 0.8;
    edge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.16 : 0.28)].CGColor;

    UIView *shine = [host viewWithTag:kMMFloatingShineTag];
    if (!shine) {
        shine = [UIView new];
        shine.tag = kMMFloatingShineTag;
        shine.userInteractionEnabled = NO;
        shine.backgroundColor = [UIColor clearColor];
        shine.clipsToBounds = YES;
        [host addSubview:shine];
    }
    shine.frame = CGRectInset(host.bounds, 1.0, 1.0);
    MMSetRadius(shine, CGRectGetHeight(shine.bounds) * 0.5);

    CAGradientLayer *g = nil;
    for (CALayer *layer in shine.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            g = (CAGradientLayer *)layer;
            break;
        }
    }
    if (!g) {
        g = [CAGradientLayer layer];
        [shine.layer addSublayer:g];
    }
    g.frame = shine.bounds;
    g.startPoint = CGPointMake(0.5, 0.0);
    g.endPoint = CGPointMake(0.5, 1.0);
    g.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.15 : 0.25)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.04 : 0.06)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    g.locations = @[@0.0, @0.18, @0.44];
    g.cornerRadius = CGRectGetHeight(shine.bounds) * 0.5;
}

static void MMStyleCapsule(UIView *capsule, UIView *host) {
    MMSetRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *blur = [capsule viewWithTag:kMMFloatingCapsuleBlurTag];
    if ([blur isKindOfClass:[UIVisualEffectView class]]) {
        blur.frame = capsule.bounds;
        ((UIVisualEffectView *)blur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        MMSetRadius(blur, CGRectGetHeight(capsule.bounds) * 0.5);
    }

    UIView *tint = [capsule viewWithTag:kMMFloatingCapsuleTintTag];
    tint.frame = capsule.bounds;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:1.0 alpha:0.18];
    MMSetRadius(tint, CGRectGetHeight(capsule.bounds) * 0.5);

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.18 : 0.34)].CGColor;
    MMSetRadius(border, CGRectGetHeight(border.bounds) * 0.5);
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

static UIViewController *MMFindHomeContentControllerFromController(UIViewController *vc) {
    if (!vc) return nil;
    NSString *name = NSStringFromClass([vc class]);
    if ([name isEqualToString:@"NewMainFrameViewController"]) return vc;

    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        for (UIViewController *sub in nav.viewControllers) {
            UIViewController *found = MMFindHomeContentControllerFromController(sub);
            if (found) return found;
        }
    }

    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *found = MMFindHomeContentControllerFromController(child);
        if (found) return found;
    }

    id tabs = nil;
    @try { tabs = [vc valueForKey:@"viewControllers"]; } @catch (__unused NSException *e) {}
    if ([tabs isKindOfClass:[NSArray class]]) {
        for (UIViewController *sub in (NSArray *)tabs) {
            UIViewController *found = MMFindHomeContentControllerFromController(sub);
            if (found) return found;
        }
    }
    return nil;
}

static UIView *MMFindSearchBarInView(UIView *root) {
    if (!root) return nil;
    NSString *name = NSStringFromClass([root class]);
    if ([name containsString:@"WCSearchBar"]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = MMFindSearchBarInView(sub);
        if (found) return found;
    }
    return nil;
}

static void MMOpenSearchFromMainTab(UIViewController *vc) {
    if (!vc) return;
    UIViewController *targetVC = MMFindHomeContentControllerFromController(vc);
    if (!targetVC) targetVC = vc;
    if ([targetVC respondsToSelector:@selector(onTapOnSearchButton)]) {
        ((void (*)(id, SEL))objc_msgSend)(targetVC, @selector(onTapOnSearchButton));
    }
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
                if (tabBar && index >= 0 && index < (NSInteger)[tabBar.items count]) {
                    @try { tabBar.selectedItem = [tabBar.items objectAtIndex:index]; } @catch (__unused NSException *e) {}
                }
                break;
            }
        }
    }
}

@interface MMFloatingActionProxy : NSObject
@end

@implementation MMFloatingActionProxy

- (void)handleTabTap:(MMFloatingTabButton *)sender {
    MMSelectIndex(sender, sender.mm_index);
}

- (void)handleSearchTap:(UIButton *)sender {
    UIResponder *r = sender;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMOpenSearchFromMainTab(vc);
                break;
            }
        }
    }
}

@end

static MMFloatingActionProxy *MMSharedActionProxy(void) {
    static MMFloatingActionProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMFloatingActionProxy new];
    });
    return proxy;
}

static CGRect MMSlotFrame(UIView *host, NSInteger index, NSInteger count) {
    CGFloat sideInset = 14.0;
    CGFloat interGap = 6.0;
    CGFloat usableW = CGRectGetWidth(host.bounds) - sideInset * 2.0 - interGap * (MAX(count, 1) - 1);
    CGFloat slotW = floor(usableW / MAX(count, 1));
    CGFloat x = sideInset + index * (slotW + interGap);
    if (index == count - 1) {
        slotW = CGRectGetWidth(host.bounds) - sideInset - x;
    }
    return CGRectMake(x, 0.0, slotW, CGRectGetHeight(host.bounds));
}

static CGRect MMCapsuleFrame(UIView *host, NSInteger index, NSInteger count) {
    CGRect slot = MMSlotFrame(host, index, count);
    CGFloat capH = CGRectGetHeight(host.bounds) - 10.0;
    CGFloat capW = MIN(CGRectGetWidth(slot) + 10.0, 72.0);
    CGFloat x = CGRectGetMidX(slot) - capW * 0.5;
    CGFloat y = (CGRectGetHeight(host.bounds) - capH) * 0.5;
    if (x < 4.0) x = 4.0;
    if (x + capW > CGRectGetWidth(host.bounds) - 4.0) x = CGRectGetWidth(host.bounds) - 4.0 - capW;
    return CGRectMake(x, y, capW, capH);
}

static MMFloatingTabButton *MMEnsureButton(UIView *container, NSInteger index) {
    MMFloatingTabButton *button = (MMFloatingTabButton *)[container viewWithTag:6000 + index];
    if (!button) {
        button = [MMFloatingTabButton new];
        button.tag = 6000 + index;
        button.backgroundColor = [UIColor clearColor];
        button.clipsToBounds = NO;

        UIImageView *imageView = [UIImageView new];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = [UIColor clearColor];
        [button addSubview:imageView];
        button.mm_imageView = imageView;

        UILabel *titleLabel = [UILabel new];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.65;
        titleLabel.backgroundColor = [UIColor clearColor];
        [button addSubview:titleLabel];
        button.mm_titleLabel = titleLabel;

        UILabel *badgeLabel = [UILabel new];
        badgeLabel.textAlignment = NSTextAlignmentCenter;
        badgeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        badgeLabel.textColor = [UIColor whiteColor];
        badgeLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.33 blue:0.33 alpha:1.0];
        badgeLabel.hidden = YES;
        badgeLabel.clipsToBounds = YES;
        [button addSubview:badgeLabel];
        button.mm_badgeLabel = badgeLabel;

        [button addTarget:MMSharedActionProxy() action:@selector(handleTabTap:) forControlEvents:UIControlEventTouchUpInside];
        [container addSubview:button];
    }
    return button;
}

static void MMUpdateButtons(UIViewController *vc, UITabBar *tabBar, UIView *host) {
    UIView *container = MMButtonsContainer(host);
    NSArray *items = tabBar.items;
    NSArray *sourceViews = MMOriginalItemViews(tabBar);
    NSInteger count = [items count];
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    NSMutableSet *valid = [NSMutableSet set];
    for (NSInteger i = 0; i < count; i++) {
        MMFloatingTabButton *button = MMEnsureButton(container, i);
        button.mm_index = i;
        [valid addObject:@(button.tag)];
        button.frame = MMSlotFrame(container, i, count);

        UITabBarItem *item = [items objectAtIndex:i];
        UIView *sourceView = i < (NSInteger)[sourceViews count] ? [sourceViews objectAtIndex:i] : nil;
        UIImageView *sourceImageView = MMKVC(sourceView, @"_imageView");
        UILabel *sourceLabel = MMKVC(sourceView, @"_textLabel");

        UIImage *image = nil;
        if ([sourceImageView isKindOfClass:[UIImageView class]] && sourceImageView.image) {
            image = sourceImageView.image;
        } else if (i == selectedIndex && item.selectedImage) {
            image = item.selectedImage;
        } else {
            image = item.image;
        }

        if (image) {
            button.mm_imageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            button.mm_imageView.hidden = NO;
        } else {
            button.mm_imageView.image = nil;
            button.mm_imageView.hidden = YES;
        }

        UIColor *normalColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.88] : [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
        UIColor *selectedColor = MMIsDark(host.traitCollection) ? [UIColor colorWithRed:0.12 green:0.93 blue:0.44 alpha:1.0] : [UIColor colorWithRed:0.00 green:0.76 blue:0.30 alpha:1.0];

        if (i == selectedIndex) {
            UIColor *iconColor = ([sourceImageView isKindOfClass:[UIImageView class]] && sourceImageView.tintColor) ? sourceImageView.tintColor : selectedColor;
            UIColor *textColor = ([sourceLabel isKindOfClass:[UILabel class]] && sourceLabel.textColor) ? sourceLabel.textColor : iconColor;
            button.mm_imageView.tintColor = iconColor;
            button.mm_titleLabel.textColor = textColor;
            button.mm_titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
        } else {
            button.mm_imageView.tintColor = normalColor;
            button.mm_titleLabel.textColor = normalColor;
            button.mm_titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
        }

        button.mm_titleLabel.text = item.title ?: @"";

        NSString *badge = item.badgeValue;
        if ([badge length] > 0) {
            button.mm_badgeLabel.hidden = NO;
            button.mm_badgeLabel.text = badge;
        } else {
            button.mm_badgeLabel.hidden = YES;
            button.mm_badgeLabel.text = nil;
        }

        CGFloat bw = CGRectGetWidth(button.bounds);
        CGFloat bh = CGRectGetHeight(button.bounds);
        CGFloat iconSize = 24.0;
        CGFloat titleH = 14.0;
        CGFloat gap = 2.0;
        CGFloat totalH = iconSize + gap + titleH;
        CGFloat startY = floor((bh - totalH) * 0.5);
        if (startY < 4.0) startY = 4.0;

        if (!button.mm_imageView.hidden) {
            button.mm_imageView.frame = CGRectMake(floor((bw - iconSize) * 0.5), startY, iconSize, iconSize);
            button.mm_titleLabel.frame = CGRectMake(0.0, startY + iconSize + gap, bw, titleH);
        } else {
            button.mm_titleLabel.frame = CGRectMake(0.0, floor((bh - titleH) * 0.5), bw, titleH);
        }

        CGFloat badgeW = MAX(18.0, MIN(30.0, 10.0 + [badge length] * 8.0));
        button.mm_badgeLabel.frame = CGRectMake(CGRectGetMaxX(button.mm_imageView.frame) - 1.0, CGRectGetMinY(button.mm_imageView.frame) - 4.0, badgeW, 18.0);
        MMSetRadius(button.mm_badgeLabel, 9.0);
    }

    for (UIView *sub in [[container subviews] copy]) {
        if (![valid containsObject:@(sub.tag)]) [sub removeFromSuperview];
    }

    (void)vc;
}

static void MMUpdateSearchButton(UIViewController *vc, UIView *root, CGRect barFrame) {
    UIViewController *homeVC = MMFindHomeContentControllerFromController(vc);
    UIView *searchBar = homeVC ? MMFindSearchBarInView(homeVC.view) : nil;
    UIView *searchHost = MMSearchHost(root);

    if (!searchBar) {
        searchHost.hidden = YES;
        searchHost.alpha = 0.0;
        return;
    }

    CGFloat size = CGRectGetHeight(barFrame);
    CGFloat gap = 10.0;
    CGFloat x = CGRectGetMaxX(barFrame) + gap;
    CGFloat y = CGRectGetMinY(barFrame);

    searchHost.frame = CGRectMake(x, y, size, size);
    searchHost.hidden = NO;
    searchHost.alpha = 1.0;

    UIVisualEffectView *blur = (UIVisualEffectView *)[searchHost viewWithTag:kMMFloatingSearchBlurTag];
    blur.frame = searchHost.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(searchHost.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    }
    MMSetRadius(blur, size * 0.5);

    UIView *tint = [blur.contentView viewWithTag:991001];
    if (!tint) {
        tint = [UIView new];
        tint.tag = 991001;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(searchHost.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithWhite:1.0 alpha:0.13];

    searchHost.layer.shadowColor = [UIColor blackColor].CGColor;
    searchHost.layer.shadowOpacity = MMIsDark(searchHost.traitCollection) ? 0.12 : 0.09;
    searchHost.layer.shadowRadius = 18.0;
    searchHost.layer.shadowOffset = CGSizeMake(0.0, 9.0);
    searchHost.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:searchHost.bounds cornerRadius:size * 0.5].CGPath;
    MMSetRadius(searchHost, size * 0.5);

    UIImageView *icon = (UIImageView *)[searchHost viewWithTag:kMMFloatingSearchIconTag];
    icon.frame = CGRectMake(floor((size - 28.0) * 0.5), floor((size - 28.0) * 0.5), 28.0, 28.0);
    icon.tintColor = MMIsDark(searchHost.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.92] : [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        icon.image = nil;
    }

    UIButton *button = (UIButton *)[searchHost viewWithTag:kMMFloatingSearchButtonTag];
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = kMMFloatingSearchButtonTag;
        button.backgroundColor = [UIColor clearColor];
        [button addTarget:MMSharedActionProxy() action:@selector(handleSearchTap:) forControlEvents:UIControlEventTouchUpInside];
        [searchHost addSubview:button];
    }
    button.frame = searchHost.bounds;

    [root bringSubviewToFront:searchHost];
}

static void MMSetVisible(UIView *view, BOOL visible) {
    if (!view) return;
    view.hidden = !visible;
    view.alpha = visible ? 1.0 : 0.0;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    UIView *host = MMHost(root);
    UIView *backdrop = MMBackdropHost(root);
    UIView *searchHost = MMSearchHost(root);

    if (!root || !tabBar || !MMShouldShowFloatingBar(vc)) {
        MMSetVisible(host, NO);
        MMSetVisible(backdrop, NO);
        MMSetVisible(searchHost, NO);
        kMMUpdatingLayout = NO;
        return;
    }

    CGFloat inset = MMBottomInset(root);
    CGFloat margin = 16.0;
    CGFloat gap = 10.0;
    CGFloat searchSize = 72.0;
    CGFloat height = 72.0;
    CGFloat y = CGRectGetHeight(root.bounds) - inset - height + 10.0;

    UIViewController *homeVC = MMFindHomeContentControllerFromController(vc);
    UIView *searchBar = homeVC ? MMFindSearchBarInView(homeVC.view) : nil;
    BOOL showSearch = (searchBar != nil);

    CGFloat width = CGRectGetWidth(root.bounds) - margin * 2.0 - (showSearch ? (searchSize + gap) : 0.0);
    CGRect barFrame = CGRectMake(margin, y, width, height);

    backdrop.frame = CGRectMake(margin - 6.0, y - 12.0, CGRectGetWidth(root.bounds) - (margin - 6.0) * 2.0, height + inset + 18.0);
    MMStyleBackdrop(backdrop);

    host.frame = barFrame;
    MMBlur(host);
    MMStyleHost(host);

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [tabBar.items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    UIView *capsule = MMCapsule(host);
    capsule.frame = MMCapsuleFrame(host, selectedIndex, (NSInteger)[tabBar.items count]);
    capsule.hidden = NO;
    MMStyleCapsule(capsule, host);

    MMHideOriginalTabBarVisuals(tabBar);
    MMUpdateButtons(vc, tabBar, host);

    [root bringSubviewToFront:backdrop];
    [root bringSubviewToFront:host];
    MMUpdateSearchButton(vc, root, barFrame);

    MMSetVisible(backdrop, YES);
    MMSetVisible(host, YES);

    kMMUpdatingLayout = NO;
}

static void MMRequestRefresh(UIViewController *vc) {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar(vc);
    });
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    MMRequestRefresh((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMRequestRefresh((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMRequestRefresh((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMRequestRefresh((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    MMRequestRefresh((UIViewController *)self);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    %orig(selectedViewController);
    MMRequestRefresh((UIViewController *)self);
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
                MMRequestRefresh(vc);
                break;
            }
        }
    }
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

%end

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    %orig(viewController, animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *ret = %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
    return ret;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    UIResponder *r = self;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                MMRequestRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

%end
