#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface MainTabBarViewController : UIViewController
- (void)setSelectedIndex:(NSUInteger)index;
@end

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingButtonsTag = 990206;

static BOOL kMMUpdatingLayout = NO;

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

static UITabBar *MMFindTabBar(UIViewController *vc) {
    @try {
        id tb = [vc valueForKey:@"tabBar"];
        if ([tb isKindOfClass:[UITabBar class]]) {
            return (UITabBar *)tb;
        }
    } @catch (__unused NSException *e) {
    }

    for (UIView *sub in vc.view.subviews) {
        if ([sub isKindOfClass:[UITabBar class]]) {
            return (UITabBar *)sub;
        }
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBar"]) {
            return (UITabBar *)sub;
        }
    }
    return nil;
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
        [host insertSubview:blur atIndex:0];
    }

    blur.frame = host.bounds;

    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }

    MMSetRadius(blur, host.bounds.size.height * 0.5);
    blur.clipsToBounds = YES;
    blur.layer.masksToBounds = YES;

    UIView *tint = [blur.contentView viewWithTag:990301];
    if (!tint) {
        tint = [UIView new];
        tint.tag = 990301;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.18];

    return blur;
}

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, host.bounds.size.height * 0.5);
    host.backgroundColor = [UIColor clearColor];
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = MMIsDark(host.traitCollection) ? 0.16 : 0.10;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0, 8.0);
    host.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:host.bounds cornerRadius:host.bounds.size.height * 0.5].CGPath;

    UIView *edge = [host viewWithTag:990302];
    if (!edge) {
        edge = [UIView new];
        edge.tag = 990302;
        edge.userInteractionEnabled = NO;
        edge.backgroundColor = [UIColor clearColor];
        [host addSubview:edge];
    }
    edge.frame = host.bounds;
    MMSetRadius(edge, host.bounds.size.height * 0.5);
    edge.layer.borderWidth = 0.8;
    edge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.14 : 0.32)].CGColor;

    UIView *shine = [host viewWithTag:990303];
    if (!shine) {
        shine = [UIView new];
        shine.tag = 990303;
        shine.userInteractionEnabled = NO;
        shine.backgroundColor = [UIColor clearColor];
        [host addSubview:shine];
    }
    shine.frame = CGRectInset(host.bounds, 1.0, 1.0);
    MMSetRadius(shine, shine.bounds.size.height * 0.5);
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
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.16 : 0.32)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.04 : 0.08)].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    g.locations = @[@0.0, @0.18, @0.45];
    g.cornerRadius = shine.bounds.size.height * 0.5;
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

static void MMSelectIndex(UIView *view, NSInteger index) {
    UIResponder *r = view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                UITabBar *tabBar = MMFindTabBar(vc);
                NSArray *originViews = MMOriginalItemViews(tabBar);

                if (index >= 0 && index < (NSInteger)originViews.count) {
                    UIView *itemView = [originViews objectAtIndex:index];
                    if ([itemView isKindOfClass:[UIControl class]]) {
                        [(UIControl *)itemView sendActionsForControlEvents:UIControlEventTouchUpInside];
                        return;
                    }
                    for (UIView *sub in itemView.subviews) {
                        if ([sub isKindOfClass:[UIControl class]]) {
                            [(UIControl *)sub sendActionsForControlEvents:UIControlEventTouchUpInside];
                            return;
                        }
                    }
                }

                if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
                    @try {
                        [(id)vc setSelectedIndex:index];
                    } @catch (__unused NSException *e) {
                    }
                }

                if (tabBar && index >= 0 && index < (NSInteger)tabBar.items.count) {
                    @try {
                        tabBar.selectedItem = [tabBar.items objectAtIndex:index];
                    } @catch (__unused NSException *e) {
                    }
                }
                break;
            }
        }
    }
}

static void MMUpdateButtons(UIViewController *vc, UITabBar *tabBar, UIView *host) {
    UIView *container = [host viewWithTag:kMMFloatingButtonsTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMFloatingButtonsTag;
        container.backgroundColor = [UIColor clearColor];
        [host addSubview:container];
    }
    container.frame = host.bounds;

    NSArray *items = tabBar.items;
    NSInteger count = items.count;
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    CGFloat sideInset = 16.0;
    CGFloat buttonW = (container.bounds.size.width - sideInset * 2.0) / count;
    CGFloat h = container.bounds.size.height;

    NSMutableSet *valid = [NSMutableSet set];
    for (NSInteger i = 0; i < count; i++) {
        NSNumber *tagNum = @(5000 + i);
        [valid addObject:tagNum];

        UIControl *btn = (UIControl *)[container viewWithTag:5000 + i];
        UIImageView *icon = nil;
        UILabel *label = nil;
        UIView *capsule = nil;

        if (!btn) {
            btn = [[UIControl alloc] initWithFrame:CGRectZero];
            btn.tag = 5000 + i;
            btn.backgroundColor = [UIColor clearColor];

            capsule = [UIView new];
            capsule.tag = 7000;
            capsule.userInteractionEnabled = NO;
            capsule.backgroundColor = [UIColor clearColor];
            [btn addSubview:capsule];

            if (@available(iOS 13.0, *)) {
                UIVisualEffectView *selBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
                selBlur.tag = 7001;
                selBlur.userInteractionEnabled = NO;
                [capsule addSubview:selBlur];
            }

            UIView *selTint = [UIView new];
            selTint.tag = 7002;
            selTint.userInteractionEnabled = NO;
            [capsule addSubview:selTint];

            icon = [UIImageView new];
            icon.tag = 7003;
            icon.contentMode = UIViewContentModeScaleAspectFit;
            [btn addSubview:icon];

            label = [UILabel new];
            label.tag = 7004;
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightRegular];
            [btn addSubview:label];

            [btn addTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
            [btn addTarget:btn action:@selector(removeTarget:action:forControlEvents:) forControlEvents:UIControlEventTouchDragInside];
            [btn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
                MMSelectIndex(btn, i);
            }] forControlEvents:UIControlEventTouchUpInside];

            [container addSubview:btn];
        } else {
            capsule = [btn viewWithTag:7000];
            icon = (UIImageView *)[btn viewWithTag:7003];
            label = (UILabel *)[btn viewWithTag:7004];
        }

        btn.frame = CGRectMake(sideInset + buttonW * i, 0.0, buttonW, h);

        BOOL selected = (i == selectedIndex);
        capsule.hidden = !selected;
        if (selected) {
            CGFloat capW = MIN(buttonW - 4.0, 68.0);
            CGFloat capH = 56.0;
            capsule.frame = CGRectMake((buttonW - capW) * 0.5, (h - capH) * 0.5, capW, capH);
            MMSetRadius(capsule, capH * 0.5);
            capsule.layer.borderWidth = 0.8;
            capsule.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(host.traitCollection) ? 0.16 : 0.34)].CGColor;

            UIView *selTint = [capsule viewWithTag:7002];
            selTint.frame = capsule.bounds;
            selTint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.16];
            MMSetRadius(selTint, capH * 0.5);

            UIView *selBlur = [capsule viewWithTag:7001];
            if ([selBlur isKindOfClass:[UIVisualEffectView class]]) {
                selBlur.frame = capsule.bounds;
                ((UIVisualEffectView *)selBlur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
                MMSetRadius(selBlur, capH * 0.5);
                selBlur.clipsToBounds = YES;
            }
        }

        UITabBarItem *item = [items objectAtIndex:i];
        UIImage *img = selected && item.selectedImage ? item.selectedImage : item.image;
        if (img) {
            icon.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            icon.image = nil;
        }

        icon.tintColor = selected
            ? (MMIsDark(host.traitCollection) ? [UIColor colorWithRed:0.15 green:0.92 blue:0.45 alpha:1.0] : [UIColor colorWithRed:0.00 green:0.76 blue:0.30 alpha:1.0])
            : (MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.88] : [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92]);

        label.text = item.title ?: @"";
        label.textColor = icon.tintColor;
        label.font = [UIFont systemFontOfSize:11.0 weight:(selected ? UIFontWeightSemibold : UIFontWeightRegular)];

        CGFloat iconSize = 26.0;
        CGFloat labelH = 15.0;
        CGFloat gap = 3.0;
        CGFloat totalH = iconSize + gap + labelH;
        CGFloat startY = floor((h - totalH) * 0.5);
        icon.frame = CGRectMake(floor((buttonW - iconSize) * 0.5), startY, iconSize, iconSize);
        label.frame = CGRectMake(0.0, startY + iconSize + gap, buttonW, labelH);
    }

    for (UIView *sub in [container.subviews copy]) {
        if (![valid containsObject:@(sub.tag)]) {
            [sub removeFromSuperview];
        }
    }

    (void)vc;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!root || !tabBar) {
        kMMUpdatingLayout = NO;
        return;
    }

    UIView *host = MMHost(root);

    CGFloat height = 80.0;
    CGFloat margin = 16.0;
    CGFloat inset = MMBottomInset(root);
    CGFloat y = CGRectGetHeight(root.bounds) - inset - height - 12.0;
    host.frame = CGRectMake(margin, y, CGRectGetWidth(root.bounds) - margin * 2.0, height);

    MMStyleHost(host);
    MMBlur(host);

    tabBar.hidden = NO;
    tabBar.transform = CGAffineTransformIdentity;
    tabBar.frame = CGRectMake(0.0, CGRectGetHeight(root.bounds) - 90.0, CGRectGetWidth(root.bounds), 90.0);

    MMHideOriginalTabBarVisuals(tabBar);
    MMUpdateButtons(vc, tabBar, host);

    host.hidden = NO;
    host.alpha = 1.0;
    [root bringSubviewToFront:host];

    kMMUpdatingLayout = NO;
}

static void MMRequestFloatingBarRefresh(UIViewController *vc) {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar(vc);
    });
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    MMRequestFloatingBarRefresh((UIViewController *)self);
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
                MMRequestFloatingBarRefresh(vc);
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
                MMRequestFloatingBarRefresh(vc);
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
                MMRequestFloatingBarRefresh(vc);
                break;
            }
        }
        r = [r nextResponder];
    }
}

%end
