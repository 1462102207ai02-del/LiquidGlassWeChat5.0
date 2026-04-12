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
static char kMMItemViewKey;
static char kMMLockedGlassFrameKey;
static char kMMLastRootSizeKey;

static NSInteger const kMMBackdropTag = 999000;
static NSInteger const kMMBackdropBlurTag = 999001;
static NSInteger const kMMBackdropTintTag = 999002;
static NSInteger const kMMGlassTag = 999003;
static NSInteger const kMMGlassBlurTag = 999004;
static NSInteger const kMMGlassTintTag = 999005;
static NSInteger const kMMGlassBorderTag = 999006;
static NSInteger const kMMGlassShineTag = 999007;
static NSInteger const kMMCapsuleTag = 999008;
static NSInteger const kMMCapsuleBlurTag = 999009;
static NSInteger const kMMCapsuleTintTag = 999010;
static NSInteger const kMMCapsuleBorderTag = 999011;
static NSInteger const kMMSearchTag = 999012;
static NSInteger const kMMSearchBlurTag = 999013;
static NSInteger const kMMSearchTintTag = 999014;
static NSInteger const kMMSearchIconTag = 999015;
static NSInteger const kMMOverlayButtonBaseTag = 999100;

static BOOL kMMUpdating = NO;
static BOOL kMMPrepared = NO;

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static void MMSetVisible(UIView *view, BOOL visible) {
    if (!view) return;
    view.hidden = !visible;
    view.alpha = visible ? 1.0 : 0.0;
}

static void MMSetRadius(UIView *view, CGFloat radius) {
    if (!view) return;
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static UIImageView *MMFindImageView(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:[UIImageView class]]) return (UIImageView *)root;
    for (UIView *sub in root.subviews) {
        UIImageView *found = MMFindImageView(sub);
        if (found) return found;
    }
    return nil;
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

static UIImage *MMBestItemImage(UIView *itemView, UITabBarItem *item, BOOL selected) {
    UIImage *img = nil;
    @try {
        id iv = [itemView valueForKey:@"imageView"];
        if ([iv isKindOfClass:[UIImageView class]]) img = ((UIImageView *)iv).image;
    } @catch (__unused NSException *e) {}
    if (!img) {
        @try {
            id iv = [itemView valueForKey:@"_imageView"];
            if ([iv isKindOfClass:[UIImageView class]]) img = ((UIImageView *)iv).image;
        } @catch (__unused NSException *e) {}
    }
    if (!img) {
        UIImageView *iv = MMFindImageView(itemView);
        img = iv.image;
    }
    if (!img && item) img = selected && item.selectedImage ? item.selectedImage : item.image;
    if (!img && item) {
        @try { img = [item valueForKey:(selected ? @"_selectedImage" : @"_image")]; } @catch (__unused NSException *e) {}
    }
    if (!img && item) {
        @try { img = [item valueForKey:@"_image"]; } @catch (__unused NSException *e) {}
    }
    return img;
}

static NSString *MMBestItemTitle(UIView *itemView, UITabBarItem *item, NSInteger index) {
    NSString *title = nil;
    @try {
        id label = [itemView valueForKey:@"textLabel"];
        if ([label isKindOfClass:[UILabel class]]) title = ((UILabel *)label).text;
    } @catch (__unused NSException *e) {}
    if (!title.length) {
        @try {
            id label = [itemView valueForKey:@"_textLabel"];
            if ([label isKindOfClass:[UILabel class]]) title = ((UILabel *)label).text;
        } @catch (__unused NSException *e) {}
    }
    if (!title.length) {
        UILabel *label = MMFindLabel(itemView);
        title = label.text;
    }
    if (!title.length && item.title.length) title = item.title;
    if (!title.length) {
        NSArray *fallback = @[@"微信", @"通讯录", @"发现", @"我"];
        if (index >= 0 && index < (NSInteger)fallback.count) title = fallback[index];
    }
    return title ?: @"";
}

static UIImage *MMFallbackSymbolImage(NSInteger index) {
    if (![UIImage respondsToSelector:@selector(systemImageNamed:)]) return nil;
    NSArray *names = @[@"message.fill", @"person.2.fill", @"safari.fill", @"person.fill"];
    if (index < 0 || index >= (NSInteger)names.count) return nil;
    UIImage *img = [UIImage systemImageNamed:names[index]];
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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
        if (!root || !top) return NO;
        if (top != root) return NO;
        if (nav.presentedViewController) return NO;
        return YES;
    }

    if ([selected isKindOfClass:[UIViewController class]]) {
        UIViewController *child = (UIViewController *)selected;
        if (child.presentedViewController) return NO;
        return YES;
    }

    return NO;
}

static NSInteger MMCompareViewX(id a, id b, void *context) {
    CGFloat ax = CGRectGetMinX(((UIView *)a).frame);
    CGFloat bx = CGRectGetMinX(((UIView *)b).frame);
    if (ax < bx) return -1;
    if (ax > bx) return 1;
    return 0;
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
        [btn addTarget:MMSharedProxy() action:@selector(tapSearch:) forControlEvents:UIControlEventTouchUpInside];
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
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(backdrop.traitCollection) ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    UIView *tint = [blur.contentView viewWithTag:kMMBackdropTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(backdrop.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.04] : [UIColor colorWithWhite:1.0 alpha:0.10];
}

static void MMStyleGlass(UIView *glass) {
    MMSetRadius(glass, 24.0);
    UIVisualEffectView *blur = (UIVisualEffectView *)[glass viewWithTag:kMMGlassBlurTag];
    blur.frame = glass.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemChromeMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, 24.0);
    UIView *tint = [blur.contentView viewWithTag:kMMGlassTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.22];
    glass.layer.shadowColor = [UIColor blackColor].CGColor;
    glass.layer.shadowOpacity = MMIsDark(glass.traitCollection) ? 0.15 : 0.11;
    glass.layer.shadowRadius = 22.0;
    glass.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    glass.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:glass.bounds cornerRadius:24.0].CGPath;
    UIView *border = [glass viewWithTag:kMMGlassBorderTag];
    border.frame = glass.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.22 : 0.36)].CGColor;
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
    g.colors = @[(__bridge id)[UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.18 : 0.26)].CGColor, (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor, (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
    g.locations = @[@0.0,@0.20,@0.45];
    g.cornerRadius = 23.0;
}

static void MMStyleCapsule(UIView *capsule, UIView *glass) {
    MMSetRadius(capsule, 20.0);
    UIView *blur = [capsule viewWithTag:kMMCapsuleBlurTag];
    if ([blur isKindOfClass:[UIVisualEffectView class]]) {
        blur.frame = capsule.bounds;
        ((UIVisualEffectView *)blur).effect = [UIBlurEffect effectWithStyle:(MMIsDark(glass.traitCollection) ? UIBlurEffectStyleSystemMaterialDark : UIBlurEffectStyleSystemMaterialLight)];
        MMSetRadius(blur, 20.0);
    }
    UIView *tint = [capsule viewWithTag:kMMCapsuleTintTag];
    tint.frame = capsule.bounds;
    tint.backgroundColor = MMIsDark(glass.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.12] : [UIColor colorWithWhite:1.0 alpha:0.26];
    MMSetRadius(tint, 20.0);
    UIView *border = [capsule viewWithTag:kMMCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.8;
    border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:(MMIsDark(glass.traitCollection) ? 0.22 : 0.38)].CGColor;
    MMSetRadius(border, 20.0);
}

static CGRect MMUnlockedGlassFrame(UIViewController *vc, BOOL showSearch) {
    UIView *root = vc.view;
    CGFloat h = CGRectGetHeight(root.bounds);
    CGFloat w = CGRectGetWidth(root.bounds);
    CGFloat safeBottom = root.safeAreaInsets.bottom;
    CGFloat glassH = 58.0;
    CGFloat searchSize = 58.0;
    CGFloat margin = 16.0;
    CGFloat gap = 10.0;

    CGFloat bottomGap = 2.0;
    CGFloat yFromBottom = h - safeBottom - glassH - bottomGap;
    CGFloat y = yFromBottom;

    UIView *label = MMFindLabelContainingText(root, @"折叠置顶聊天");
    if (label) {
        UIView *banner = label;
        while (banner.superview && CGRectGetWidth(banner.bounds) < w * 0.70) {
            banner = banner.superview;
        }
        UIView *ref = banner.superview ?: root;
        CGRect bannerRect = [ref convertRect:banner.frame toView:root];
        CGFloat yFromBanner = CGRectGetMaxY(bannerRect) + 1.0;
        if (yFromBanner > y) y = yFromBanner;
    }

    if (y > yFromBottom) y = yFromBottom;

    CGFloat width = w - margin * 2.0 - (showSearch ? (searchSize + gap) : 0.0);
    return CGRectMake(margin, y, width, glassH);
}

static CGRect MMGlassFrame(UIViewController *vc, BOOL showSearch) {
    CGSize rootSize = vc.view.bounds.size;
    NSValue *sizeValue = objc_getAssociatedObject(vc, &kMMLastRootSizeKey);
    NSValue *frameValue = objc_getAssociatedObject(vc, &kMMLockedGlassFrameKey);

    if (!sizeValue || !CGSizeEqualToSize([sizeValue CGSizeValue], rootSize) || !frameValue) {
        CGRect frame = MMUnlockedGlassFrame(vc, showSearch);
        objc_setAssociatedObject(vc, &kMMLockedGlassFrameKey, [NSValue valueWithCGRect:frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(vc, &kMMLastRootSizeKey, [NSValue valueWithCGSize:rootSize], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return frame;
    }

    CGRect locked = [frameValue CGRectValue];
    CGFloat newWidth = rootSize.width - 16.0 * 2.0 - (showSearch ? (58.0 + 10.0) : 0.0);
    locked.size.width = newWidth;
    locked.origin.x = 16.0;
    objc_setAssociatedObject(vc, &kMMLockedGlassFrameKey, [NSValue valueWithCGRect:locked], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return locked;
}

static void MMInvalidateLockedFrame(UIViewController *vc) {
    objc_setAssociatedObject(vc, &kMMLockedGlassFrameKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, &kMMLastRootSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void MMMakeTabBarTransparent(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 0.001;
    tabBar.userInteractionEnabled = NO;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.translucent = YES;
    tabBar.clipsToBounds = YES;
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        sub.alpha = 0.0;
        if ([name containsString:@"BarBackground"] || [name containsString:@"_UIBarBackground"] || [name containsString:@"Backdrop"] || [name containsString:@"UITabBarButton"]) {
            sub.hidden = YES;
        }
    }
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

static void MMPrepareTabBarEarly(UIViewController *vc) {
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!tabBar) return;
    tabBar.alpha = 0.001;
    tabBar.hidden = NO;
    tabBar.userInteractionEnabled = NO;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        sub.alpha = 0.0;
        if ([name containsString:@"BarBackground"] || [name containsString:@"_UIBarBackground"] || [name containsString:@"Backdrop"] || [name containsString:@"UITabBarButton"]) {
            sub.hidden = YES;
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
    UIButton *searchButton = (UIButton *)host.subviews.lastObject;
    objc_setAssociatedObject(searchButton, &kMMVCKey, vc, OBJC_ASSOCIATION_ASSIGN);
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMSearchBlurTag];
    blur.frame = host.bounds;
    if (@available(iOS 13.0, *)) {
        blur.effect = [UIBlurEffect effectWithStyle:(MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemChromeMaterialDark : UIBlurEffectStyleSystemChromeMaterialLight)];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    }
    MMSetRadius(blur, 29.0);
    UIView *tint = [blur.contentView viewWithTag:kMMSearchTintTag];
    tint.frame = blur.contentView.bounds;
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = MMIsDark(host.traitCollection) ? [UIColor colorWithWhite:1.0 alpha:0.08] : [UIColor colorWithWhite:1.0 alpha:0.20];
    host.layer.shadowColor = [UIColor blackColor].CGColor;
    host.layer.shadowOpacity = MMIsDark(host.traitCollection) ? 0.15 : 0.11;
    host.layer.shadowRadius = 22.0;
    host.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    host.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:host.bounds cornerRadius:29.0].CGPath;
    MMSetRadius(host, 29.0);
    UIImageView *icon = (UIImageView *)[host viewWithTag:kMMSearchIconTag];
    icon.frame = CGRectMake(16.0, 16.0, 26.0, 26.0);
    icon.tintColor = [UIColor colorWithRed:0.42 green:0.44 blue:0.48 alpha:0.92];
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    searchButton.frame = host.bounds;
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
    for (NSInteger i = 0; i < count; i++) {
        UIButton *btn = MMEnsureOverlayButton(vc.view, i);
        CGFloat x = CGRectGetMinX(glass.frame) + sideInset + i * (slotW + gap);
        CGFloat w = (i == count - 1) ? (CGRectGetMaxX(glass.frame) - sideInset - x) : slotW;
        btn.frame = CGRectMake(x, CGRectGetMinY(glass.frame), w, slotH);
        objc_setAssociatedObject(btn, &kMMVCKey, vc, OBJC_ASSOCIATION_ASSIGN);
        objc_setAssociatedObject(btn, &kMMIndexKey, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *itemView = i < (NSInteger)itemViews.count ? [itemViews objectAtIndex:i] : nil;
        objc_setAssociatedObject(btn, &kMMItemViewKey, itemView, OBJC_ASSOCIATION_ASSIGN);
        UITabBarItem *item = i < (NSInteger)items.count ? [items objectAtIndex:i] : nil;
        UIImage *srcImage = MMBestItemImage(itemView, item, i == selectedIndex);
        NSString *srcTitle = MMBestItemTitle(itemView, item, i);
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
        UIImage *img = srcImage;
        if (!img) img = MMFallbackSymbolImage(i);
        iconView.image = img ? [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;
        iconView.tintColor = color;
        titleLabel.text = srcTitle ?: @"";
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
        BOOL animate = !capsule.hidden && fabs(CGRectGetMinX(capsule.frame) - capX) > 0.5;
        void (^updates)(void) = ^{
            capsule.frame = CGRectMake(capX, capY, capW, capH);
        };
        capsule.hidden = NO;
        MMStyleCapsule(capsule, glass);
        if (animate) {
            [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut animations:updates completion:nil];
        } else {
            updates();
        }
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
    backdrop.userInteractionEnabled = NO;
    glass.userInteractionEnabled = NO;
    search.userInteractionEnabled = visible;
    for (NSInteger i = 0; i < 4; i++) {
        UIView *btn = [root viewWithTag:kMMOverlayButtonBaseTag + i];
        MMSetVisible(btn, visible);
        btn.userInteractionEnabled = visible;
    }
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc || kMMUpdating) return;
    kMMUpdating = YES;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!tabBar || !MMShouldShow(vc)) {
        if (tabBar) {
            tabBar.alpha = 0.001;
            tabBar.hidden = NO;
            tabBar.userInteractionEnabled = NO;
            for (UIView *sub in tabBar.subviews) {
                NSString *name = NSStringFromClass([sub class]);
                if ([name containsString:@"BarBackground"] || [name containsString:@"_UIBarBackground"] || [name containsString:@"Backdrop"]) {
                    sub.hidden = YES;
                    sub.alpha = 0.0;
                } else if ([name containsString:@"UITabBarButton"]) {
                    sub.alpha = 0.0;
                    sub.hidden = YES;
                }
            }
        }
        MMHideOrShowFloating(vc, NO);
        kMMUpdating = NO;
        return;
    }
    UIViewController *home = MMFindHomeController(vc);
    BOOL showSearch = home ? (MMFindSearchBarInView(home.view) != nil) : NO;
    CGRect glassFrame = MMGlassFrame(vc, showSearch);
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
    } else {
        tabBar.selectedItem = [tabBar.items objectAtIndex:index];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        MMUpdateFloatingBar(vc);
    });
}

- (void)tapSearch:(UIButton *)sender {
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

- (void)viewDidLoad {
    %orig;
    kMMPrepared = NO;
    MMInvalidateLockedFrame((UIViewController *)self);
    MMPrepareTabBarEarly((UIViewController *)self);
}

- (void)viewWillAppear:(BOOL)animated {
    MMPrepareTabBarEarly((UIViewController *)self);
    MMUpdateFloatingBar((UIViewController *)self);
    %orig(animated);
}

- (void)viewWillLayoutSubviews {
    MMPrepareTabBarEarly((UIViewController *)self);
    MMUpdateFloatingBar((UIViewController *)self);
    %orig;
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdateFloatingBar((UIViewController *)self);
    kMMPrepared = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    MMPrepareTabBarEarly((UIViewController *)self);
    MMUpdateFloatingBar((UIViewController *)self);
    %orig(animated);
    MMPrepareTabBarEarly((UIViewController *)self);
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMInvalidateLockedFrame((UIViewController *)self);
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    MMUpdateFloatingBar((UIViewController *)self);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    MMPrepareTabBarEarly((UIViewController *)self);
    %orig(selectedViewController);
    MMPrepareTabBarEarly((UIViewController *)self);
    MMUpdateFloatingBar((UIViewController *)self);
}

%end


%hook UITabBar
- (void)layoutSubviews {
    %orig;
    self.alpha = 0.001;
    self.userInteractionEnabled = NO;
    self.hidden = NO;
    for (UIView *sub in self.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        sub.alpha = 0.0;
        if ([name containsString:@"BarBackground"] || [name containsString:@"_UIBarBackground"] || [name containsString:@"Backdrop"] || [name containsString:@"UITabBarButton"]) {
            sub.hidden = YES;
        }
    }
}
%end
