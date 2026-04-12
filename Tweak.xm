#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface MainTabBarViewController : UIViewController
- (void)setSelectedIndex:(NSUInteger)index;
@end

@interface MMFloatingProxy : NSObject
- (void)tapTab:(UIButton *)sender;
- (void)tapSearch:(UIButton *)sender;
@end

static MMFloatingProxy *MMSharedProxy(void);

static char kMMVCKey;
static char kMMIndexKey;

static NSInteger const kMMBackdropTag = 998000;
static NSInteger const kMMBackdropBlurTag = 998001;
static NSInteger const kMMBackdropTintTag = 998002;
static NSInteger const kMMGlassTag = 998003;
static NSInteger const kMMGlassBlurTag = 998004;
static NSInteger const kMMGlassTintTag = 998005;
static NSInteger const kMMGlassBorderTag = 998006;
static NSInteger const kMMGlassShineTag = 998007;
static NSInteger const kMMCapsuleTag = 998008;
static NSInteger const kMMCapsuleBlurTag = 998009;
static NSInteger const kMMCapsuleTintTag = 998010;
static NSInteger const kMMCapsuleBorderTag = 998011;
static NSInteger const kMMSearchTag = 998012;
static NSInteger const kMMSearchBlurTag = 998013;
static NSInteger const kMMSearchTintTag = 998014;
static NSInteger const kMMSearchIconTag = 998015;
static NSInteger const kMMOverlayButtonBaseTag = 998100;

static BOOL kMMUpdating = NO;

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static void MMSetRadius(UIView *view, CGFloat radius) {
    if (!view) return;
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static UITabBar *MMFindTabBar(UIViewController *vc) {
    if (!vc) return nil;
    @try {
        id tb = [vc valueForKey:@"tabBar"];
        if ([tb isKindOfClass:[UITabBar class]]) return (UITabBar *)tb;
    } @catch (__unused NSException *e) {}
    for (UIView *sub in vc.view.subviews) {
        if ([sub isKindOfClass:[UITabBar class]]) return (UITabBar *)sub;
    }
    return nil;
}

static UIViewController *MMFindHomeController(UIViewController *vc) {
    if (!vc) return nil;
    NSString *name = NSStringFromClass([vc class]);
    if ([name isEqualToString:@"NewMainFrameViewController"]) return vc;
    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        for (UIViewController *child in nav.viewControllers) {
            UIViewController *found = MMFindHomeController(child);
            if (found) return found;
        }
    }
    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *found = MMFindHomeController(child);
        if (found) return found;
    }
    id vcs = nil;
    @try { vcs = [vc valueForKey:@"viewControllers"]; } @catch (__unused NSException *e) {}
    if ([vcs isKindOfClass:[NSArray class]]) {
        for (UIViewController *child in (NSArray *)vcs) {
            UIViewController *found = MMFindHomeController(child);
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

static UIView *MMFindLabelContainingText(UIView *root, NSString *text) {
    if (!root || !text.length) return nil;
    if ([root isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)root;
        if ([label.text containsString:text]) return label;
    }
    for (UIView *sub in root.subviews) {
        UIView *found = MMFindLabelContainingText(sub, text);
        if (found) return found;
    }
    return nil;
}

static BOOL MMShouldShow(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return NO;
    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) selected = [vc valueForKey:@"selectedViewController"];
    } @catch (__unused NSException *e) {}
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        UIViewController *root = nav.viewControllers.count > 0 ? nav.viewControllers.firstObject : nil;
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

static NSComparisonResult MMCompareViewX(id a, id b, void *context) {
    CGFloat ax = CGRectGetMinX(((UIView *)a).frame);
    CGFloat bx = CGRectGetMinX(((UIView *)b).frame);
    if (ax < bx) return NSOrderedAscending;
    if (ax > bx) return NSOrderedDescending;
    return NSOrderedSame;
}

static NSArray *MMItemViews(UITabBar *tabBar) {
    NSMutableArray *arr = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"UITabBarButton"]) [arr addObject:sub];
    }
    [arr sortUsingFunction:MMCompareViewX context:NULL];
    return arr;
}

static UIView *MMEnsureBackdrop(UIView *root) {
    UIView *view = [root viewWithTag:kMMBackdropTag];
    if (!view) {
        view = [UIView new];
        view.tag = kMMBackdropTag;
        view.userInteractionEnabled = NO;
        [root addSubview:view];
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMBackdropBlurTag;
        blur.userInteractionEnabled = NO;
        [view addSubview:blur];
        UIView *tint = [UIView new];
        tint.tag = kMMBackdropTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
    }
    return view;
}

static UIView *MMEnsureGlass(UIView *root) {
    UIView *glass = [root viewWithTag:kMMGlassTag];
    if (!glass) {
        glass = [UIView new];
        glass.tag = kMMGlassTag;
        glass.userInteractionEnabled = NO;
        [root addSubview:glass];
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMGlassBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [glass addSubview:blur];
        UIView *tint = [UIView new];
        tint.tag = kMMGlassTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
        UIView *border = [UIView new];
        border.tag = kMMGlassBorderTag;
        border.userInteractionEnabled = NO;
        [glass addSubview:border];
        UIView *shine = [UIView new];
        shine.tag = kMMGlassShineTag;
        shine.userInteractionEnabled = NO;
        shine.clipsToBounds = YES;
        [glass addSubview:shine];
        UIView *capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.clipsToBounds = YES;
        [glass addSubview:capsule];
        if (@available(iOS 13.0, *)) {
            UIVisualEffectView *capsuleBlur = [[UIVisualEffectView alloc] initWithEffect:nil];
            capsuleBlur.tag = kMMCapsuleBlurTag;
            capsuleBlur.userInteractionEnabled = NO;
            capsuleBlur.clipsToBounds = YES;
            [capsule addSubview:capsuleBlur];
        }
        UIView *capsuleTint = [UIView new];
        capsuleTint.tag = kMMCapsuleTintTag;
        capsuleTint.userInteractionEnabled = NO;
        [capsule addSubview:capsuleTint];
        UIView *capsuleBorder = [UIView new];
        capsuleBorder.tag = kMMCapsuleBorderTag;
        capsuleBorder.userInteractionEnabled = NO;
        [capsule addSubview:capsuleBorder];
    }
    return glass;
}

static UIView *MMEnsureSearch(UIView *root) {
    UIView *host = [root viewWithTag:kMMSearchTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMSearchTag;
        host.userInteractionEnabled = YES;
        [root addSubview:host];
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMSearchBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];
        UIView *tint = [UIView new];
        tint.tag = kMMSearchTintTag;
        tint.userInteractionEnabled = NO;
        [blur.contentView addSubview:tint];
        UIImageView *icon = [UIImageView new];
        icon.tag = kMMSearchIconTag;
        icon.userInteractionEnabled = NO;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [host addSubview:icon];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = [UIColor clearColor];
        [btn addTarget:MMSharedProxy() action:@selector(handleSearchTap:) forControlEvents:UIControlEventTouchUpInside];
        [host addSubview:btn];
    }
    return host;
}

static UIButton *MMEnsureOverlayButton(UIView *root, NSInteger index) {
    UIButton *btn = (UIButton *)[root viewWithTag:kMMOverlayButtonBaseTag + index];
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = kMMOverlayButtonBaseTag + index;
        btn.backgroundColor = [UIColor clearColor];
        btn.exclusiveTouch = YES;
        [btn addTarget:MMSharedProxy() action:@selector(tapTab:) forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:btn];
    }
    return btn;
}

static void MMStyleBackdrop(UIView *backdrop) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[backdrop viewWithTag:kMMBackdropBlurTag];
    blur.frame = backdrop.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(backdrop.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    UIView *tint = [blur.contentView viewWithTag:kMMBackdropTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(backdrop.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.05] : [UIColor colorWithWhite:1.0 alpha:0.12];
}

static void MMStyleGlass(UIView *glass) {
    MMSetRadius(glass, 24.0);
    UIVisualEffectView *blur = (UIVisualEffectView *)[glass viewWithTag:kMMGlassBlurTag];
    blur.frame = glass.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, 24.0);
    UIView *tint = [blur.contentView viewWithTag:kMMGlassTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.18];
    glass.layer.shadowColor = [UIColor blackColor].CGColor;
    glass.layer.shadowOpacity = MMIsDark(glass.traitCollection) ? 0.14 : 0.10;
    glass.layer.shadowRadius = 20.0;
    glass.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    glass.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:glass.bounds cornerRadius:24.0].CGPath;
    UIView *border = [glass viewWithTag:kMMGlassBorderTag];
    border.frame = glass.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.20 : 0.34)].CGColor;
    MMSetRadius(border, 24.0);
    UIView *shine = [glass viewWithTag:kMMGlassShineTag];
    shine.frame = CGRectInset(glass.bounds, 1.0, 1.0);
    MMSetRadius(shine, 23.0);
    CAGradientLayer *g = nil;
    for (CALayer *layer in shine.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) { g = (CAGradientLayer *)layer; break; }
    }
    if (!g) { g = [CAGradientLayer layer]; [shine.layer addSublayer:g]; }
    g.frame = shine.bounds;
    g.startPoint = CGPointMake(0.5, 0.0);
    g.endPoint = CGPointMake(0.5, 1.0);
    g.colors = @[(__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.16 : 0.24)].CGColor, (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor, (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
    g.locations = @[@0.0,@0.20,@0.45];
    g.cornerRadius = 23.0;
}

static void MMStyleCapsule(UIView *capsule, UIView *glass) {
    MMSetRadius(capsule, 20.0);
    UIView *blur = [capsule viewWithTag:kMMCapsuleBlurTag];
    if ([blur isKindOfClass:[UIVisualEffectView class]]) {
        blur.frame = capsule.bounds;
        ((UIVisualEffectView *)blur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        MMSetRadius(blur, 20.0);
    }
    UIView *tint = [capsule viewWithTag:kMMCapsuleTintTag];
    tint.frame = capsule.bounds;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.10] : [UIColor colorWithWhite:1.0 alpha:0.22];
    MMSetRadius(tint, 20.0);
    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.20 : 0.36)].CGColor;
    MMSetRadius(border, 20.0);
}

static CGRect MMComputeGlassFrame(UIViewController *vc, BOOL showSearch) {
    UIView *root = vc.view;
    CGFloat h = CGRectGetHeight(root.bounds);
    CGFloat w = CGRectGetWidth(root.bounds);
    CGFloat safeBottom = root.safeAreaInsets.bottom;
    CGFloat glassH = 58.0;
    CGFloat searchSize = 58.0;
    CGFloat margin = 16.0;
    CGFloat gap = 10.0;
    CGFloat y = h - safeBottom - glassH - 8.0;
    UIView *label = MMFindLabelContainingText(root, @"折叠置顶聊天");
    if (label) {
        UIView *banner = label.superview ?: label;
        UIView *ref = banner.superview ?: root;
        CGRect bannerRect = [ref convertRect:banner.frame toView:root];
        CGFloat minY = CGRectGetMaxY(bannerRect) + 1.0;
        if (y < minY) y = minY;
    }
    CGFloat width = w - margin * 2.0 - (showSearch ? (searchSize + gap) : 0.0);
    return CGRectMake(margin, y, width, glassH);
}

static void MMMakeTabBarTransparent(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 0.01;
    tabBar.userInteractionEnabled = YES;
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
}

static void MMLayoutSearch(UIViewController *vc, CGRect glassFrame) {
    UIView *root = vc.view;
    UIViewController *home = MMFindHomeController(vc);
    UIView *searchBar = home ? MMFindSearchBarInView(home.view) : nil;
    UIView *host = MMEnsureSearch(root);
    if (!searchBar) {
        host.hidden = YES;
        host.alpha = 0.0;
        return;
    }
    CGFloat size = 58.0;
    host.frame = CGRectMake(CGRectGetMaxX(glassFrame) + 10.0, CGRectGetMinY(glassFrame), size, size);
    host.hidden = NO;
    host.alpha = 1.0;
    objc_setAssociatedObject(host.subviews.lastObject, &kMMVCKey, vc, OBJC_ASSOCIATION_ASSIGN);
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMSearchBlurTag];
    blur.frame = host.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, 29.0);
    UIView *tint = [blur.contentView viewWithTag:kMMSearchTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.18];
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = MMIsDark(host.traitCollection) ? 0.14 : 0.10;
    host.layer.shadowRadius = 20.0;
    host.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    host.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:host.bounds cornerRadius:29.0].CGPath;
    MMSetRadius(host, 29.0);
    UIImageView *icon = (UIImageView *)[host viewWithTag:kMMSearchIconTag];
    icon.frame = CGRectMake(16.0, 16.0, 26.0, 26.0);
    icon.tintColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIButton *btn = (UIButton *)host.subviews.lastObject;
    btn.frame = host.bounds;
    [root bringSubviewToFront:host];
}

static void MMLayoutOverlayButtons(UIViewController *vc, UITabBar *tabBar, UIView *glass) {
    NSArray *items = tabBar.items;
    NSArray *itemViews = MMItemViews(tabBar);
    NSInteger count = MIN((NSInteger)items.count, 4);
    if (count <= 0) return;
    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }
    CGFloat sideInset = 10.0;
    CGFloat gap = 2.0;
    CGFloat usableW = CGRectGetWidth(glass.bounds) - sideInset * 2.0 - gap * (count - 1);
    CGFloat slotW = floor(usableW / count);
    CGFloat slotH = CGRectGetHeight(glass.bounds);
    NSArray *fallback = @[@"微信",@"通讯录",@"发现",@"我"];
    for (NSInteger i = 0; i < count; i++) {
        UIButton *btn = MMEnsureOverlayButton(vc.view, i);
        CGFloat x = CGRectGetMinX(glass.frame) + sideInset + i * (slotW + gap);
        CGFloat w = (i == count - 1) ? (CGRectGetMaxX(glass.frame) - sideInset - x) : slotW;
        btn.frame = CGRectMake(x, CGRectGetMinY(glass.frame), w, slotH);
        objc_setAssociatedObject(btn, &kMMVCKey, vc, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(btn, &kMMIndexKey, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        UIView *itemView = i < (NSInteger)itemViews.count ? itemViews[i] : nil;
        UITabBarItem *item = i < (NSInteger)items.count ? items[i] : nil;

        UIImageView *srcIcon = MMFindImageView(itemView);
        UILabel *srcLabel = MMFindLabel(itemView);

        UIImageView *iconView = (UIImageView *)[btn viewWithTag:100 + i];
        UILabel *titleLabel = (UILabel *)[btn viewWithTag:200 + i];
        if (!iconView) {
            iconView = [UIImageView new];
            iconView.tag = 100 + i;
            iconView.contentMode = UIViewContentModeScaleAspectFit;
            iconView.userInteractionEnabled = NO;
            [btn addSubview:iconView];
        }
        if (!titleLabel) {
            titleLabel = [UILabel new];
            titleLabel.tag = 200 + i;
            titleLabel.textAlignment = NSTextAlignmentCenter;
            titleLabel.adjustsFontSizeToFitWidth = YES;
            titleLabel.minimumScaleFactor = 0.6;
            titleLabel.userInteractionEnabled = NO;
            [btn addSubview:titleLabel];
        }

        UIColor *normalColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
        UIColor *selectedColor = [UIColor colorWithRed:0.00 green:0.76 blue:0.30 alpha:1.0];
        UIColor *color = (i == selectedIndex) ? selectedColor : normalColor;

        UIImage *img = srcIcon.image;
        if (!img && item) img = (i == selectedIndex && item.selectedImage) ? item.selectedImage : item.image;
        if (!img && item) {
            @try { img = [item valueForKey:(i == selectedIndex ? @"_selectedImage" : @"_image")]; } @catch (__unused NSException *e) {}
        }
        iconView.image = img ? [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;
        iconView.tintColor = color;

        NSString *title = srcLabel.text;
        if (!title.length && item.title.length) title = item.title;
        if (!title.length && i < 4) title = fallback[i];
        titleLabel.text = title ?: @"";
        titleLabel.textColor = color;
        titleLabel.font = [UIFont systemFontOfSize:11.0 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightRegular)];

        CGFloat iconSize = 21.0;
        CGFloat titleH = 12.0;
        CGFloat contentGap = 2.0;
        CGFloat totalH = iconSize + contentGap + titleH;
        CGFloat top = floor((slotH - totalH) * 0.5);
        if (top < 4.0) top = 4.0;
        iconView.frame = CGRectMake(floor((w - iconSize) * 0.5), top, iconSize, iconSize);
        titleLabel.frame = CGRectMake(0.0, CGRectGetMaxY(iconView.frame) + contentGap, w, titleH);
    }

    UIView *capsule = [glass viewWithTag:kMMCapsuleTag];
    UIButton *selectedBtn = (UIButton *)[vc.view viewWithTag:kMMOverlayButtonBaseTag + selectedIndex];
    if (selectedBtn) {
        CGFloat capH = CGRectGetHeight(glass.bounds) - 10.0;
        CGFloat capW = MIN(CGRectGetWidth(selectedBtn.frame) + 8.0, 64.0);
        CGFloat capX = CGRectGetMidX(selectedBtn.frame) - capW * 0.5 - CGRectGetMinX(glass.frame);
        CGFloat capY = (CGRectGetHeight(glass.bounds) - capH) * 0.5;
        if (capX < 4.0) capX = 4.0;
        if (capX + capW > CGRectGetWidth(glass.bounds) - 4.0) capX = CGRectGetWidth(glass.bounds) - 4.0 - capW;
        capsule.frame = CGRectMake(capX, capY, capW, capH);
        capsule.hidden = NO;
        MMStyleCapsule(capsule, glass);
    } else {
        capsule.hidden = YES;
    }
}

static void MMHideOrShowFloating(UIViewController *vc, BOOL visible) {
    UIView *root = vc.view;
    UIView *backdrop = [root viewWithTag:kMMBackdropTag];
    UIView *glass = [root viewWithTag:kMMGlassTag];
    UIView *search = [root viewWithTag:kMMSearchTag];
    MMSetVisible(backdrop, visible);
    MMSetVisible(glass, visible);
    MMSetVisible(search, visible);
    for (NSInteger i = 0; i < 4; i++) {
        UIView *btn = [root viewWithTag:kMMOverlayButtonBaseTag + i];
        MMSetVisible(btn, visible);
    }
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdating) return;
    kMMUpdating = YES;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!tabBar || !MMShouldShow(vc)) {
        if (tabBar) tabBar.alpha = 1.0;
        MMHideOrShowFloating(vc, NO);
        kMMUpdating = NO;
        return;
    }
    UIViewController *home = MMFindHomeController(vc);
    BOOL showSearch = home ? (MMFindSearchBarInView(home.view) != nil) : NO;
    CGRect glassFrame = MMComputeGlassFrame(vc, showSearch);
    UIView *backdrop = MMEnsureBackdrop(vc.view);
    backdrop.frame = CGRectMake(0.0, CGRectGetMinY(glassFrame) - 8.0, CGRectGetWidth(vc.view.bounds), CGRectGetHeight(vc.view.bounds) - CGRectGetMinY(glassFrame) + 8.0);
    MMStyleBackdrop(backdrop);
    UIView *glass = MMEnsureGlass(vc.view);
    glass.frame = glassFrame;
    MMStyleGlass(glass);
    MMMakeTabBarTransparent(tabBar);
    MMLayoutOverlayButtons(vc, tabBar, glass);
    MMLayoutSearch(vc, glassFrame);
    [vc.view bringSubviewToFront:backdrop];
    [vc.view bringSubviewToFront:glass];
    for (NSInteger i = 0; i < 4; i++) {
        UIView *btn = [vc.view viewWithTag:kMMOverlayButtonBaseTag + i];
        if (btn) [vc.view bringSubviewToFront:btn];
    }
    UIView *search = [vc.view viewWithTag:kMMSearchTag];
    if (search && !search.hidden) [vc.view bringSubviewToFront:search];
    MMHideOrShowFloating(vc, YES);
    kMMUpdating = NO;
}

@implementation MMFloatingProxy
- (void)tapTab:(UIButton *)sender {
    UIViewController *vc = (UIViewController *)objc_getAssociatedObject(sender, &kMMVCKey);
    NSNumber *idxNum = (NSNumber *)objc_getAssociatedObject(sender, &kMMIndexKey);
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!vc || !idxNum || !tabBar) return;
    NSInteger index = idxNum.integerValue;
    if (index < 0 || index >= (NSInteger)tabBar.items.count) return;
    if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
        ((void (*)(id, SEL, NSUInteger))objc_msgSend)(vc, @selector(setSelectedIndex:), (NSUInteger)index);
    }
    tabBar.selectedItem = [tabBar.items objectAtIndex:index];
    MMUpdateFloatingBar(vc);
}
- (void)handleSearchTap:(UIButton *)sender {
    UIViewController *vc = (UIViewController *)objc_getAssociatedObject(sender, &kMMVCKey);
    if (!vc) return;
    UIViewController *home = MMFindHomeController(vc);
    if (!home) home = vc;
    if ([home respondsToSelector:@selector(onTapOnSearchButton)]) {
        ((void (*)(id, SEL))objc_msgSend)(home, @selector(onTapOnSearchButton));
    }
}
@end

static MMFloatingProxy *MMSharedProxy(void) {
    static MMFloatingProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ proxy = [MMFloatingProxy new]; });
    return proxy;
}

%hook MainTabBarViewController
- (void)viewDidLoad { %orig; MMUpdateFloatingBar((UIViewController *)self); }
- (void)viewDidLayoutSubviews { %orig; MMUpdateFloatingBar((UIViewController *)self); }
- (void)viewDidAppear:(BOOL)animated { %orig(animated); MMUpdateFloatingBar((UIViewController *)self); }
- (void)viewSafeAreaInsetsDidChange { %orig; MMUpdateFloatingBar((UIViewController *)self); }
- (void)setSelectedIndex:(NSUInteger)index { %orig(index); MMUpdateFloatingBar((UIViewController *)self); }
- (void)setSelectedViewController:(UIViewController *)selectedViewController { %orig(selectedViewController); MMUpdateFloatingBar((UIViewController *)self); }
%end
