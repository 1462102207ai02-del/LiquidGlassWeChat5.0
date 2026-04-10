#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSInteger const kMMFloatingHostTag = 992001;
static NSInteger const kMMFloatingBackdropTag = 992002;
static NSInteger const kMMFloatingBackdropTintTag = 992003;
static NSInteger const kMMFloatingBarBlurTag = 992004;
static NSInteger const kMMFloatingBarTag = 992005;
static NSInteger const kMMFloatingCapsuleTag = 992006;
static NSInteger const kMMFloatingSearchTag = 992007;
static NSInteger const kMMFloatingButtonBaseTag = 992100;
static NSInteger const kMMFloatingButtonImageBaseTag = 992200;
static NSInteger const kMMFloatingButtonLabelBaseTag = 992300;
static NSInteger const kMMFloatingSearchIconTag = 992400;
static NSInteger const kMMFloatingBarBorderTag = 992500;
static NSInteger const kMMFloatingCapsuleBorderTag = 992501;
static NSInteger const kMMFloatingSearchBorderTag = 992502;
static NSInteger const kMMFloatingBarGlowTag = 992503;
static NSInteger const kMMFloatingCapsuleGlowTag = 992504;
static char kMMFloatingIndexKey;

@interface UIView (MMFind)
- (UIView *)mm_findSubviewPassing:(BOOL(^)(UIView *view))block;
@end

@implementation UIView (MMFind)
- (UIView *)mm_findSubviewPassing:(BOOL(^)(UIView *view))block {
    if (!block) return nil;
    if (block(self)) return self;
    for (UIView *subview in self.subviews) {
        UIView *found = [subview mm_findSubviewPassing:block];
        if (found) return found;
    }
    return nil;
}
@end

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static BOOL MMIsDark(UITraitCollection *trait) {
    if (!trait) return NO;
    if ([trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static void MMSetContinuousRadius(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static UIView *MMEnsureView(UIView *parent, NSInteger tag) {
    UIView *view = [parent viewWithTag:tag];
    if (!view) {
        view = [[UIView alloc] initWithFrame:CGRectZero];
        view.tag = tag;
        [parent addSubview:view];
    }
    return view;
}

static UIControl *MMEnsureControl(UIView *parent, NSInteger tag) {
    UIControl *control = (UIControl *)[parent viewWithTag:tag];
    if (![control isKindOfClass:[UIControl class]]) {
        control = [[UIControl alloc] initWithFrame:CGRectZero];
        control.tag = tag;
        control.backgroundColor = UIColor.clearColor;
        [parent addSubview:control];
    }
    return control;
}

static UIImageView *MMEnsureImageView(UIView *parent, NSInteger tag) {
    UIImageView *view = (UIImageView *)[parent viewWithTag:tag];
    if (![view isKindOfClass:[UIImageView class]]) {
        view = [[UIImageView alloc] initWithFrame:CGRectZero];
        view.tag = tag;
        view.contentMode = UIViewContentModeScaleAspectFit;
        [parent addSubview:view];
    }
    return view;
}

static UILabel *MMEnsureLabel(UIView *parent, NSInteger tag) {
    UILabel *label = (UILabel *)[parent viewWithTag:tag];
    if (![label isKindOfClass:[UILabel class]]) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.tag = tag;
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = UIColor.clearColor;
        [parent addSubview:label];
    }
    return label;
}

static CAShapeLayer *MMEnsureShapeBorder(UIView *parent, NSInteger tag) {
    UIView *container = MMEnsureView(parent, tag);
    container.userInteractionEnabled = NO;
    container.frame = parent.bounds;
    CAShapeLayer *layer = (CAShapeLayer *)container.layer.sublayers.firstObject;
    if (![layer isKindOfClass:[CAShapeLayer class]]) {
        layer = [CAShapeLayer layer];
        [container.layer addSublayer:layer];
    }
    layer.frame = container.bounds;
    return layer;
}

static CAGradientLayer *MMEnsureGlow(UIView *parent, NSInteger tag) {
    UIView *container = MMEnsureView(parent, tag);
    container.userInteractionEnabled = NO;
    container.frame = parent.bounds;
    container.clipsToBounds = YES;
    MMSetContinuousRadius(container, CGRectGetHeight(parent.bounds) * 0.5);
    CAGradientLayer *layer = (CAGradientLayer *)container.layer.sublayers.firstObject;
    if (![layer isKindOfClass:[CAGradientLayer class]]) {
        layer = [CAGradientLayer layer];
        [container.layer addSublayer:layer];
    }
    layer.frame = container.bounds;
    layer.cornerRadius = CGRectGetHeight(container.bounds) * 0.5;
    return layer;
}

static UITabBar *MMFindTabBar(UIViewController *vc) {
    if ([vc isKindOfClass:[UITabBarController class]]) {
        return ((UITabBarController *)vc).tabBar;
    }
    UIView *found = [vc.view mm_findSubviewPassing:^BOOL(UIView *view) {
        return [view isKindOfClass:[UITabBar class]];
    }];
    return [found isKindOfClass:[UITabBar class]] ? (UITabBar *)found : nil;
}

static UIViewController *MMResolveMainTabBarController(UIViewController *vc) {
    UIViewController *current = vc;
    while (current) {
        if ([NSStringFromClass(current.class) isEqualToString:@"MainTabBarViewController"]) return current;
        current = current.parentViewController;
    }
    UITabBarController *tabVC = vc.tabBarController;
    if ([NSStringFromClass(tabVC.class) isEqualToString:@"MainTabBarViewController"]) return tabVC;
    return nil;
}

static BOOL MMShouldShowOnlyOnHomeRoot(UIViewController *vc) {
    UIViewController *mainVC = MMResolveMainTabBarController(vc);
    if (!mainVC) return NO;
    if (vc == mainVC) return YES;
    UIViewController *selected = nil;
    @try {
        selected = [mainVC valueForKey:@"selectedViewController"];
    } @catch (__unused NSException *e) {}
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        UIViewController *top = nav.topViewController ?: nav.visibleViewController;
        UIViewController *root = nav.viewControllers.count > 0 ? nav.viewControllers.firstObject : nil;
        return (vc == top && top == root);
    }
    return (vc == selected);
}

static void MMHideFloatingIfExists(UIViewController *vc) {
    UIView *root = vc.view;
    UIView *host = [root viewWithTag:kMMFloatingHostTag];
    UIView *backdrop = [root viewWithTag:kMMFloatingBackdropTag];
    if (host) { host.hidden = YES; host.alpha = 0.0; host.userInteractionEnabled = NO; }
    if (backdrop) { backdrop.hidden = YES; backdrop.alpha = 0.0; }
}

static void MMCollectImageViews(UIView *view, NSMutableArray<UIImageView *> *result) {
    if ([view isKindOfClass:[UIImageView class]] && ((UIImageView *)view).image) {
        [result addObject:(UIImageView *)view];
    }
    for (UIView *sub in view.subviews) {
        MMCollectImageViews(sub, result);
    }
}

static UIImageView *MMBestImageViewInTabButton(UIView *button) {
    NSMutableArray<UIImageView *> *candidates = [NSMutableArray array];
    MMCollectImageViews(button, candidates);
    UIImageView *best = nil;
    CGFloat bestScore = -CGFLOAT_MAX;
    for (UIImageView *iv in candidates) {
        CGRect f = [iv.superview convertRect:iv.frame toView:button];
        CGFloat w = CGRectGetWidth(f);
        CGFloat h = CGRectGetHeight(f);
        CGFloat score = 0.0;
        if (w >= 16.0 && w <= 40.0 && h >= 16.0 && h <= 40.0) score += 100.0;
        score -= fabs(w - 26.0) * 2.0;
        score -= fabs(h - 26.0) * 2.0;
        score -= fabs(CGRectGetMidY(f) - 20.0);
        score += iv.alpha * 5.0;
        if (score > bestScore) { bestScore = score; best = iv; }
    }
    return best;
}

static NSArray<UIControl *> *MMTabBarItemViews(UITabBar *tabBar) {
    NSMutableArray<UIControl *> *result = [NSMutableArray array];
    for (UIView *subview in tabBar.subviews) {
        if ([subview isKindOfClass:[UIControl class]]) {
            NSString *name = NSStringFromClass(subview.class);
            if ([name containsString:@"TabBarButton"]) {
                [result addObject:(UIControl *)subview];
            }
        }
    }
    [result sortUsingComparator:^NSComparisonResult(UIControl *a, UIControl *b) {
        CGFloat x1 = CGRectGetMinX(a.frame);
        CGFloat x2 = CGRectGetMinX(b.frame);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return result;
}

static UIView *MMImageViewInTabButton(UIView *button) {
    return MMBestImageViewInTabButton(button);
}

static UILabel *MMLabelInTabButton(UIView *button) {
    UIView *view = [button mm_findSubviewPassing:^BOOL(UIView *v) {
        return [v isKindOfClass:[UILabel class]];
    }];
    return [view isKindOfClass:[UILabel class]] ? (UILabel *)view : nil;
}

static UIImage *MMOriginalImage(UIImage *image) {
    if (!image) return nil;
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static UIColor *MMNormalTextColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.92) : MMRGBA(78, 84, 96, 0.98);
}

static UIColor *MMBarStrokeColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.16) : MMRGBA(255, 255, 255, 0.52);
}

static UIColor *MMCapsuleStrokeColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.22) : MMRGBA(255, 255, 255, 0.72);
}

static UIColor *MMSearchStrokeColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.18) : MMRGBA(255, 255, 255, 0.58);
}

static void MMHideOriginalTabBarBackground(UITabBar *tabBar) {
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = UIColor.clearColor;
    if ([UITabBarAppearance class]) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;
        if ([tabBar respondsToSelector:@selector(setStandardAppearance:)]) {
            tabBar.standardAppearance = appearance;
        }
        if ([tabBar respondsToSelector:@selector(setScrollEdgeAppearance:)]) {
            ((void (*)(id, SEL, id))objc_msgSend)(tabBar, @selector(setScrollEdgeAppearance:), appearance);
        }
    }
    UIView *bg = [tabBar mm_findSubviewPassing:^BOOL(UIView *view) {
        NSString *name = NSStringFromClass(view.class);
        return [name containsString:@"Background"];
    }];
    bg.hidden = YES;
}

static CGRect MMNativeContainerFrame(UITabBar *tabBar, UIView *root) {
    if (tabBar.superview) {
        return [tabBar.superview convertRect:tabBar.frame toView:root];
    }
    return tabBar.frame;
}

static UIImage *MMSearchSymbol(BOOL dark) {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config];
    if (!image) image = [UIImage systemImageNamed:@"magnifyingglass"];
    UIColor *color = dark ? UIColor.whiteColor : MMRGBA(92, 97, 108, 0.88);
    if ([image respondsToSelector:@selector(imageWithTintColor:renderingMode:)]) {
        return [image imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return image;
}

static void MMApplyMaterialBlur(UIVisualEffectView *view, BOOL dark, CGFloat radius, CGFloat alpha) {
    view.effect = [UIBlurEffect effectWithStyle:(dark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight)];
    view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:alpha];
    MMSetContinuousRadius(view, radius);
    view.clipsToBounds = YES;
    view.userInteractionEnabled = NO;
}

static void MMApplyBarStyle(UIView *bar, BOOL dark) {
    bar.backgroundColor = dark ? MMRGBA(118, 124, 136, 0.20) : MMRGBA(245, 250, 255, 0.30);
    MMSetContinuousRadius(bar, CGRectGetHeight(bar.bounds) * 0.5);

    CAShapeLayer *border = MMEnsureShapeBorder(bar, kMMFloatingBarBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bar.bounds, 0.35, 0.35) cornerRadius:CGRectGetHeight(bar.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = MMBarStrokeColor(dark).CGColor;
    border.lineWidth = 0.85;

    CAGradientLayer *glow = MMEnsureGlow(bar, kMMFloatingBarGlowTag);
    glow.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.52].CGColor,
        (__bridge id)[UIColor colorWithRed:(219.0 / 255.0) green:(234.0 / 255.0) blue:(255.0 / 255.0) alpha:0.28].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor
    ];
    glow.startPoint = CGPointMake(0.0, 0.0);
    glow.endPoint = CGPointMake(1.0, 1.0);
}

static void MMApplyCapsuleStyle(UIView *capsule, BOOL dark) {
    capsule.backgroundColor = dark ? MMRGBA(246, 249, 252, 0.12) : MMRGBA(255, 255, 255, 0.34);
    MMSetContinuousRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    CAShapeLayer *border = MMEnsureShapeBorder(capsule, kMMFloatingCapsuleBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(capsule.bounds, 0.3, 0.3) cornerRadius:CGRectGetHeight(capsule.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = MMCapsuleStrokeColor(dark).CGColor;
    border.lineWidth = 0.95;

    CAGradientLayer *glow = MMEnsureGlow(capsule, kMMFloatingCapsuleGlowTag);
    glow.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.88].CGColor,
        (__bridge id)[UIColor colorWithRed:(233.0 / 255.0) green:(244.0 / 255.0) blue:(255.0 / 255.0) alpha:0.42].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor
    ];
    glow.startPoint = CGPointMake(0.0, 0.0);
    glow.endPoint = CGPointMake(1.0, 1.0);
}

static void MMApplySearchStyle(UIView *dock, BOOL dark) {
    dock.backgroundColor = dark ? MMRGBA(118, 124, 136, 0.20) : MMRGBA(245, 250, 255, 0.30);
    MMSetContinuousRadius(dock, CGRectGetHeight(dock.bounds) * 0.5);

    CAShapeLayer *border = MMEnsureShapeBorder(dock, kMMFloatingSearchBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(dock.bounds, 0.35, 0.35) cornerRadius:CGRectGetHeight(dock.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = MMSearchStrokeColor(dark).CGColor;
    border.lineWidth = 0.85;
}

static BOOL MMTriggerTopSearch(UIView *root) {
    UIView *search = [root mm_findSubviewPassing:^BOOL(UIView *view) {
        if (CGRectGetMinY(view.frame) > 180.0) return NO;
        if ([view isKindOfClass:[UISearchBar class]]) return YES;
        if ([view isKindOfClass:[UITextField class]]) return YES;
        if ([view isKindOfClass:[UIControl class]]) {
            NSString *name = NSStringFromClass(view.class).lowercaseString;
            if ([name containsString:@"search"]) return YES;
        }
        return NO;
    }];
    if ([search isKindOfClass:[UITextField class]]) {
        return [(UITextField *)search becomeFirstResponder];
    }
    if ([search isKindOfClass:[UISearchBar class]]) {
        return [[(UISearchBar *)search valueForKey:@"searchField"] becomeFirstResponder];
    }
    if ([search isKindOfClass:[UIControl class]]) {
        [(UIControl *)search sendActionsForControlEvents:UIControlEventTouchUpInside];
        return YES;
    }
    return NO;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc.isViewLoaded) return;
    if (!MMShouldShowOnlyOnHomeRoot(vc)) {
        MMHideFloatingIfExists(vc);
        return;
    }
    UIViewController *mainVC = MMResolveMainTabBarController(vc) ?: vc;
    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(mainVC);
    if (!root || !tabBar || tabBar.items.count == 0) {
        MMHideFloatingIfExists(vc);
        return;
    }

    MMHideOriginalTabBarBackground(tabBar);

    CGRect container = MMNativeContainerFrame(tabBar, root);
    if (CGRectIsEmpty(container)) return;

    BOOL dark = MMIsDark(root.traitCollection);

    UIView *host = MMEnsureView(root, kMMFloatingHostTag);
    host.frame = container;
    host.backgroundColor = UIColor.clearColor;
    host.userInteractionEnabled = YES;
    host.hidden = NO;
    [root bringSubviewToFront:host];

    UIVisualEffectView *backdrop = (UIVisualEffectView *)MMEnsureView(host, kMMFloatingBackdropTag);
    if (![backdrop isKindOfClass:[UIVisualEffectView class]]) {
        [backdrop removeFromSuperview];
        backdrop = [[UIVisualEffectView alloc] initWithFrame:CGRectZero];
        backdrop.tag = kMMFloatingBackdropTag;
        backdrop.userInteractionEnabled = NO;
        [host addSubview:backdrop];
    }
    backdrop.frame = host.bounds;
    MMApplyMaterialBlur(backdrop, dark, 0.0, dark ? 0.03 : 0.12);
    backdrop.layer.cornerRadius = 0.0;

    UIView *backdropTint = MMEnsureView(host, kMMFloatingBackdropTintTag);
    backdropTint.frame = host.bounds;
    backdropTint.backgroundColor = dark ? MMRGBA(255, 255, 255, 0.012) : MMRGBA(196, 223, 255, 0.22);
    backdropTint.userInteractionEnabled = NO;

    CGFloat sideMargin = 14.0;
    CGFloat gap = 14.0;
    CGFloat searchSize = 64.0;
    CGFloat barHeight = 64.0;
    CGFloat verticalLift = 3.0;
    CGFloat barY = floor((CGRectGetHeight(container) - barHeight) * 0.5) - verticalLift;
    CGFloat searchY = floor((CGRectGetHeight(container) - searchSize) * 0.5) - verticalLift;
    CGFloat barX = sideMargin;
    CGFloat barWidth = CGRectGetWidth(container) - sideMargin * 2.0 - searchSize - gap;
    CGFloat searchX = CGRectGetWidth(container) - sideMargin - searchSize;

    UIVisualEffectView *barBlur = (UIVisualEffectView *)MMEnsureView(host, kMMFloatingBarBlurTag);
    if (![barBlur isKindOfClass:[UIVisualEffectView class]]) {
        [barBlur removeFromSuperview];
        barBlur = [[UIVisualEffectView alloc] initWithFrame:CGRectZero];
        barBlur.tag = kMMFloatingBarBlurTag;
        barBlur.userInteractionEnabled = NO;
        [host addSubview:barBlur];
    }
    barBlur.frame = CGRectMake(barX, barY, barWidth, barHeight);
    MMApplyMaterialBlur(barBlur, dark, barHeight * 0.5, dark ? 0.025 : 0.10);

    UIView *bar = MMEnsureView(host, kMMFloatingBarTag);
    bar.frame = CGRectMake(barX, barY, barWidth, barHeight);
    bar.userInteractionEnabled = YES;
    MMApplyBarStyle(bar, dark);

    UIView *dock = MMEnsureView(host, kMMFloatingSearchTag);
    dock.frame = CGRectMake(searchX, searchY, searchSize, searchSize);
    dock.userInteractionEnabled = YES;
    MMApplySearchStyle(dock, dark);

    UIControl *searchButton = MMEnsureControl(dock, kMMFloatingSearchIconTag + 100);
    searchButton.frame = dock.bounds;
    [searchButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    if ([vc respondsToSelector:@selector(mm_floatingSearchTapped:)]) {
        [searchButton addTarget:vc action:@selector(mm_floatingSearchTapped:) forControlEvents:UIControlEventTouchUpInside];
    }

    UIImageView *searchIcon = MMEnsureImageView(dock, kMMFloatingSearchIconTag);
    searchIcon.image = MMSearchSymbol(dark);
    searchIcon.frame = CGRectMake(floor((searchSize - 30.0) * 0.5), floor((searchSize - 30.0) * 0.5), 30.0, 30.0);
    searchIcon.userInteractionEnabled = NO;

    NSArray<UIControl *> *itemViews = MMTabBarItemViews(tabBar);
    NSInteger count = MIN((NSInteger)itemViews.count, 4);
    if (count <= 0) return;

    UITabBarController *tabVC = [vc isKindOfClass:[UITabBarController class]] ? (UITabBarController *)vc : vc.tabBarController;
    NSInteger selectedIndex = 0;
    if (tabVC) {
        selectedIndex = MAX(0, MIN((NSInteger)tabVC.selectedIndex, count - 1));
    }

    CGFloat contentLeft = 17.0;
    CGFloat contentRight = 17.0;
    CGFloat usableWidth = barWidth - contentLeft - contentRight;
    CGFloat slotWidth = floor(usableWidth / count);

    CGRect selectedSlot = CGRectMake(contentLeft + slotWidth * selectedIndex, 0.0, slotWidth, barHeight);
    CGFloat capsuleHeight = 54.0;
    CGFloat capsuleY = floor((barHeight - capsuleHeight) * 0.5);
    CGFloat capsuleWidth = MIN(slotWidth + 20.0, MAX(capsuleHeight * 1.58, slotWidth + 12.0));
    CGFloat capsuleX = floor(CGRectGetMidX(selectedSlot) - capsuleWidth * 0.5);

    UIView *capsule = MMEnsureView(bar, kMMFloatingCapsuleTag);
    capsule.frame = CGRectMake(capsuleX, capsuleY, capsuleWidth, capsuleHeight);
    capsule.userInteractionEnabled = NO;
    MMApplyCapsuleStyle(capsule, dark);

    for (NSInteger i = 0; i < 4; i++) {
        UIControl *slotControl = MMEnsureControl(bar, kMMFloatingButtonBaseTag + i);
        UIImageView *iconView = MMEnsureImageView(slotControl, kMMFloatingButtonImageBaseTag + i);
        UILabel *label = MMEnsureLabel(slotControl, kMMFloatingButtonLabelBaseTag + i);

        if (i >= count) {
            slotControl.hidden = YES;
            continue;
        }

        slotControl.hidden = NO;
        slotControl.frame = CGRectMake(contentLeft + slotWidth * i, 0.0, slotWidth, barHeight);
        objc_setAssociatedObject(slotControl, &kMMFloatingIndexKey, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [slotControl removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        if ([vc respondsToSelector:@selector(mm_floatingTabTapped:)]) {
            [slotControl addTarget:vc action:@selector(mm_floatingTabTapped:) forControlEvents:UIControlEventTouchUpInside];
        }

        UIControl *sourceView = itemViews[i];
        UIView *sourceImageView = MMImageViewInTabButton(sourceView);
        UILabel *sourceLabel = MMLabelInTabButton(sourceView);
        UITabBarItem *item = (i < tabBar.items.count) ? tabBar.items[i] : nil;

        UIImage *baseImage = nil;
        if ([sourceImageView isKindOfClass:[UIImageView class]] && ((UIImageView *)sourceImageView).image) {
            baseImage = ((UIImageView *)sourceImageView).image;
        }
        if (!baseImage) {
            baseImage = (i == selectedIndex ? (item.selectedImage ?: item.image) : (item.image ?: item.selectedImage));
        }
        baseImage = MMOriginalImage(baseImage);
        UIColor *normalColor = MMNormalTextColor(dark);
        UIColor *selectedColor = sourceLabel.textColor ?: ((UIImageView *)sourceImageView).tintColor ?: tabBar.tintColor ?: MMRGBA(7, 193, 96, 1.0);
        UIColor *iconTint = (i == selectedIndex) ? selectedColor : normalColor;

        iconView.frame = CGRectMake(floor((slotWidth - 26.0) * 0.5), 7.0, 26.0, 26.0);
        label.frame = CGRectMake(0.0, 35.5, slotWidth, 16.0);
        label.font = [UIFont systemFontOfSize:11.0 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightMedium)];
        label.text = item.title ?: @"";
        label.textColor = (i == selectedIndex) ? selectedColor : normalColor;
        label.alpha = 1.0;

        UIImage *finalImage = baseImage;
        if (!finalImage && [sourceImageView isKindOfClass:[UIImageView class]]) {
            finalImage = ((UIImageView *)sourceImageView).image;
        }
        if (finalImage && finalImage.renderingMode != UIImageRenderingModeAlwaysOriginal && [finalImage respondsToSelector:@selector(imageWithTintColor:renderingMode:)]) {
            finalImage = [finalImage imageWithTintColor:iconTint renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        if (!finalImage) {
            NSString *title = item.title ?: @"";
            if ([title containsString:@"微信"]) finalImage = [UIImage systemImageNamed:@"message"];
            else if ([title containsString:@"通讯录"]) finalImage = [UIImage systemImageNamed:@"person.2"];
            else if ([title containsString:@"发现"]) finalImage = [UIImage systemImageNamed:@"safari"];
            else if ([title containsString:@"我"]) finalImage = [UIImage systemImageNamed:@"person"];
            if (finalImage && [finalImage respondsToSelector:@selector(imageWithTintColor:renderingMode:)]) {
                finalImage = [finalImage imageWithTintColor:iconTint renderingMode:UIImageRenderingModeAlwaysOriginal];
            }
        }
        iconView.image = finalImage;
        iconView.hidden = (finalImage == nil);
        iconView.tintColor = iconTint;
        iconView.alpha = 1.0;
        iconView.layer.opacity = 1.0;
    }

    for (UIControl *source in itemViews) {
        source.alpha = 0.001;
        source.userInteractionEnabled = NO;
    }
}

