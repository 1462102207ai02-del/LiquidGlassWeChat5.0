#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingCapsuleTag = 990203;
static NSInteger const kMMFloatingCapsuleBorderTag = 990204;
static NSInteger const kMMFloatingCapsuleGlowTag = 990205;
static NSInteger const kMMFloatingButtonsTag = 990206;
static NSInteger const kMMFloatingCoreTag = 990207;
static NSInteger const kMMFloatingShineTag = 990208;
static NSInteger const kMMFloatingEdgeTag = 990209;
static NSInteger const kMMFloatingInnerEdgeTag = 990210;
static NSInteger const kMMNativeBackdropHostTag = 990211;
static NSInteger const kMMNativeBackdropBlurTag = 990212;
static NSInteger const kMMNativeBackdropTintTag = 990213;

static NSInteger const kMMDockSearchHostTag = 991201;
static NSInteger const kMMDockSearchBlurTag = 991202;
static NSInteger const kMMDockSearchIconTag = 991203;
static NSInteger const kMMDockSearchHitButtonTag = 991204;

static BOOL kMMUpdatingLayout = NO;
static BOOL kMMSettingsPresented = NO;

static void MMRequestFloatingBarRefresh(UIViewController *vc);
static void MMShowSettingsMenu(UIViewController *vc);
static void MMOpenSearchFromMainTab(UIViewController *vc);

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a);
static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static BOOL MMIsDark(UITraitCollection *trait);
static CGFloat MMClamp(CGFloat value, CGFloat min, CGFloat max);
static NSString *MMModeSuffix(UITraitCollection *trait);
static NSString *MMKey(NSString *prefix, UITraitCollection *trait, NSString *component);
static CGFloat MMUserFloat(NSString *key, CGFloat fallback);
static CGFloat MMUserAlpha(NSString *key, CGFloat fallback);
static NSString *MMPercentString(CGFloat alpha);
static CGFloat MMPercentToAlpha(NSString *text, CGFloat fallback);
static void MMSaveFloat(NSString *key, CGFloat value);
static UIColor *MMColorFromStored(NSString *prefix, UITraitCollection *trait, UIColor *fallback);
static void MMSaveColor(NSString *prefix, UITraitCollection *trait, UIColor *color);
static void MMRemoveColor(NSString *prefix, UITraitCollection *trait);
static UIColor *MMBackgroundTintColor(UITraitCollection *trait);
static UIColor *MMCapsuleTintColor(UITraitCollection *trait);
static UIColor *MMSelectedColor(UITraitCollection *trait);
static UIColor *MMNormalColor(UITraitCollection *trait);
static CGFloat MMBottomInset(UIView *view);
static void MMSetRadius(UIView *view, CGFloat radius);
static id MMKVC(id obj, NSString *key);
static UITabBar *MMFindTabBar(UIViewController *vc);
static BOOL MMShouldHideFloatingBar(UIViewController *vc);
static UIView *MMNativeBackdropHost(UIView *root);
static void MMUpdateNativeBackdrop(UIViewController *vc, UITabBar *tabBar);
static UIView *MMHost(UIView *root);
static UIVisualEffectView *MMBlur(UIView *host);
static UIView *MMCapsule(UIView *host);
static UIView *MMButtonsContainer(UIView *host);
static void MMStyleHost(UIView *host);
static CGRect MMSlotFrame(UIView *host, NSInteger index, NSInteger count);
static CGRect MMCapsuleFrame(UIView *host, NSInteger index, NSInteger count);
static void MMStyleCapsule(UIView *host, NSInteger selectedIndex, NSInteger count);
static NSArray *MMOriginalItemViews(UITabBar *tabBar);
static void MMSelectIndex(UIView *view, NSInteger index);
static void MMUpdateButtons(UIViewController *vc, UITabBar *tabBar, UIView *host);
static void MMHideOriginalTabBarVisuals(UITabBar *tabBar);
static UIView *MMFindSearchBarInView(UIView *root);
static UIViewController *MMFindHomeContentControllerFromController(UIViewController *vc);
static CAGradientLayer *MMEnsureGradient(UIView *view, NSString *name);
static void MMApplyLiquidGlass(UIView *view, BOOL capsuleStyle);
static void MMApplyButtonSelectionLayout(UIView *container, UIView *host, UITabBar *tabBar, NSArray *originalItemViews, NSInteger selectedIndex, CGRect activeCapsuleFrame, BOOL useActiveCapsuleFrame);



static CAGradientLayer *MMEnsureGradient(UIView *view, NSString *name) {
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]] && [((CAGradientLayer *)layer).name isEqualToString:name]) {
            return (CAGradientLayer *)layer;
        }
    }
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.name = name;
    [view.layer addSublayer:layer];
    return layer;
}

static void MMApplyLiquidGlassOverlay(UIView *view, BOOL capsuleStyle) {
    if (!view) return;

    UIView *overlay = [view viewWithTag:990260];
    if (!overlay) {
        overlay = [UIView new];
        overlay.tag = 990260;
        overlay.userInteractionEnabled = NO;
        overlay.backgroundColor = [UIColor clearColor];
        [view addSubview:overlay];
    }
    overlay.frame = CGRectInset(view.bounds, capsuleStyle ? 1.1 : 1.0, capsuleStyle ? 1.1 : 1.0);
    MMSetRadius(overlay, overlay.bounds.size.height * 0.5);
    if (@available(iOS 13.0, *)) overlay.layer.cornerCurve = kCACornerCurveContinuous;
    overlay.clipsToBounds = YES;
    overlay.layer.masksToBounds = YES;

    CAGradientLayer *overlayLayer = MMEnsureGradient(overlay, capsuleStyle ? @"capsule_overlay" : @"host_overlay");
    overlayLayer.frame = overlay.bounds;
    overlayLayer.startPoint = CGPointMake(0.0, 0.0);
    overlayLayer.endPoint = CGPointMake(1.0, 1.0);

    if (capsuleStyle) {
        overlayLayer.colors = @[
            (__bridge id)[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:(MMIsDark(view.traitCollection) ? 0.10 : 0.22)].CGColor,
            (__bridge id)[UIColor colorWithRed:(233.0/255.0) green:(242.0/255.0) blue:(253.0/255.0) alpha:(MMIsDark(view.traitCollection) ? 0.04 : 0.12)].CGColor,
            (__bridge id)[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:(MMIsDark(view.traitCollection) ? 0.015 : 0.06)].CGColor
        ];
        overlayLayer.locations = @[@0.0, @0.46, @1.0];
    } else {
        overlayLayer.colors = @[
            (__bridge id)[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:(MMIsDark(view.traitCollection) ? 0.06 : 0.12)].CGColor,
            (__bridge id)[UIColor colorWithRed:(226.0/255.0) green:(237.0/255.0) blue:(252.0/255.0) alpha:(MMIsDark(view.traitCollection) ? 0.02 : 0.08)].CGColor,
            (__bridge id)[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:(MMIsDark(view.traitCollection) ? 0.01 : 0.04)].CGColor
        ];
        overlayLayer.locations = @[@0.0, @0.50, @1.0];
    }
    overlayLayer.cornerRadius = overlay.bounds.size.height * 0.5;
    overlayLayer.masksToBounds = YES;
}

static void MMApplyLiquidGlass(UIView *view, BOOL capsuleStyle) {
    if (!view) return;

    UIView *core = [view viewWithTag:kMMFloatingCoreTag];
    if (!core) {
        core = [UIView new];
        core.tag = kMMFloatingCoreTag;
        core.userInteractionEnabled = NO;
        [view insertSubview:core atIndex:0];
    }

    BOOL dark = MMIsDark(view.traitCollection);
    core.frame = CGRectInset(view.bounds, capsuleStyle ? 1.15 : 1.05, capsuleStyle ? 1.15 : 1.05);
    MMSetRadius(core, core.bounds.size.height * 0.5);
    if (@available(iOS 13.0, *)) core.layer.cornerCurve = kCACornerCurveContinuous;
    core.clipsToBounds = YES;
    core.layer.masksToBounds = YES;

    if (capsuleStyle) {
        core.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:(dark ? 0.08 : 0.22)];
    } else {
        core.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:(dark ? 0.05 : 0.14)];
    }

    UIView *shine = [view viewWithTag:kMMFloatingShineTag];
    if (!shine) {
        shine = [UIView new];
        shine.tag = kMMFloatingShineTag;
        shine.userInteractionEnabled = NO;
        [view addSubview:shine];
    }
    shine.frame = CGRectInset(view.bounds, 0.65, 0.65);
    MMSetRadius(shine, shine.bounds.size.height * 0.5);
    if (@available(iOS 13.0, *)) shine.layer.cornerCurve = kCACornerCurveContinuous;
    shine.backgroundColor = [UIColor clearColor];
    shine.clipsToBounds = YES;
    shine.layer.masksToBounds = YES;

    CAGradientLayer *moving = MMEnsureGradient(shine, capsuleStyle ? @"capsule_move" : @"host_move");
    CAGradientLayer *topLine = MMEnsureGradient(shine, capsuleStyle ? @"capsule_top" : @"host_top");

    if (capsuleStyle) {
        moving.frame = shine.bounds;
        moving.startPoint = CGPointMake(0.5, 0.0);
        moving.endPoint = CGPointMake(0.5, 1.0);
        moving.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:(dark ? 0.18 : 0.34)].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:(dark ? 0.06 : 0.11)].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        moving.locations = @[@0.0, @0.13, @0.34];
        moving.cornerRadius = shine.bounds.size.height * 0.5;
        moving.masksToBounds = YES;
        [moving removeAnimationForKey:@"capsule_move_anim"];

        topLine.frame = shine.bounds;
        topLine.startPoint = CGPointMake(0.0, 0.0);
        topLine.endPoint = CGPointMake(1.0, 0.0);
        topLine.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:(dark ? 0.22 : 0.58)].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        topLine.locations = @[@0.0, @0.50, @1.0];
        topLine.cornerRadius = shine.bounds.size.height * 0.5;
        topLine.masksToBounds = YES;
    } else {
        moving.frame = CGRectInset(shine.bounds, -shine.bounds.size.width * 0.35, 0.0);
        moving.startPoint = CGPointMake(0.0, 0.0);
        moving.endPoint = CGPointMake(1.0, 1.0);
        moving.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:(dark ? 0.10 : 0.20)].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        moving.locations = @[@(-0.35), @(-0.08), @(0.16)];
        moving.cornerRadius = shine.bounds.size.height * 0.5;
        moving.masksToBounds = YES;
        [moving removeAnimationForKey:@"host_move_anim"];

        topLine.frame = shine.bounds;
        topLine.startPoint = CGPointMake(0.0, 0.0);
        topLine.endPoint = CGPointMake(1.0, 0.0);
        topLine.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:(dark ? 0.22 : 0.46)].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        topLine.locations = @[@0.0, @0.50, @1.0];
        topLine.cornerRadius = shine.bounds.size.height * 0.5;
        topLine.masksToBounds = YES;
    }

    UIView *edge = [view viewWithTag:kMMFloatingEdgeTag];
    if (!edge) {
        edge = [UIView new];
        edge.tag = kMMFloatingEdgeTag;
        edge.userInteractionEnabled = NO;
        edge.backgroundColor = [UIColor clearColor];
        [view addSubview:edge];
    }
    edge.frame = CGRectInset(view.bounds, 0.6, 0.6);
    MMSetRadius(edge, edge.bounds.size.height * 0.5);
    if (@available(iOS 13.0, *)) edge.layer.cornerCurve = kCACornerCurveContinuous;
    edge.clipsToBounds = YES;
    edge.layer.masksToBounds = YES;

    UIView *innerEdge = [view viewWithTag:kMMFloatingInnerEdgeTag];
    if (!innerEdge) {
        innerEdge = [UIView new];
        innerEdge.tag = kMMFloatingInnerEdgeTag;
        innerEdge.userInteractionEnabled = NO;
        innerEdge.backgroundColor = [UIColor clearColor];
        [view addSubview:innerEdge];
    }
    innerEdge.frame = CGRectInset(view.bounds, capsuleStyle ? 1.7 : 1.3, capsuleStyle ? 1.7 : 1.3);
    MMSetRadius(innerEdge, innerEdge.bounds.size.height * 0.5);
    if (@available(iOS 13.0, *)) innerEdge.layer.cornerCurve = kCACornerCurveContinuous;

    CGFloat outerAlpha = dark ? 0.16 : 0.42;
    CGFloat innerAlpha = dark ? 0.13 : 0.13;
    CGFloat outerWidth = 0.84;
    CGFloat innerWidth = 0.15;
    if (capsuleStyle) {
        outerAlpha = dark ? 0.14 : 0.38;
        innerAlpha = dark ? 0.11 : 0.11;
        outerWidth = 0.78;
        innerWidth = 0.13;
    }

    edge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:outerAlpha].CGColor;
    edge.layer.borderWidth = outerWidth;
    innerEdge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:innerAlpha].CGColor;
    innerEdge.layer.borderWidth = innerWidth;

    view.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:(capsuleStyle ? (dark ? 0.016 : 0.004) : (dark ? 0.020 : 0.004))].CGColor;
    view.layer.shadowOpacity = 1.0;
    view.layer.shadowRadius = capsuleStyle ? 1.4 : 2.0;
    view.layer.shadowOffset = CGSizeMake(0, capsuleStyle ? 0.28 : 0.55);

    MMApplyLiquidGlassOverlay(view, capsuleStyle);
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

static NSString *MMModeSuffix(UITraitCollection *trait) {
    return MMIsDark(trait) ? @"dark" : @"light";
}

static NSString *MMKey(NSString *prefix, UITraitCollection *trait, NSString *component) {
    return [NSString stringWithFormat:@"%@_%@_%@", prefix, MMModeSuffix(trait), component];
}

static CGFloat MMUserFloat(NSString *key, CGFloat fallback) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id obj = [defaults objectForKey:key];
    if (!obj) return fallback;
    return [defaults floatForKey:key];
}

static CGFloat MMUserAlpha(NSString *key, CGFloat fallback) {
    return MMClamp(MMUserFloat(key, fallback), 0.0, 1.0);
}

static NSString *MMPercentString(CGFloat alpha) {
    return [NSString stringWithFormat:@"%.0f", MMClamp(alpha, 0.0, 1.0) * 100.0];
}

static CGFloat MMPercentToAlpha(NSString *text, CGFloat fallback) {
    if (![text length]) return fallback;
    return MMClamp(([text doubleValue] / 100.0), 0.0, 1.0);
}

static void MMSaveFloat(NSString *key, CGFloat value) {
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static UIColor *MMColorFromStored(NSString *prefix, UITraitCollection *trait, UIColor *fallback) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *rKey = MMKey(prefix, trait, @"r");
    NSString *gKey = MMKey(prefix, trait, @"g");
    NSString *bKey = MMKey(prefix, trait, @"b");

    if ([defaults objectForKey:rKey] && [defaults objectForKey:gKey] && [defaults objectForKey:bKey]) {
        CGFloat r = MMClamp([defaults floatForKey:rKey], 0.0, 1.0);
        CGFloat g = MMClamp([defaults floatForKey:gKey], 0.0, 1.0);
        CGFloat b = MMClamp([defaults floatForKey:bKey], 0.0, 1.0);
        return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
    }
    return fallback;
}

static void MMSaveColor(NSString *prefix, UITraitCollection *trait, UIColor *color) {
    CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
    UIColor *resolved = color ?: [UIColor whiteColor];
    if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
        CGColorRef cgColor = resolved.CGColor;
        size_t count = CGColorGetNumberOfComponents(cgColor);
        const CGFloat *components = CGColorGetComponents(cgColor);
        if (count >= 3) {
            r = components[0];
            g = components[1];
            b = components[2];
        } else if (count == 2) {
            r = components[0];
            g = components[0];
            b = components[0];
        }
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:r forKey:MMKey(prefix, trait, @"r")];
    [defaults setFloat:g forKey:MMKey(prefix, trait, @"g")];
    [defaults setFloat:b forKey:MMKey(prefix, trait, @"b")];
    [defaults synchronize];
}

static void MMRemoveColor(NSString *prefix, UITraitCollection *trait) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:MMKey(prefix, trait, @"r")];
    [defaults removeObjectForKey:MMKey(prefix, trait, @"g")];
    [defaults removeObjectForKey:MMKey(prefix, trait, @"b")];
    [defaults synchronize];
}

static UIColor *MMBackgroundTintColor(UITraitCollection *trait) {
    return MMColorFromStored(@"mm_bg_color", trait, MMIsDark(trait) ? MMRGBA(112, 120, 132, 1.0) : MMRGBA(255, 255, 255, 1.0));
}

static UIColor *MMCapsuleTintColor(UITraitCollection *trait) {
    return MMColorFromStored(@"mm_capsule_color", trait, MMIsDark(trait) ? MMRGBA(232, 238, 245, 1.0) : MMRGBA(255, 255, 255, 1.0));
}

static UIColor *MMSelectedColor(UITraitCollection *trait) {
    UIColor *fallback = MMIsDark(trait) ? MMRGBA(0, 216, 95, 1.0) : MMRGBA(0, 190, 80, 1.0);
    return MMColorFromStored(@"mm_selected_color", trait, fallback);
}

static UIColor *MMNormalColor(UITraitCollection *trait) {
    UIColor *fallback = MMIsDark(trait) ? MMRGBA(255, 255, 255, 0.80) : MMRGBA(104, 107, 116, 0.94);
    return MMColorFromStored(@"mm_normal_color", trait, fallback);
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

static BOOL MMShouldHideFloatingBar(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return YES;
    if (kMMSettingsPresented) return NO;

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
        if (root && top && top != root) return YES;
        if (nav.presentedViewController && !kMMSettingsPresented) return YES;
    } else if ([selected isKindOfClass:[UIViewController class]]) {
        UIViewController *child = (UIViewController *)selected;
        if (child.presentedViewController && !kMMSettingsPresented) return YES;
    }

    return NO;
}

@interface MMFloatingTabButton : UIControl
@property (nonatomic, retain) UIImageView *mm_imageView;
@property (nonatomic, retain) UILabel *mm_titleLabel;
@property (nonatomic, retain) UILabel *mm_badgeLabel;
@property (nonatomic, assign) NSInteger mm_index;
@end

@implementation MMFloatingTabButton
@end


@interface MMFloatingDragProxy : NSObject
@property (nonatomic, assign) UIViewController *mainTabVC;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation MMFloatingDragProxy

- (NSInteger)nearestIndexForHost:(UIView *)host count:(NSInteger)count x:(CGFloat)x {
    NSInteger nearest = 0;
    CGFloat best = CGFLOAT_MAX;
    for (NSInteger i = 0; i < count; i++) {
        CGRect slot = MMSlotFrame(host, i, count);
        CGFloat mid = CGRectGetMidX(slot);
        CGFloat d = fabs(mid - x);
        if (d < best) {
            best = d;
            nearest = i;
        }
    }
    return nearest;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *host = gesture.view;
    UIViewController *vc = self.mainTabVC;
    if (!host || !vc) return;

    UITabBar *tabBar = MMFindTabBar(vc);
    NSArray *items = tabBar.items;
    NSInteger count = items.count;
    if (count <= 0) return;

    CGPoint location = [gesture locationInView:host];
    NSInteger nearest = [self nearestIndexForHost:host count:count x:location.x];
    CGRect baseCapsule = MMCapsuleFrame(host, nearest, count);

    CGFloat minX = 1.5;
    CGFloat maxX = CGRectGetWidth(host.bounds) - CGRectGetWidth(baseCapsule) - 1.5;
    CGFloat x = location.x - CGRectGetWidth(baseCapsule) * 0.5;
    if (x < minX) x = minX;
    if (x > maxX) x = maxX;
    CGRect activeFrame = CGRectMake(x, CGRectGetMinY(baseCapsule), CGRectGetWidth(baseCapsule), CGRectGetHeight(baseCapsule));

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.currentIndex = nearest;
    }

    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        UIView *capsule = MMCapsule(host);
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        capsule.frame = activeFrame;
        MMSetRadius(capsule, CGRectGetHeight(activeFrame) * 0.5);
        MMApplyLiquidGlass(capsule, YES);
        [CATransaction commit];

        if (nearest != self.currentIndex) {
            self.currentIndex = nearest;
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        self.currentIndex = nearest;
        [UIView animateWithDuration:0.34
                              delay:0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.15
                            options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            UIView *capsule = MMCapsule(host);
            capsule.frame = MMCapsuleFrame(host, nearest, count);
            MMSetRadius(capsule, CGRectGetHeight(capsule.frame) * 0.5);
            MMApplyLiquidGlass(capsule, YES);
        } completion:^(__unused BOOL finished) {
            MMSelectIndex(host, nearest);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                MMRequestFloatingBarRefresh(vc);
            });
        }];
    }
}

@end

static MMFloatingDragProxy *MMSharedFloatingDragProxy(void) {
    static MMFloatingDragProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMFloatingDragProxy new];
        proxy.currentIndex = 0;
    });
    return proxy;
}

@interface MMColorPickerProxy : NSObject <UIColorPickerViewControllerDelegate>
@property (nonatomic, assign) UIViewController *vc;
@property (nonatomic, copy) NSString *prefix;
@end

@implementation MMColorPickerProxy
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    if (self.vc && [self.prefix length]) {
        MMSaveColor(self.prefix, self.vc.traitCollection, viewController.selectedColor);
        MMRequestFloatingBarRefresh(self.vc);
    }
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    if (self.vc && [self.prefix length]) {
        MMSaveColor(self.prefix, self.vc.traitCollection, viewController.selectedColor);
        MMRequestFloatingBarRefresh(self.vc);
    }
    kMMSettingsPresented = NO;
}
@end

static MMColorPickerProxy *MMSharedColorPickerProxy(void) {
    static MMColorPickerProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMColorPickerProxy new];
    });
    return proxy;
}

@interface MMGestureProxy : NSObject
@end

@implementation MMGestureProxy
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIResponder *r = gesture.view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            MMShowSettingsMenu((UIViewController *)r);
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

@interface MMDockSearchTapProxy : NSObject
@property (nonatomic, assign) UIViewController *mainTabVC;
@end

@implementation MMDockSearchTapProxy
- (void)handleTap:(__unused id)sender {
    MMOpenSearchFromMainTab(self.mainTabVC);
}
@end

static MMDockSearchTapProxy *MMSharedDockSearchTapProxy(void) {
    static MMDockSearchTapProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMDockSearchTapProxy new];
    });
    return proxy;
}

static void MMPresentColorPicker(UIViewController *vc, NSString *prefix, UIColor *currentColor, NSString *title) {
    if (!vc || !NSClassFromString(@"UIColorPickerViewController")) return;

    MMColorPickerProxy *proxy = MMSharedColorPickerProxy();
    proxy.vc = vc;
    proxy.prefix = prefix;

    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.delegate = proxy;
    picker.selectedColor = currentColor ?: [UIColor whiteColor];
    picker.title = title;
    [vc presentViewController:picker animated:YES completion:nil];
}

static void MMShowNamedAlphaAlert(UIViewController *vc, NSString *key, NSString *title, NSString *placeholder, CGFloat fallback) {
    if (!vc || ![key length]) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:@"请输入百分比 0 到 100" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = placeholder;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = MMPercentString(MMUserAlpha(key, fallback));
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        MMSaveFloat(key, fallback);
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UITextField *field = [alert.textFields count] > 0 ? [alert.textFields objectAtIndex:0] : nil;
        CGFloat value = MMPercentToAlpha(field.text, fallback);
        MMSaveFloat(key, value);
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    [vc presentViewController:alert animated:YES completion:nil];
}

static void MMShowSingleAlphaAlert(UIViewController *vc, NSString *type) {
    if (!vc || ![type length]) return;

    BOOL dark = MMIsDark(vc.traitCollection);
    NSString *title = nil;
    NSString *placeholder = nil;
    NSString *key = nil;
    CGFloat fallback = 0.0;

    if ([type isEqualToString:@"bg"]) {
        key = dark ? @"mm_bg_alpha_dark" : @"mm_bg_alpha_light";
        title = dark ? @"底栏背景透明度（深色模式）" : @"底栏背景透明度（浅色模式）";
        placeholder = @"底栏背景透明度 %";
        fallback = dark ? 0.05 : 0.13;
    } else if ([type isEqualToString:@"capsule"]) {
        key = dark ? @"mm_capsule_alpha_dark" : @"mm_capsule_alpha_light";
        title = dark ? @"胶囊透明度（深色模式）" : @"胶囊透明度（浅色模式）";
        placeholder = @"胶囊透明度 %";
        fallback = dark ? 0.10 : 0.24;
    } else if ([type isEqualToString:@"host_border"]) {
        key = dark ? @"mm_host_border_alpha_dark" : @"mm_host_border_alpha_light";
        title = dark ? @"底栏描边透明度（深色模式）" : @"底栏描边透明度（浅色模式）";
        placeholder = @"底栏描边透明度 %";
        fallback = dark ? 0.12 : 0.22;
    } else if ([type isEqualToString:@"capsule_border"]) {
        key = dark ? @"mm_capsule_border_alpha_dark" : @"mm_capsule_border_alpha_light";
        title = dark ? @"胶囊描边透明度（深色模式）" : @"胶囊描边透明度（浅色模式）";
        placeholder = @"胶囊描边透明度 %";
        fallback = dark ? 0.12 : 0.24;
    } else if ([type isEqualToString:@"glow_top"]) {
        key = dark ? @"mm_glow_top_alpha_dark" : @"mm_glow_top_alpha_light";
        title = dark ? @"高光顶部透明度（深色模式）" : @"高光顶部透明度（浅色模式）";
        placeholder = @"高光顶部透明度 %";
        fallback = 0.10;
    } else if ([type isEqualToString:@"glow_mid"]) {
        key = dark ? @"mm_glow_mid_alpha_dark" : @"mm_glow_mid_alpha_light";
        title = dark ? @"高光中段透明度（深色模式）" : @"高光中段透明度（浅色模式）";
        placeholder = @"高光中段透明度 %";
        fallback = 0.03;
    }

    MMShowNamedAlphaAlert(vc, key, title, placeholder, fallback);
}

static void MMShowColorMenu(UIViewController *vc) {
    if (!vc) return;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:(MMIsDark(vc.traitCollection) ? @"颜色设置（深色模式）" : @"颜色设置（浅色模式）") message:@"调用系统取色盘" preferredStyle:UIAlertControllerStyleActionSheet];

    [menu addAction:[UIAlertAction actionWithTitle:@"背景颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_bg_color", MMBackgroundTintColor(vc.traitCollection), @"背景颜色");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"胶囊颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_capsule_color", MMCapsuleTintColor(vc.traitCollection), @"胶囊颜色");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"选中图标文字颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_selected_color", MMSelectedColor(vc.traitCollection), @"选中颜色");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"未选中图标文字颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_normal_color", MMNormalColor(vc.traitCollection), @"未选中颜色");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"恢复当前模式默认颜色" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        MMRemoveColor(@"mm_bg_color", vc.traitCollection);
        MMRemoveColor(@"mm_capsule_color", vc.traitCollection);
        MMRemoveColor(@"mm_selected_color", vc.traitCollection);
        MMRemoveColor(@"mm_normal_color", vc.traitCollection);
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"返回" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        popover.sourceView = vc.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMaxY(vc.view.bounds) - 80.0, 1.0, 1.0);
    }
    [vc presentViewController:menu animated:YES completion:nil];
}

static void MMShowSettingsMenu(UIViewController *vc) {
    if (!vc || kMMSettingsPresented) return;
    kMMSettingsPresented = YES;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"LiquidGlass 设置" message:@"当前模式单独保存" preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改底栏背景透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"bg");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改胶囊透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"capsule");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改底栏描边透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"host_border");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改胶囊描边透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"capsule_border");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改高光顶部透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"glow_top");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改高光中段透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"glow_mid");
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"修改颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowColorMenu(vc);
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        popover.sourceView = vc.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMaxY(vc.view.bounds) - 80.0, 1.0, 1.0);
    }
    [vc presentViewController:menu animated:YES completion:nil];
}

static UIView *MMNativeBackdropHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMNativeBackdropHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMNativeBackdropHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = NO;
        host.clipsToBounds = YES;
        [root addSubview:host];

        UIView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
        blur.tag = kMMNativeBackdropBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        [host addSubview:blur];

        UIView *tint = [UIView new];
        tint.tag = kMMNativeBackdropTintTag;
        tint.userInteractionEnabled = NO;
        [host addSubview:tint];
    }
    return host;
}

static void MMUpdateNativeBackdrop(UIViewController *vc, UITabBar *tabBar) {
    if (!vc || !vc.isViewLoaded || !tabBar) return;
    UIView *root = vc.view;
    UIView *host = MMNativeBackdropHost(root);

    CGFloat inset = MMBottomInset(root);
    CGFloat floatingHeight = 72.0;
    CGFloat floatingY = CGRectGetHeight(root.bounds) - inset - floatingHeight - 14.0;

    CGFloat blurTop = floatingY - 12.0;
    CGFloat blurHeight = CGRectGetHeight(root.bounds) - blurTop;

    host.frame = CGRectMake(0.0, blurTop, CGRectGetWidth(root.bounds), blurHeight);
    host.layer.cornerRadius = 0.0;
    host.layer.masksToBounds = YES;

    UIView *blur = [host viewWithTag:kMMNativeBackdropBlurTag];
    blur.frame = host.bounds;
    if ([blur isKindOfClass:[UIVisualEffectView class]]) {
        if (MMIsDark(root.traitCollection)) {
            ((UIVisualEffectView *)blur).effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        } else {
            ((UIVisualEffectView *)blur).effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        }
    }
    blur.layer.cornerRadius = 0.0;
    blur.layer.masksToBounds = YES;

    UIView *tint = [host viewWithTag:kMMNativeBackdropTintTag];
    tint.frame = host.bounds;
    tint.backgroundColor = MMIsDark(root.traitCollection) ? MMRGBA(255, 255, 255, 0.0008) : MMRGBA(255, 255, 255, 0.008);

    host.alpha = MMIsDark(root.traitCollection) ? 0.016 : 0.055;

    CAGradientLayer *fade = MMEnsureGradient(host, @"native_backdrop_fade");
    fade.frame = host.bounds;
    fade.startPoint = CGPointMake(0.5, 0.0);
    fade.endPoint = CGPointMake(0.5, 1.0);
    fade.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.24].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor
    ];
    fade.locations = @[@0.0, @0.16, @1.0];
    host.layer.mask = fade;

    [root insertSubview:host belowSubview:MMHost(root)];
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

        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:MMSharedGestureProxy() action:@selector(handleLongPress:)];
        [host addGestureRecognizer:press];
    }
    return host;
}

static UIVisualEffectView *MMBlur(UIView *host) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMFloatingBlurTag];
    if (!blur) {
        UIBlurEffectStyle style = MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
        blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
        blur.tag = kMMFloatingBlurTag;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];
    }
    blur.frame = host.bounds;

    UIBlurEffectStyle style = MMIsDark(host.traitCollection) ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight;
    blur.effect = [UIBlurEffect effectWithStyle:style];

    UIColor *tint = MMBackgroundTintColor(host.traitCollection);
    CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
    [tint getRed:&r green:&g blue:&b alpha:&a];
    blur.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:(MMIsDark(host.traitCollection) ? 0.028 : 0.040)];

    MMSetRadius(blur, host.bounds.size.height * 0.5);
    blur.layer.masksToBounds = YES;
    blur.clipsToBounds = YES;
    blur.layer.cornerRadius = host.bounds.size.height * 0.5;
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
    host.backgroundColor = [UIColor clearColor];
    host.layer.borderWidth = 0.0;
    host.layer.borderColor = [UIColor clearColor].CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:(MMIsDark(host.traitCollection) ? 0.022 : 0.006)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 2.2;
    host.layer.shadowOffset = CGSizeMake(0, 0.7);
    MMApplyLiquidGlass(host, NO);
}

static CGRect MMSlotFrame(UIView *host, NSInteger index, NSInteger count) {
    CGFloat hostW = CGRectGetWidth(host.bounds);
    CGFloat hostH = CGRectGetHeight(host.bounds);
    CGFloat top = 5.0;
    CGFloat slotH = hostH - top * 2.0;

    CGFloat sideInset = 20.0;
    CGFloat interGap = 12.0;
    CGFloat usableW = hostW - sideInset * 2.0 - interGap * (MAX(count, 1) - 1);
    CGFloat slotW = floor(usableW / MAX(count, 1));

    CGFloat x = sideInset + index * (slotW + interGap);
    if (index == count - 1) {
        slotW = hostW - sideInset - x;
    }
    return CGRectMake(x, top, slotW, slotH);
}

static CGRect MMCapsuleFrame(UIView *host, NSInteger index, NSInteger count) {
    CGRect slot = MMSlotFrame(host, index, count);
    CGFloat hostH = CGRectGetHeight(host.bounds);
    CGFloat verticalInset = 8.2;
    CGFloat targetHeight = hostH - verticalInset * 2.0;
    CGFloat targetWidth = MIN(CGRectGetWidth(slot) + 14.0, MAX(CGRectGetWidth(slot) + 9.0, targetHeight * 1.54));
    CGFloat x = CGRectGetMidX(slot) - targetWidth * 0.5;
    return CGRectMake(x, verticalInset, targetWidth, targetHeight);
}

static void MMStyleCapsule(UIView *host, NSInteger selectedIndex, NSInteger count) {
    if (count <= 0) return;

    UIView *capsule = MMCapsule(host);
    CGRect frame = MMCapsuleFrame(host, selectedIndex, count);
    capsule.frame = frame;
    MMSetRadius(capsule, frame.size.height * 0.5);
    capsule.clipsToBounds = NO;
    capsule.layer.masksToBounds = NO;

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.backgroundColor = [UIColor clearColor];
    border.layer.borderWidth = 0.0;

    UIView *glow = [capsule viewWithTag:kMMFloatingCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 2.2, 2.2);
    MMSetRadius(glow, glow.bounds.size.height * 0.5);
    glow.backgroundColor = [UIColor clearColor];
    glow.clipsToBounds = YES;

    MMApplyLiquidGlass(capsule, YES);
}

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
        button.mm_imageView = imageView;
        [button addSubview:imageView];

        UILabel *titleLabel = [UILabel new];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.72;
        titleLabel.backgroundColor = [UIColor clearColor];
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

static NSArray *MMOriginalItemViews(UITabBar *tabBar) {
    NSMutableArray *items = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBarItemView"]) [items addObject:sub];
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
                if (tabBar && index >= 0 && index < (NSInteger)[tabBar.items count]) {
                    @try { tabBar.selectedItem = [tabBar.items objectAtIndex:index]; } @catch (__unused NSException *e) {}
                }
                break;
            }
        }
    }
}


static void MMApplyButtonSelectionLayout(UIView *container, UIView *host, UITabBar *tabBar, NSArray *originalItemViews, NSInteger selectedIndex, CGRect activeCapsuleFrame, BOOL useActiveCapsuleFrame) {
    NSArray *items = tabBar.items;
    NSInteger count = items.count;

    for (NSInteger i = 0; i < count; i++) {
        MMFloatingTabButton *button = (MMFloatingTabButton *)[container viewWithTag:6000 + i];
        if (![button isKindOfClass:[MMFloatingTabButton class]]) continue;

        CGRect frame = (i == selectedIndex)
            ? (useActiveCapsuleFrame ? activeCapsuleFrame : MMCapsuleFrame(host, i, count))
            : MMSlotFrame(host, i, count);
        button.frame = frame;
        button.backgroundColor = [UIColor clearColor];

        UITabBarItem *item = [items objectAtIndex:i];
        UIView *sourceItemView = i < (NSInteger)[originalItemViews count] ? [originalItemViews objectAtIndex:i] : nil;
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

        UIColor *titleColor = MMNormalColor(host.traitCollection);
        if (i == selectedIndex) {
            UILabel *sourceLabel = MMKVC(sourceItemView, @"_textLabel");
            UIColor *sourceIconColor = ([sourceImageView isKindOfClass:[UIImageView class]] && sourceImageView.tintColor) ? sourceImageView.tintColor : nil;
            UIColor *sourceTextColor = [sourceLabel isKindOfClass:[UILabel class]] ? sourceLabel.textColor : nil;
            UIColor *fallbackSelected = MMSelectedColor(host.traitCollection);
            button.mm_imageView.tintColor = sourceIconColor ?: fallbackSelected;
            button.mm_titleLabel.text = item.title ?: @"";
            button.mm_titleLabel.textColor = sourceTextColor ?: button.mm_imageView.tintColor ?: fallbackSelected;
        } else {
            button.mm_imageView.tintColor = titleColor;
            button.mm_titleLabel.text = item.title ?: @"";
            button.mm_titleLabel.textColor = titleColor;
        }
        button.mm_titleLabel.font = [UIFont systemFontOfSize:11.0 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightRegular)];

        NSString *badge = item.badgeValue;
        if ([badge length] > 0) {
            button.mm_badgeLabel.hidden = NO;
            button.mm_badgeLabel.text = badge;
        } else {
            button.mm_badgeLabel.hidden = YES;
            button.mm_badgeLabel.text = nil;
        }

        CGFloat bw = button.bounds.size.width;
        CGFloat bh = button.bounds.size.height;
        CGFloat iconSize = 26.0;
        CGFloat titleH = 15.0;
        CGFloat spacing = 3.0;
        CGFloat totalH = button.mm_imageView.hidden ? titleH : (iconSize + spacing + titleH);
        CGFloat startY = floor((bh - totalH) * 0.5);
        if (startY < 4.0) startY = 4.0;

        if (!button.mm_imageView.hidden) {
            button.mm_imageView.frame = CGRectMake(floor((bw - iconSize) * 0.5), startY, iconSize, iconSize);
            button.mm_titleLabel.frame = CGRectMake(0.0, startY + iconSize + spacing, bw, titleH);
        } else {
            button.mm_titleLabel.frame = CGRectMake(0.0, floor((bh - titleH) * 0.5), bw, titleH);
        }

        CGFloat badgeW = MAX(18.0, MIN(28.0, 10.0 + [badge length] * 8.0));
        if (!button.mm_imageView.hidden) {
            button.mm_badgeLabel.frame = CGRectMake(CGRectGetMaxX(button.mm_imageView.frame) - 2.0, CGRectGetMinY(button.mm_imageView.frame) - 4.0, badgeW, 18.0);
        }
        MMSetRadius(button.mm_badgeLabel, 9.0);
    }
}

static void MMUpdateButtons(UIViewController *vc, UITabBar *tabBar, UIView *host) {
    UIView *container = MMButtonsContainer(host);
    NSArray *items = tabBar.items;
    NSArray *originalItemViews = MMOriginalItemViews(tabBar);
    NSInteger count = [items count];
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    MMStyleCapsule(host, selectedIndex, count);

    UIPanGestureRecognizer *pan = nil;
    for (UIGestureRecognizer *gr in host.gestureRecognizers) {
        if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) {
            pan = (UIPanGestureRecognizer *)gr;
            break;
        }
    }
    if (!pan) {
        pan = [[UIPanGestureRecognizer alloc] initWithTarget:MMSharedFloatingDragProxy() action:@selector(handlePan:)];
        pan.maximumNumberOfTouches = 1;
        pan.cancelsTouchesInView = NO;
        [host addGestureRecognizer:pan];
    }
    MMSharedFloatingDragProxy().mainTabVC = vc;
    MMSharedFloatingDragProxy().currentIndex = selectedIndex;

    NSMutableSet *validTags = [NSMutableSet set];
    for (NSInteger i = 0; i < count; i++) {
        [validTags addObject:[NSNumber numberWithInteger:(6000 + i)]];
        MMFloatingTabButton *button = MMEnsureButton(container, i);
        button.mm_index = i;
        [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            MMSelectIndex(button, button.mm_index);
        }] forControlEvents:UIControlEventTouchUpInside];
    }

    MMApplyButtonSelectionLayout(container, host, tabBar, originalItemViews, selectedIndex, CGRectZero, NO);

    for (UIView *sub in [[container subviews] copy]) {
        if (![validTags containsObject:[NSNumber numberWithInteger:sub.tag]]) {
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

static UIView *MMDockSearchHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMDockSearchHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMDockSearchHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = YES;
        host.clipsToBounds = NO;
        [root addSubview:host];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        blur.tag = kMMDockSearchBlurTag;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];

        UIImageView *icon = [UIImageView new];
        icon.tag = kMMDockSearchIconTag;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.userInteractionEnabled = NO;
        [host addSubview:icon];

        UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
        hit.tag = kMMDockSearchHitButtonTag;
        hit.backgroundColor = [UIColor clearColor];
        [host addSubview:hit];
    }
    return host;
}



static void MMOpenSearchFromMainTab(UIViewController *vc) {
    if (!vc) return;

    UIViewController *targetVC = MMFindHomeContentControllerFromController(vc);
    if (!targetVC) targetVC = vc;

    if ([targetVC respondsToSelector:@selector(onTapOnSearchButton)]) {
        ((void (*)(id, SEL))objc_msgSend)(targetVC, @selector(onTapOnSearchButton));
    }
}

static void MMSetFloatingVisible(UIView *host, UIView *dockHost, BOOL visible) {
    CGFloat targetAlpha = visible ? 1.0 : 0.0;

    if (host) {
        if (visible) host.hidden = NO;
        if (fabs(host.alpha - targetAlpha) > 0.01) {
            [UIView animateWithDuration:0.14 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{
                host.alpha = targetAlpha;
            } completion:^(BOOL finished) {
                if (finished && !visible) host.hidden = YES;
            }];
        } else {
            host.alpha = targetAlpha;
            host.hidden = !visible;
        }
        host.userInteractionEnabled = visible;
    }

    if (dockHost) {
        if (visible) dockHost.hidden = NO;
        if (fabs(dockHost.alpha - targetAlpha) > 0.01) {
            [UIView animateWithDuration:0.14 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction animations:^{
                dockHost.alpha = targetAlpha;
            } completion:^(BOOL finished) {
                if (finished && !visible) dockHost.hidden = YES;
            }];
        } else {
            dockHost.alpha = targetAlpha;
            dockHost.hidden = !visible;
        }
        dockHost.userInteractionEnabled = visible;
    }
}

static void MMUpdateDockSearchButton(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;

    UIView *root = vc.view;
    UIViewController *homeVC = MMFindHomeContentControllerFromController(vc);
    UIView *searchBar = homeVC ? MMFindSearchBarInView(homeVC.view) : nil;

    UIView *host = MMDockSearchHost(root);
    if (!searchBar) {
        MMSetFloatingVisible(nil, host, NO);
        return;
    }

    CGFloat inset = MMBottomInset(root);
    CGFloat margin = 18.0;
    CGFloat dockSize = 72.0;
    CGFloat y = CGRectGetHeight(root.bounds) - inset - dockSize - 14.0;
    CGFloat x = CGRectGetWidth(root.bounds) - margin - dockSize;

    host.frame = CGRectMake(x, y, dockSize, dockSize);
    host.hidden = NO;
    host.alpha = 1.0;
    host.userInteractionEnabled = YES;
    MMSetRadius(host, dockSize * 0.5);
    if (@available(iOS 13.0, *)) host.layer.cornerCurve = kCACornerCurveContinuous;
    host.layer.borderWidth = 0.0;
    host.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:(MMIsDark(host.traitCollection) ? 0.018 : 0.006)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 1.8;
    host.layer.shadowOffset = CGSizeMake(0, 0.6);
    MMApplyLiquidGlass(host, NO);

    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMDockSearchBlurTag];
    blur.frame = host.bounds;
    UIColor *tint = MMBackgroundTintColor(host.traitCollection);
    CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
    [tint getRed:&r green:&g blue:&b alpha:&a];
    blur.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:(MMIsDark(host.traitCollection) ? 0.018 : 0.022)];
    MMSetRadius(blur, dockSize * 0.5);
    if (@available(iOS 13.0, *)) blur.layer.cornerCurve = kCACornerCurveContinuous;
    blur.layer.masksToBounds = YES;
    blur.clipsToBounds = YES;
    blur.layer.cornerRadius = host.bounds.size.height * 0.5;

    UIImageView *icon = (UIImageView *)[host viewWithTag:kMMDockSearchIconTag];
    icon.frame = CGRectMake(floor((dockSize - 29.0) * 0.5), floor((dockSize - 29.0) * 0.5), 29.0, 29.0);
    icon.tintColor = MMIsDark(host.traitCollection) ? MMRGBA(255, 255, 255, 0.88) : MMRGBA(106, 110, 120, 0.80);
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } else {
        icon.image = nil;
    }

    UIButton *hit = (UIButton *)[host viewWithTag:kMMDockSearchHitButtonTag];
    hit.frame = host.bounds;
    [hit removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    MMDockSearchTapProxy *proxy = MMSharedDockSearchTapProxy();
    proxy.mainTabVC = vc;
    [hit addTarget:proxy action:@selector(handleTap:) forControlEvents:UIControlEventTouchUpInside];

    UIView *nativeBackdropNow = [root viewWithTag:kMMNativeBackdropHostTag];
    if (nativeBackdropNow) [root insertSubview:nativeBackdropNow belowSubview:host];
    [root bringSubviewToFront:host];
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc) return;
    if (kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!root || !tabBar) {
        kMMUpdatingLayout = NO;
        return;
    }

    UIView *host = MMHost(root);
    UIView *nativeBackdrop = [root viewWithTag:kMMNativeBackdropHostTag];
    UIView *dockHost = [root viewWithTag:kMMDockSearchHostTag];

    if (MMShouldHideFloatingBar(vc)) {
        tabBar.hidden = NO;
        MMHideOriginalTabBarVisuals(tabBar);
        if (nativeBackdrop) {
            nativeBackdrop.hidden = YES;
            nativeBackdrop.alpha = 0.0;
        }
        MMSetFloatingVisible(host, dockHost, NO);
        kMMUpdatingLayout = NO;
        return;
    }

    CGFloat inset = MMBottomInset(root);
    CGFloat margin = 18.0;
    CGFloat gap = 10.0;
    CGFloat dockSize = 72.0;
    CGFloat height = 74.0;
    CGFloat y = CGRectGetHeight(root.bounds) - inset - height - 14.0;

    UIViewController *homeVC = MMFindHomeContentControllerFromController(vc);
    UIView *searchBar = homeVC ? MMFindSearchBarInView(homeVC.view) : nil;
    BOOL showDockSearch = (searchBar != nil);

    CGFloat hostWidth = CGRectGetWidth(root.bounds) - margin * 2.0 - (showDockSearch ? (dockSize + gap) : 0.0);
    CGRect frame = CGRectMake(margin, y, hostWidth, height);

    host.frame = frame;

    tabBar.hidden = NO;
    tabBar.transform = CGAffineTransformIdentity;
    tabBar.frame = frame;

    MMUpdateNativeBackdrop(vc, tabBar);
    UIView *nativeBackdropNow = [root viewWithTag:kMMNativeBackdropHostTag];
    nativeBackdropNow.hidden = NO;
    nativeBackdropNow.alpha = 1.0;

    MMStyleHost(host);
    MMBlur(host);
    MMHideOriginalTabBarVisuals(tabBar);
    MMUpdateButtons(vc, tabBar, host);

    MMSetFloatingVisible(host, nil, YES);
    host.hidden = NO;
    host.alpha = 1.0;
    [root bringSubviewToFront:host];
    MMUpdateDockSearchButton(vc);
    UIView *dockHostNow = [root viewWithTag:kMMDockSearchHostTag];
    if (dockHostNow) {
        dockHostNow.hidden = NO;
        dockHostNow.alpha = 1.0;
        [root bringSubviewToFront:dockHostNow];
    }

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
