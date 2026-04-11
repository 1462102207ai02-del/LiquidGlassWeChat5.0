#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSInteger const kMMHostTag = 993001;
static NSInteger const kMMBackdropTag = 993002;
static NSInteger const kMMBackdropTintTag = 993003;
static NSInteger const kMMBarBlurTag = 993004;
static NSInteger const kMMBarTag = 993005;
static NSInteger const kMMCapsuleTag = 993006;
static NSInteger const kMMCapsuleBorderTag = 993007;
static NSInteger const kMMCapsuleGlowTag = 993008;
static NSInteger const kMMBarBorderTag = 993009;
static NSInteger const kMMBarGlowTag = 993010;
static NSInteger const kMMDockTag = 993011;
static NSInteger const kMMDockBlurTag = 993012;
static NSInteger const kMMDockBorderTag = 993013;
static NSInteger const kMMDockIconTag = 993014;
static NSInteger const kMMDockButtonTag = 993015;

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

static UIVisualEffectView *MMEnsureBlur(UIView *parent, NSInteger tag) {
    UIView *existing = [parent viewWithTag:tag];
    UIVisualEffectView *blur = [existing isKindOfClass:[UIVisualEffectView class]] ? (UIVisualEffectView *)existing : nil;
    if (!blur) {
        [existing removeFromSuperview];
        blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = tag;
        [parent addSubview:blur];
    }
    return blur;
}

static CAShapeLayer *MMEnsureBorderLayer(UIView *parent, NSInteger tag) {
    UIView *holder = MMEnsureView(parent, tag);
    holder.userInteractionEnabled = NO;
    holder.backgroundColor = UIColor.clearColor;
    holder.frame = parent.bounds;
    CAShapeLayer *layer = (CAShapeLayer *)holder.layer.sublayers.firstObject;
    if (![layer isKindOfClass:[CAShapeLayer class]]) {
        layer = [CAShapeLayer layer];
        [holder.layer addSublayer:layer];
    }
    layer.frame = holder.bounds;
    return layer;
}

static CAGradientLayer *MMEnsureGlowLayer(UIView *parent, NSInteger tag) {
    UIView *holder = MMEnsureView(parent, tag);
    holder.userInteractionEnabled = NO;
    holder.backgroundColor = UIColor.clearColor;
    holder.frame = parent.bounds;
    holder.clipsToBounds = YES;
    MMSetContinuousRadius(holder, CGRectGetHeight(parent.bounds) * 0.5);
    CAGradientLayer *layer = (CAGradientLayer *)holder.layer.sublayers.firstObject;
    if (![layer isKindOfClass:[CAGradientLayer class]]) {
        layer = [CAGradientLayer layer];
        [holder.layer addSublayer:layer];
    }
    layer.frame = holder.bounds;
    layer.cornerRadius = CGRectGetHeight(holder.bounds) * 0.5;
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

static NSArray<UIControl *> *MMTabBarButtons(UITabBar *tabBar) {
    NSMutableArray<UIControl *> *buttons = [NSMutableArray array];
    for (UIView *subview in tabBar.subviews) {
        if ([subview isKindOfClass:[UIControl class]]) {
            NSString *name = NSStringFromClass(subview.class);
            if ([name containsString:@"TabBarButton"] || [name containsString:@"MMTabBarItemView"]) {
                [buttons addObject:(UIControl *)subview];
            }
        }
    }
    [buttons sortUsingComparator:^NSComparisonResult(UIControl *a, UIControl *b) {
        CGFloat x1 = CGRectGetMinX(a.frame);
        CGFloat x2 = CGRectGetMinX(b.frame);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return buttons;
}

static UIViewController *MMSelectedRootController(UIViewController *vc) {
    UITabBarController *tabVC = [vc isKindOfClass:[UITabBarController class]] ? (UITabBarController *)vc : vc.tabBarController;
    if (!tabVC) return nil;
    UIViewController *selected = nil;
    @try {
        selected = [tabVC valueForKey:@"selectedViewController"];
    } @catch (__unused NSException *e) {
    }
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        return nav.viewControllers.count > 0 ? nav.viewControllers.firstObject : nav.topViewController;
    }
    return selected;
}

static BOOL MMShouldShowFloatingBar(UIViewController *vc) {
    UIViewController *root = MMSelectedRootController(vc);
    if (!root) return YES;
    UIViewController *selected = nil;
    UITabBarController *tabVC = [vc isKindOfClass:[UITabBarController class]] ? (UITabBarController *)vc : vc.tabBarController;
    @try {
        selected = [tabVC valueForKey:@"selectedViewController"];
    } @catch (__unused NSException *e) {
    }
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        UIViewController *top = nav.topViewController ?: nav.visibleViewController;
        return top == root;
    }
    return YES;
}

static UIView *MMFindTopSearchView(UIView *root) {
    return [root mm_findSubviewPassing:^BOOL(UIView *view) {
        if (CGRectGetMinY(view.frame) > 180.0) return NO;
        if ([view isKindOfClass:[UISearchBar class]]) return YES;
        if ([view isKindOfClass:[UITextField class]]) return YES;
        NSString *name = NSStringFromClass(view.class).lowercaseString;
        if ([view isKindOfClass:[UIControl class]] && [name containsString:@"search"]) return YES;
        return NO;
    }];
}

static void MMOpenTopSearch(UIViewController *vc) {
    UIView *search = MMFindTopSearchView(vc.view);
    if ([search isKindOfClass:[UITextField class]]) {
        [(UITextField *)search becomeFirstResponder];
        return;
    }
    if ([search isKindOfClass:[UISearchBar class]]) {
        UITextField *field = nil;
        @try { field = [(UISearchBar *)search valueForKey:@"searchField"]; } @catch (__unused NSException *e) {}
        [field becomeFirstResponder];
        return;
    }
    if ([search isKindOfClass:[UIControl class]]) {
        [(UIControl *)search sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
}

static CGRect MMNativeContainerFrame(UITabBar *tabBar, UIView *root) {
    if (tabBar.superview) {
        return [tabBar.superview convertRect:tabBar.frame toView:root];
    }
    return tabBar.frame;
}

static void MMHideNativeBackgroundOnly(UITabBar *tabBar) {
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = UIColor.clearColor;
    tabBar.barTintColor = UIColor.clearColor;
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

static UIImage *MMSearchImage(BOOL dark) {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config];
    if (!image) image = [UIImage systemImageNamed:@"magnifyingglass"];
    UIColor *color = dark ? UIColor.whiteColor : MMRGBA(92, 97, 108, 0.88);
    if ([image respondsToSelector:@selector(imageWithTintColor:renderingMode:)]) {
        return [image imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return image;
}

static void MMApplyBlur(UIVisualEffectView *view, BOOL dark, CGFloat radius, CGFloat alpha) {
    view.effect = [UIBlurEffect effectWithStyle:(dark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight)];
    view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:alpha];
    MMSetContinuousRadius(view, radius);
    view.clipsToBounds = YES;
    view.userInteractionEnabled = NO;
}

static void MMApplyBarStyle(UIView *bar, BOOL dark) {
    bar.backgroundColor = dark ? MMRGBA(118, 124, 136, 0.20) : MMRGBA(245, 250, 255, 0.30);
    MMSetContinuousRadius(bar, CGRectGetHeight(bar.bounds) * 0.5);
    CAShapeLayer *border = MMEnsureBorderLayer(bar, kMMBarBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bar.bounds, 0.35, 0.35) cornerRadius:CGRectGetHeight(bar.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = (dark ? MMRGBA(255, 255, 255, 0.16) : MMRGBA(255, 255, 255, 0.52)).CGColor;
    border.lineWidth = 0.85;
    CAGradientLayer *glow = MMEnsureGlowLayer(bar, kMMBarGlowTag);
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
    CAShapeLayer *border = MMEnsureBorderLayer(capsule, kMMCapsuleBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(capsule.bounds, 0.30, 0.30) cornerRadius:CGRectGetHeight(capsule.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = (dark ? MMRGBA(255, 255, 255, 0.22) : MMRGBA(255, 255, 255, 0.72)).CGColor;
    border.lineWidth = 0.95;
    CAGradientLayer *glow = MMEnsureGlowLayer(capsule, kMMCapsuleGlowTag);
    glow.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.88].CGColor,
        (__bridge id)[UIColor colorWithRed:(233.0 / 255.0) green:(244.0 / 255.0) blue:(255.0 / 255.0) alpha:0.42].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor
    ];
    glow.startPoint = CGPointMake(0.0, 0.0);
    glow.endPoint = CGPointMake(1.0, 1.0);
}

static void MMApplyDockStyle(UIView *dock, BOOL dark) {
    dock.backgroundColor = dark ? MMRGBA(118, 124, 136, 0.20) : MMRGBA(245, 250, 255, 0.30);
    MMSetContinuousRadius(dock, CGRectGetHeight(dock.bounds) * 0.5);
    CAShapeLayer *border = MMEnsureBorderLayer(dock, kMMDockBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(dock.bounds, 0.35, 0.35) cornerRadius:CGRectGetHeight(dock.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = (dark ? MMRGBA(255, 255, 255, 0.18) : MMRGBA(255, 255, 255, 0.58)).CGColor;
    border.lineWidth = 0.85;
}

static void MMSetVisible(UIView *view, BOOL visible) {
    if (!view) return;
    view.hidden = !visible;
    view.alpha = visible ? 1.0 : 0.0;
    view.userInteractionEnabled = visible;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc.isViewLoaded) return;
    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!root || !tabBar || tabBar.items.count == 0) return;

    UIView *host = MMEnsureView(root, kMMHostTag);
    UIView *dock = MMEnsureView(root, kMMDockTag);

    if (!MMShouldShowFloatingBar(vc)) {
        MMSetVisible(host, NO);
        MMSetVisible(dock, NO);
        tabBar.alpha = 1.0;
        tabBar.userInteractionEnabled = YES;
        return;
    }

    MMHideNativeBackgroundOnly(tabBar);

    CGRect container = MMNativeContainerFrame(tabBar, root);
    if (CGRectIsEmpty(container)) {
        MMSetVisible(host, NO);
        MMSetVisible(dock, NO);
        return;
    }

    BOOL dark = MMIsDark(root.traitCollection);

    host.frame = container;
    host.backgroundColor = UIColor.clearColor;
    host.hidden = NO;
    host.alpha = 1.0;
    host.userInteractionEnabled = NO;
    [root insertSubview:host belowSubview:tabBar];

    UIVisualEffectView *backdrop = MMEnsureBlur(host, kMMBackdropTag);
    backdrop.frame = host.bounds;
    MMApplyBlur(backdrop, dark, 0.0, dark ? 0.03 : 0.12);
    backdrop.layer.cornerRadius = 0.0;

    UIView *backdropTint = MMEnsureView(host, kMMBackdropTintTag);
    backdropTint.frame = host.bounds;
    backdropTint.backgroundColor = dark ? MMRGBA(255, 255, 255, 0.012) : MMRGBA(196, 223, 255, 0.22);
    backdropTint.userInteractionEnabled = NO;

    CGFloat sideMargin = 14.0;
    CGFloat gap = 14.0;
    CGFloat searchSize = 64.0;
    CGFloat barHeight = 64.0;
    CGFloat verticalLift = 3.0;
    CGFloat barY = floor((CGRectGetHeight(container) - barHeight) * 0.5) - verticalLift;
    CGFloat dockY = floor((CGRectGetHeight(container) - searchSize) * 0.5) - verticalLift;
    CGFloat barX = sideMargin;
    CGFloat barWidth = CGRectGetWidth(container) - sideMargin * 2.0 - searchSize - gap;
    CGFloat dockX = CGRectGetWidth(container) - sideMargin - searchSize;

    UIVisualEffectView *barBlur = MMEnsureBlur(host, kMMBarBlurTag);
    barBlur.frame = CGRectMake(barX, barY, barWidth, barHeight);
    MMApplyBlur(barBlur, dark, barHeight * 0.5, dark ? 0.025 : 0.10);

    UIView *bar = MMEnsureView(host, kMMBarTag);
    bar.frame = CGRectMake(barX, barY, barWidth, barHeight);
    bar.userInteractionEnabled = NO;
    MMApplyBarStyle(bar, dark);

    UIView *capsule = MMEnsureView(bar, kMMCapsuleTag);
    NSArray<UIControl *> *buttons = MMTabBarButtons(tabBar);
    NSInteger count = MIN((NSInteger)buttons.count, 4);
    NSInteger selectedIndex = 0;
    UITabBarController *tabVC = [vc isKindOfClass:[UITabBarController class]] ? (UITabBarController *)vc : vc.tabBarController;
    if (tabVC) selectedIndex = MAX(0, MIN((NSInteger)tabVC.selectedIndex, count - 1));

    if (count > 0 && selectedIndex < count) {
        UIControl *selectedButton = buttons[selectedIndex];
        CGRect selectedFrame = [selectedButton.superview convertRect:selectedButton.frame toView:host];
        CGRect capFrame = CGRectInset(selectedFrame, 3.0, 5.0);
        capFrame.origin.y = barY + floor((barHeight - 54.0) * 0.5);
        capFrame.size.height = 54.0;
        capsule.frame = [host convertRect:capFrame toView:bar];
        MMApplyCapsuleStyle(capsule, dark);
        capsule.hidden = NO;
    } else {
        capsule.hidden = YES;
    }

    dock.frame = CGRectMake(dockX, dockY, searchSize, searchSize);
    dock.hidden = NO;
    dock.alpha = 1.0;
    dock.userInteractionEnabled = YES;
    MMApplyDockStyle(dock, dark);

    UIVisualEffectView *dockBlur = MMEnsureBlur(dock, kMMDockBlurTag);
    dockBlur.frame = dock.bounds;
    MMApplyBlur(dockBlur, dark, searchSize * 0.5, dark ? 0.025 : 0.10);

    UIView *iconHolder = MMEnsureView(dock, kMMDockIconTag);
    UIImageView *icon = [iconHolder isKindOfClass:[UIImageView class]] ? (UIImageView *)iconHolder : nil;
    if (!icon) {
        [iconHolder removeFromSuperview];
        icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        icon.tag = kMMDockIconTag;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [dock addSubview:icon];
    }
    icon.image = MMSearchImage(dark);
    icon.frame = CGRectMake(floor((searchSize - 30.0) * 0.5), floor((searchSize - 30.0) * 0.5), 30.0, 30.0);
    icon.userInteractionEnabled = NO;

    UIView *dockButtonHolder = MMEnsureView(dock, kMMDockButtonTag);
    UIControl *dockButton = [dockButtonHolder isKindOfClass:[UIControl class]] ? (UIControl *)dockButtonHolder : nil;
    if (!dockButton) {
        [dockButtonHolder removeFromSuperview];
        dockButton = [[UIControl alloc] initWithFrame:CGRectZero];
        dockButton.tag = kMMDockButtonTag;
        [dock addSubview:dockButton];
    }
    dockButton.frame = dock.bounds;
    [dockButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [dockButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        MMOpenTopSearch(vc);
    }] forControlEvents:UIControlEventTouchUpInside];

    for (NSInteger i = 0; i < count; i++) {
        UIControl *btn = buttons[i];
        btn.hidden = NO;
        btn.alpha = 1.0;
        btn.userInteractionEnabled = YES;
        [tabBar bringSubviewToFront:btn];
    }

    [root bringSubviewToFront:tabBar];
    [root bringSubviewToFront:dock];
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    MMUpdateFloatingBar((UIViewController *)self);
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
    MMUpdateFloatingBar((UIViewController *)self);
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
                MMUpdateFloatingBar(vc);
                break;
            }
        }
    }
}

%end
