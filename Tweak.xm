#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface MainTabBarViewController : UIViewController
- (void)setSelectedIndex:(NSUInteger)index;
@end

@interface MMFloatingActionProxy : NSObject
- (void)handleTabTap:(UIButton *)sender;
- (void)handleSearchTap:(UIButton *)sender;
@end

static MMFloatingActionProxy *MMSharedActionProxy(void);

static char kMMTabVCKey;
static char kMMTabIndexKey;
static char kMMTabBarKey;

static NSInteger const kMMBackdropTag = 997000;
static NSInteger const kMMBackdropBlurTag = 997001;
static NSInteger const kMMBackdropTintTag = 997002;
static NSInteger const kMMGlassTag = 997003;
static NSInteger const kMMGlassBlurTag = 997004;
static NSInteger const kMMGlassTintTag = 997005;
static NSInteger const kMMGlassBorderTag = 997006;
static NSInteger const kMMGlassShineTag = 997007;
static NSInteger const kMMCapsuleTag = 997008;
static NSInteger const kMMCapsuleBlurTag = 997009;
static NSInteger const kMMCapsuleTintTag = 997010;
static NSInteger const kMMCapsuleBorderTag = 997011;
static NSInteger const kMMButtonsHostTag = 997012;
static NSInteger const kMMSearchHostTag = 997013;
static NSInteger const kMMSearchBlurTag = 997014;
static NSInteger const kMMSearchTintTag = 997015;
static NSInteger const kMMSearchIconTag = 997016;
static NSInteger const kMMSearchButtonTag = 997017;

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
    } @catch (__unused NSException *e) {
    }
    for (UIView *sub in vc.view.subviews) {
        if ([sub isKindOfClass:[UITabBar class]]) return (UITabBar *)sub;
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBar"]) return (UITabBar *)sub;
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

static UIImageView *MMFindImageView(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)root;
        if (iv.image) return iv;
    }
    for (UIView *sub in root.subviews) {
        UIImageView *found = MMFindImageView(sub);
        if (found) return found;
    }
    return nil;
}

static UIImage *MMBestImageFromItemView(UIView *itemView) {
    if (!itemView) return nil;
    UIImageView *iv = MMFindImageView(itemView);
    if (iv.image) return iv.image;
    @try {
        id obj = [itemView valueForKey:@"imageView"];
        if ([obj isKindOfClass:[UIImageView class]] && ((UIImageView *)obj).image) return ((UIImageView *)obj).image;
    } @catch (__unused NSException *e) {}
    @try {
        id obj = [itemView valueForKey:@"_imageView"];
        if ([obj isKindOfClass:[UIImageView class]] && ((UIImageView *)obj).image) return ((UIImageView *)obj).image;
    } @catch (__unused NSException *e) {}
    return nil;
}

static UIImage *MMBestImageFromTabBarItem(UITabBarItem *item, BOOL selected) {
    if (!item) return nil;
    UIImage *image = nil;
    if (selected && item.selectedImage) image = item.selectedImage;
    if (!image && item.image) image = item.image;
    if (!image) {
        @try { image = [item valueForKey:(selected ? @"_selectedImage" : @"_image")]; } @catch (__unused NSException *e) {}
    }
    if (!image) {
        @try { image = [item valueForKey:@"_image"]; } @catch (__unused NSException *e) {}
    }
    return image;
}

static UILabel *MMFindLabel(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:[UILabel class]]) return (UILabel *)root;
    for (UIView *sub in root.subviews) {
        UILabel *found = MMFindLabel(sub);
        if (found) return found;
    }
    return nil;
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

static NSArray *MMItemViews(UITabBar *tabBar) {
    NSMutableArray *result = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"UITabBarButton"]) {
            [result addObject:sub];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return result;
}

static UIView *MMEnsureBackdrop(UIView *root) {
    UIView *view = [root viewWithTag:kMMBackdropTag];
    if (!view) {
        view = [UIView new];
        view.tag = kMMBackdropTag;
        view.userInteractionEnabled = NO;
        view.backgroundColor = [UIColor clearColor];
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
        glass.backgroundColor = [UIColor clearColor];
        glass.clipsToBounds = NO;
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
        border.backgroundColor = [UIColor clearColor];
        [glass addSubview:border];
        UIView *shine = [UIView new];
        shine.tag = kMMGlassShineTag;
        shine.userInteractionEnabled = NO;
        shine.backgroundColor = [UIColor clearColor];
        shine.clipsToBounds = YES;
        [glass addSubview:shine];
        UIView *capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
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
        capsuleBorder.backgroundColor = [UIColor clearColor];
        [capsule addSubview:capsuleBorder];
        UIView *buttonsHost = [UIView new];
        buttonsHost.tag = kMMButtonsHostTag;
        buttonsHost.userInteractionEnabled = YES;
        buttonsHost.backgroundColor = [UIColor clearColor];
        [glass addSubview:buttonsHost];
    }
    return glass;
}

static UIView *MMEnsureSearchHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMSearchHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMSearchHostTag;
        host.userInteractionEnabled = YES;
        host.backgroundColor = [UIColor clearColor];
        host.clipsToBounds = NO;
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
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = kMMSearchButtonTag;
        button.backgroundColor = [UIColor clearColor];
        [button addTarget:MMSharedActionProxy() action:@selector(handleSearchTap:) forControlEvents:UIControlEventTouchUpInside];
        [host addSubview:button];
    }
    return host;
}

static UIButton *MMEnsureTabButton(UIView *host, NSInteger index) {
    UIButton *button = (UIButton *)[host viewWithTag:8000 + index];
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = 8000 + index;
        button.backgroundColor = [UIColor clearColor];
        button.adjustsImageWhenHighlighted = NO;
        button.exclusiveTouch = YES;
        [button addTarget:MMSharedActionProxy() action:@selector(handleTabTap:) forControlEvents:UIControlEventTouchUpInside];
        UIImageView *iconView = [UIImageView new];
        iconView.tag = 100 + index;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.userInteractionEnabled = NO;
        [button addSubview:iconView];
        UILabel *titleLabel = [UILabel new];
        titleLabel.tag = 200 + index;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.6;
        titleLabel.userInteractionEnabled = NO;
        [button addSubview:titleLabel];
        [host addSubview:button];
    }
    return button;
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
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, CGRectGetHeight(glass.bounds) * 0.5);
    UIView *tint = [blur.contentView viewWithTag:kMMGlassTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.18];
    glass.layer.shadowColor = [UIColor blackColor].CGColor;
    glass.layer.shadowOpacity = MMIsDark(glass.traitCollection) ? 0.14 : 0.10;
    glass.layer.shadowRadius = 20.0;
    glass.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    glass.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:glass.bounds cornerRadius:CGRectGetHeight(glass.bounds) * 0.5].CGPath;
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
    g.colors = @[(__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.16 : 0.24)].CGColor, (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor, (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
    g.locations = @[@0.0, @0.20, @0.45];
    g.cornerRadius = CGRectGetHeight(shine.bounds) * 0.5;
}

static void MMStyleCapsule(UIView *capsule, UIView *glass) {
    MMSetRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);
    UIView *capsuleBlur = [capsule viewWithTag:kMMCapsuleBlurTag];
    if ([capsuleBlur isKindOfClass:[UIVisualEffectView class]]) {
        capsuleBlur.frame = capsule.bounds;
        ((UIVisualEffectView *)capsuleBlur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
        MMSetRadius(capsuleBlur, CGRectGetHeight(capsule.bounds) * 0.5);
    }
    UIView *capsuleTint = [capsule viewWithTag:kMMCapsuleTintTag];
    capsuleTint.frame = capsule.bounds;
    capsuleTint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.16];
    MMSetRadius(capsuleTint, CGRectGetHeight(capsuleTint.bounds) * 0.5);
    UIView *capsuleBorder = [capsule viewWithTag:kMMCapsuleBorderTag];
    capsuleBorder.frame = capsule.bounds;
    capsuleBorder.layer.borderWidth = 0.8;
    capsuleBorder.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.18 : 0.30)].CGColor;
    MMSetRadius(capsuleBorder, CGRectGetHeight(capsuleBorder.bounds) * 0.5);
}

static CGRect MMComputeGlassFrame(UIViewController *vc, BOOL showSearch) {
    UIView *root = vc.view;
    CGFloat screenW = CGRectGetWidth(root.bounds);
    CGFloat screenH = CGRectGetHeight(root.bounds);
    CGFloat safeBottom = root.safeAreaInsets.bottom;
    CGFloat glassHeight = 58.0;
    CGFloat searchSize = 58.0;
    CGFloat margin = 16.0;
    CGFloat gap = 10.0;
    CGFloat y = screenH - safeBottom - glassHeight - 8.0;
    UIView *label = MMFindLabelContainingText(root, @"折叠置顶聊天");
    if (label) {
        UIView *banner = label.superview ?: label;
        UIView *ref = banner.superview ?: root;
        CGRect bannerRect = [ref convertRect:banner.frame toView:root];
        CGFloat minY = CGRectGetMaxY(bannerRect) + 1.0;
        if (y < minY) y = minY;
    }
    CGFloat width = screenW - margin * 2.0 - (showSearch ? (searchSize + gap) : 0.0);
    return CGRectMake(margin, y, width, glassHeight);
}

static void MMHideOriginalTabBar(UITabBar *tabBar) {
    tabBar.alpha = 0.01;
    tabBar.hidden = NO;
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
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"BarBackground"] || [name containsString:@"_UIBarBackground"] || [name containsString:@"Backdrop"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
    }
}

static void MMUpdateOverlayButtons(UIViewController *vc, UITabBar *tabBar, UIView *glass) {
    UIView *host = [glass viewWithTag:kMMButtonsHostTag];
    host.frame = glass.bounds;
    NSArray *items = tabBar.items;
    NSArray *itemViews = MMItemViews(tabBar);
    NSInteger count = MIN((NSInteger)items.count, (NSInteger)itemViews.count);
    if (count <= 0) return;
    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }
    CGFloat sideInset = 10.0;
    CGFloat interGap = 2.0;
    CGFloat usableW = CGRectGetWidth(host.bounds) - sideInset * 2.0 - interGap * (count - 1);
    CGFloat slotW = floor(usableW / count);
    CGFloat slotH = CGRectGetHeight(host.bounds);
    for (NSInteger i = 0; i < count; i++) {
        UIButton *button = MMEnsureTabButton(host, i);
        CGFloat x = sideInset + i * (slotW + interGap);
        CGFloat w = (i == count - 1) ? (CGRectGetWidth(host.bounds) - sideInset - x) : slotW;
        button.frame = CGRectMake(x, 0.0, w, slotH);
        objc_setAssociatedObject(button, &kMMTabVCKey, vc, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(button, &kMMTabBarKey, tabBar, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(button, &kMMTabIndexKey, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *itemView = [itemViews objectAtIndex:i];
        UILabel *srcLabel = MMFindLabel(itemView);
        UIImageView *srcIcon = MMFindImageView(itemView);
        UIColor *normalColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
        UIColor *selectedColor = [UIColor colorWithRed:0.00 green:0.76 blue:0.30 alpha:1.0];
        UIColor *color = (i == selectedIndex) ? selectedColor : normalColor;
        UIImageView *iconView = (UIImageView *)[button viewWithTag:100 + i];
        UILabel *titleLabel = (UILabel *)[button viewWithTag:200 + i];
        UIImage *image = MMBestImageFromItemView(itemView);
        if (!image) {
            UITabBarItem *item = [items objectAtIndex:i];
            image = MMBestImageFromTabBarItem(item, i == selectedIndex);
        }
        iconView.image = image ? [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;
        iconView.tintColor = color;
        NSString *title = srcLabel.text;
        if (!title.length) {
            UITabBarItem *item = [items objectAtIndex:i];
            title = item.title ?: @"";
        }
        titleLabel.text = title;
        titleLabel.textColor = color;
        titleLabel.font = [UIFont systemFontOfSize:11.0 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightRegular)];
        CGFloat iconSize = 21.0;
        CGFloat titleH = 12.0;
        CGFloat gap = 2.0;
        CGFloat totalH = iconSize + gap + titleH;
        CGFloat top = floor((slotH - totalH) * 0.5);
        if (top < 4.0) top = 4.0;
        iconView.frame = CGRectMake(floor((w - iconSize) * 0.5), top, iconSize, iconSize);
        titleLabel.frame = CGRectMake(0.0, CGRectGetMaxY(iconView.frame) + gap, w, titleH);
    }
    UIView *capsule = [glass viewWithTag:kMMCapsuleTag];
    UIButton *selectedButton = (UIButton *)[host viewWithTag:8000 + selectedIndex];
    if (selectedButton) {
        CGFloat capH = CGRectGetHeight(glass.bounds) - 10.0;
        CGFloat capW = MIN(CGRectGetWidth(selectedButton.frame) + 8.0, 62.0);
        CGFloat capX = CGRectGetMidX(selectedButton.frame) - capW * 0.5;
        CGFloat capY = (CGRectGetHeight(glass.bounds) - capH) * 0.5;
        if (capX < 4.0) capX = 4.0;
        if (capX + capW > CGRectGetWidth(glass.bounds) - 4.0) capX = CGRectGetWidth(glass.bounds) - 4.0 - capW;
        capsule.frame = CGRectMake(capX, capY, capW, capH);
        capsule.hidden = NO;
        MMStyleCapsule(capsule, glass);
    } else {
        capsule.hidden = YES;
    }
    [glass bringSubviewToFront:capsule];
    [glass bringSubviewToFront:host];
}

static void MMUpdateSearchHost(UIViewController *vc, CGRect glassFrame) {
    UIView *root = vc.view;
    UIViewController *home = MMFindHomeController(vc);
    UIView *searchBar = home ? MMFindSearchBarInView(home.view) : nil;
    UIView *host = MMEnsureSearchHost(root);
    if (!searchBar) {
        host.hidden = YES;
        host.alpha = 0.0;
        return;
    }
    CGFloat size = 58.0;
    CGFloat gap = 10.0;
    host.frame = CGRectMake(CGRectGetMaxX(glassFrame) + gap, CGRectGetMinY(glassFrame), size, size);
    host.hidden = NO;
    host.alpha = 1.0;
    objc_setAssociatedObject([host viewWithTag:kMMSearchButtonTag], &kMMTabVCKey, vc, OBJC_ASSOCIATION_ASSIGN);
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMSearchBlurTag];
    blur.frame = host.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemThinMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, size * 0.5);
    UIView *tint = [blur.contentView viewWithTag:kMMSearchTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.06] : [UIColor colorWithWhite:1.0 alpha:0.10];
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = MMIsDark(host.traitCollection) ? 0.12 : 0.08;
    host.layer.shadowRadius = 18.0;
    host.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    host.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:host.bounds cornerRadius:size * 0.5].CGPath;
    MMSetRadius(host, size * 0.5);
    UIImageView *icon = (UIImageView *)[host viewWithTag:kMMSearchIconTag];
    icon.frame = CGRectMake(floor((size - 26.0) * 0.5), floor((size - 26.0) * 0.5), 26.0, 26.0);
    icon.tintColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        icon.image = nil;
    }
    UIButton *button = (UIButton *)[host viewWithTag:kMMSearchButtonTag];
    button.frame = host.bounds;
    [root bringSubviewToFront:host];
}

static void MMSetVisible(UIView *view, BOOL visible) {
    if (!view) return;
    view.hidden = !visible;
    view.alpha = visible ? 1.0 : 0.0;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdating) return;
    kMMUpdating = YES;
    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    UIView *backdrop = MMEnsureBackdrop(root);
    UIView *glass = MMEnsureGlass(root);
    UIView *searchHost = MMEnsureSearchHost(root);
    if (!root || !tabBar || !MMShouldShowFloatingBar(vc)) {
        MMSetVisible(backdrop, NO);
        MMSetVisible(glass, NO);
        MMSetVisible(searchHost, NO);
        if (tabBar) tabBar.alpha = 1.0;
        kMMUpdating = NO;
        return;
    }
    UIViewController *home = MMFindHomeController(vc);
    BOOL showSearch = home ? (MMFindSearchBarInView(home.view) != nil) : NO;
    CGRect glassFrame = MMComputeGlassFrame(vc, showSearch);
    backdrop.frame = CGRectMake(0.0, CGRectGetMinY(glassFrame) - 8.0, CGRectGetWidth(root.bounds), CGRectGetHeight(root.bounds) - CGRectGetMinY(glassFrame) + 8.0);
    MMStyleBackdrop(backdrop);
    glass.frame = glassFrame;
    MMStyleGlass(glass);
    MMHideOriginalTabBar(tabBar);
    MMUpdateOverlayButtons(vc, tabBar, glass);
    MMUpdateSearchHost(vc, glassFrame);
    [root bringSubviewToFront:backdrop];
    [root bringSubviewToFront:glass];
    [root bringSubviewToFront:searchHost];
    MMSetVisible(backdrop, YES);
    MMSetVisible(glass, YES);
    kMMUpdating = NO;
}

@implementation MMFloatingActionProxy
- (void)handleTabTap:(UIButton *)sender {
    UIViewController *vc = (UIViewController *)objc_getAssociatedObject(sender, &kMMTabVCKey);
    UITabBar *tabBar = (UITabBar *)objc_getAssociatedObject(sender, &kMMTabBarKey);
    NSNumber *idxNum = (NSNumber *)objc_getAssociatedObject(sender, &kMMTabIndexKey);
    if (!vc || !tabBar || !idxNum) return;
    NSInteger index = idxNum.integerValue;
    if (index < 0 || index >= (NSInteger)tabBar.items.count) return;
    if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
        ((void (*)(id, SEL, NSUInteger))objc_msgSend)(vc, @selector(setSelectedIndex:), (NSUInteger)index);
    }
    tabBar.selectedItem = [tabBar.items objectAtIndex:index];
    MMUpdateFloatingBar(vc);
}
- (void)handleSearchTap:(UIButton *)sender {
    UIViewController *vc = (UIViewController *)objc_getAssociatedObject(sender, &kMMTabVCKey);
    if (!vc) return;
    UIViewController *home = MMFindHomeController(vc);
    if (!home) home = vc;
    if ([home respondsToSelector:@selector(onTapOnSearchButton)]) {
        ((void (*)(id, SEL))objc_msgSend)(home, @selector(onTapOnSearchButton));
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

%hook MainTabBarViewController
- (void)viewDidLoad { %orig; MMUpdateFloatingBar((UIViewController *)self); }
- (void)viewDidLayoutSubviews { %orig; MMUpdateFloatingBar((UIViewController *)self); }
- (void)viewDidAppear:(BOOL)animated { %orig(animated); MMUpdateFloatingBar((UIViewController *)self); }
- (void)viewSafeAreaInsetsDidChange { %orig; MMUpdateFloatingBar((UIViewController *)self); }
- (void)setSelectedIndex:(NSUInteger)index { %orig(index); MMUpdateFloatingBar((UIViewController *)self); }
- (void)setSelectedViewController:(UIViewController *)selectedViewController { %orig(selectedViewController); MMUpdateFloatingBar((UIViewController *)self); }
%end
