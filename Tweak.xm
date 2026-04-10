#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSInteger const kMMFloatingHostTag = 991001;
static NSInteger const kMMFloatingBlurTag = 991002;
static NSInteger const kMMFloatingBarTag = 991003;
static NSInteger const kMMFloatingSearchTag = 991004;
static NSInteger const kMMFloatingBackdropTag = 991005;
static NSInteger const kMMFloatingCapsuleTag = 991006;
static NSInteger const kMMFloatingButtonBaseTag = 991100;
static NSInteger const kMMFloatingSearchIconTag = 991200;
static NSInteger const kMMFloatingSearchBorderTag = 991201;
static NSInteger const kMMFloatingBarBorderTag = 991202;
static NSInteger const kMMFloatingCapsuleBorderTag = 991203;
static NSInteger const kMMFloatingCapsuleGlowTag = 991204;
static NSInteger const kMMFloatingBarGlowTag = 991205;
static NSInteger const kMMFloatingBackdropTintTag = 991206;

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

static BOOL MMIsDark(UITraitCollection *trait) {
    if (@available(iOS 12.0, *)) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static void MMSetContinuousRadius(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static UIView *MMFloatingHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMFloatingHostTag];
    if (!host) {
        host = [[UIView alloc] initWithFrame:CGRectZero];
        host.tag = kMMFloatingHostTag;
        host.backgroundColor = UIColor.clearColor;
        host.clipsToBounds = NO;
        [root addSubview:host];
    }
    return host;
}

static UIVisualEffectView *MMBackdrop(UIView *host) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMFloatingBackdropTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingBackdropTag;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];
    }
    return blur;
}

static UIView *MMBackdropTint(UIView *host) {
    UIView *view = [host viewWithTag:kMMFloatingBackdropTintTag];
    if (!view) {
        view = [[UIView alloc] initWithFrame:CGRectZero];
        view.tag = kMMFloatingBackdropTintTag;
        view.userInteractionEnabled = NO;
        [host addSubview:view];
    }
    return view;
}

static UIVisualEffectView *MMBarBlur(UIView *host) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMFloatingBlurTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:nil];
        blur.tag = kMMFloatingBlurTag;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];
    }
    return blur;
}

static UIView *MMBar(UIView *host) {
    UIView *bar = [host viewWithTag:kMMFloatingBarTag];
    if (!bar) {
        bar = [[UIView alloc] initWithFrame:CGRectZero];
        bar.tag = kMMFloatingBarTag;
        bar.backgroundColor = UIColor.clearColor;
        [host addSubview:bar];
    }
    return bar;
}

static UIView *MMSearchDock(UIView *host) {
    UIView *dock = [host viewWithTag:kMMFloatingSearchTag];
    if (!dock) {
        dock = [[UIView alloc] initWithFrame:CGRectZero];
        dock.tag = kMMFloatingSearchTag;
        dock.backgroundColor = UIColor.clearColor;
        [host addSubview:dock];
    }
    return dock;
}

static CAShapeLayer *MMEnsureBorder(UIView *host, NSInteger tag) {
    UIView *container = [host viewWithTag:tag];
    if (![container isKindOfClass:[UIView class]]) {
        container = [[UIView alloc] initWithFrame:CGRectZero];
        container.tag = tag;
        container.userInteractionEnabled = NO;
        container.backgroundColor = UIColor.clearColor;
        [host addSubview:container];
    }
    CAShapeLayer *layer = (CAShapeLayer *)container.layer.sublayers.firstObject;
    if (![layer isKindOfClass:[CAShapeLayer class]]) {
        layer = [CAShapeLayer layer];
        [container.layer addSublayer:layer];
    }
    container.frame = host.bounds;
    layer.frame = container.bounds;
    return layer;
}

static CAGradientLayer *MMEnsureGlow(UIView *host, NSInteger tag) {
    UIView *container = [host viewWithTag:tag];
    if (![container isKindOfClass:[UIView class]]) {
        container = [[UIView alloc] initWithFrame:CGRectZero];
        container.tag = tag;
        container.userInteractionEnabled = NO;
        container.backgroundColor = UIColor.clearColor;
        container.clipsToBounds = YES;
        [host addSubview:container];
    }
    CAGradientLayer *layer = (CAGradientLayer *)container.layer.sublayers.firstObject;
    if (![layer isKindOfClass:[CAGradientLayer class]]) {
        layer = [CAGradientLayer layer];
        [container.layer addSublayer:layer];
    }
    container.frame = host.bounds;
    MMSetContinuousRadius(container, CGRectGetHeight(host.bounds) * 0.5);
    layer.frame = container.bounds;
    layer.cornerRadius = CGRectGetHeight(container.bounds) * 0.5;
    return layer;
}

static UIView *MMCapsule(UIView *bar) {
    UIView *capsule = [bar viewWithTag:kMMFloatingCapsuleTag];
    if (!capsule) {
        capsule = [[UIView alloc] initWithFrame:CGRectZero];
        capsule.tag = kMMFloatingCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = UIColor.clearColor;
        [bar addSubview:capsule];
    }
    return capsule;
}

static UIButton *MMButtonAtIndex(UIView *bar, NSInteger index) {
    NSInteger tag = kMMFloatingButtonBaseTag + index;
    UIButton *button = (UIButton *)[bar viewWithTag:tag];
    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = tag;
        button.adjustsImageWhenHighlighted = NO;
        button.backgroundColor = UIColor.clearColor;
        [bar addSubview:button];
    }
    return button;
}

static UIImageView *MMSearchIcon(UIView *dock) {
    UIImageView *icon = (UIImageView *)[dock viewWithTag:kMMFloatingSearchIconTag];
    if (!icon) {
        icon = [[UIImageView alloc] initWithFrame:CGRectZero];
        icon.tag = kMMFloatingSearchIconTag;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [dock addSubview:icon];
    }
    return icon;
}

static UIViewController *MMNearestViewController(UIView *view) {
    UIResponder *responder = view;
    while (responder) {
        responder = responder.nextResponder;
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
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

static UIView *MMImageViewInTabBarButton(UIView *button) {
    return [button mm_findSubviewPassing:^BOOL(UIView *view) {
        return [view isKindOfClass:[UIImageView class]];
    }];
}

static UILabel *MMLabelInTabBarButton(UIView *button) {
    return (UILabel *)[button mm_findSubviewPassing:^BOOL(UIView *view) {
        return [view isKindOfClass:[UILabel class]];
    }];
}

static UIImage *MMRenderedOriginalImage(UIImage *image) {
    if (!image) return nil;
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static UIColor *MMNormalTextColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.72) : MMRGBA(92, 97, 108, 0.78);
}

static UIColor *MMSearchStrokeColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.16) : MMRGBA(255, 255, 255, 0.48);
}

static UIColor *MMBarStrokeColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.12) : MMRGBA(255, 255, 255, 0.42);
}

static UIColor *MMCapsuleStrokeColor(BOOL dark) {
    return dark ? MMRGBA(255, 255, 255, 0.18) : MMRGBA(255, 255, 255, 0.62);
}

static void MMApplyMaterial(UIVisualEffectView *view, BOOL dark, CGFloat radius, CGFloat alpha) {
    view.effect = [UIBlurEffect effectWithStyle:(dark ? UIBlurEffectStyleSystemUltraThinMaterialDark : UIBlurEffectStyleSystemUltraThinMaterialLight)];
    view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:alpha];
    MMSetContinuousRadius(view, radius);
    view.clipsToBounds = YES;
}

static void MMApplyBarStyling(UIView *bar, BOOL dark) {
    bar.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(dark ? 0.06 : 0.14)];
    MMSetContinuousRadius(bar, CGRectGetHeight(bar.bounds) * 0.5);

    CAShapeLayer *border = MMEnsureBorder(bar, kMMFloatingBarBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bar.bounds, 0.35, 0.35) cornerRadius:CGRectGetHeight(bar.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = MMBarStrokeColor(dark).CGColor;
    border.lineWidth = 0.7;

    CAGradientLayer *glow = MMEnsureGlow(bar, kMMFloatingBarGlowTag);
    glow.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.38].CGColor,
        (__bridge id)[UIColor colorWithRed:(225.0 / 255.0) green:(238.0 / 255.0) blue:(252.0 / 255.0) alpha:0.16].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.02].CGColor
    ];
    glow.startPoint = CGPointMake(0.0, 0.0);
    glow.endPoint = CGPointMake(1.0, 1.0);
}

static void MMApplyCapsuleStyling(UIView *capsule, BOOL dark) {
    capsule.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(dark ? 0.08 : 0.22)];
    MMSetContinuousRadius(capsule, CGRectGetHeight(capsule.bounds) * 0.5);

    CAShapeLayer *border = MMEnsureBorder(capsule, kMMFloatingCapsuleBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(capsule.bounds, 0.3, 0.3) cornerRadius:CGRectGetHeight(capsule.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = MMCapsuleStrokeColor(dark).CGColor;
    border.lineWidth = 0.75;

    CAGradientLayer *glow = MMEnsureGlow(capsule, kMMFloatingCapsuleGlowTag);
    glow.colors = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.72].CGColor,
        (__bridge id)[UIColor colorWithRed:(233.0 / 255.0) green:(243.0 / 255.0) blue:(253.0 / 255.0) alpha:0.28].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor
    ];
    glow.startPoint = CGPointMake(0.0, 0.0);
    glow.endPoint = CGPointMake(1.0, 1.0);
}

static void MMApplySearchStyling(UIView *dock, BOOL dark) {
    dock.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(dark ? 0.06 : 0.14)];
    MMSetContinuousRadius(dock, CGRectGetHeight(dock.bounds) * 0.5);

    CAShapeLayer *border = MMEnsureBorder(dock, kMMFloatingSearchBorderTag);
    border.path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(dock.bounds, 0.35, 0.35) cornerRadius:CGRectGetHeight(dock.bounds) * 0.5].CGPath;
    border.fillColor = UIColor.clearColor.CGColor;
    border.strokeColor = MMSearchStrokeColor(dark).CGColor;
    border.lineWidth = 0.7;
}

static UIImage *MMSearchImage(BOOL dark) {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:30 weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:config];
    if (!image) image = [UIImage systemImageNamed:@"magnifyingglass"];
    if (@available(iOS 13.0, *)) {
        return [image imageWithTintColor:(dark ? UIColor.whiteColor : MMRGBA(92, 97, 108, 0.82)) renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return image;
}

static void MMHideOriginalTabBarBackground(UITabBar *tabBar) {
    if (!tabBar) return;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = UIColor.clearColor;
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;
        tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            tabBar.scrollEdgeAppearance = appearance;
        }
    }
    UIView *bg = [tabBar mm_findSubviewPassing:^BOOL(UIView *view) {
        NSString *name = NSStringFromClass(view.class);
        return [name containsString:@"Background"];
    }];
    bg.hidden = YES;
}

static CGRect MMContainerFrame(UITabBar *tabBar, UIView *root) {
    CGRect frame = [tabBar.superview convertRect:tabBar.frame toView:root];
    return frame;
}

static void MMUpdateFloatingBar(UIViewController *vc) {
    if (!vc.isViewLoaded) return;
    UIView *root = vc.view;
    UITabBar *tabBar = MMFindTabBar(vc);
    if (!root || !tabBar || tabBar.items.count == 0) return;

    MMHideOriginalTabBarBackground(tabBar);

    CGRect container = MMContainerFrame(tabBar, root);
    if (CGRectIsEmpty(container)) return;

    BOOL dark = MMIsDark(root.traitCollection);

    UIView *host = MMFloatingHost(root);
    host.frame = container;
    host.hidden = NO;
    [root bringSubviewToFront:host];

    UIVisualEffectView *backdrop = MMBackdrop(host);
    backdrop.frame = host.bounds;
    MMApplyMaterial(backdrop, dark, 0.0, dark ? 0.02 : 0.08);
    backdrop.layer.cornerRadius = 0.0;

    UIView *backdropTint = MMBackdropTint(host);
    backdropTint.frame = host.bounds;
    backdropTint.backgroundColor = dark ? [UIColor colorWithWhite:1.0 alpha:0.004] : MMRGBA(205, 228, 255, 0.12);

    CGFloat sideMargin = 14.0;
    CGFloat gap = 14.0;
    CGFloat searchSize = 64.0;
    CGFloat barHeight = 64.0;
    CGFloat barY = floor((CGRectGetHeight(container) - barHeight) * 0.5);
    CGFloat dockY = floor((CGRectGetHeight(container) - searchSize) * 0.5);
    CGFloat barX = sideMargin;
    CGFloat barWidth = CGRectGetWidth(container) - sideMargin * 2.0 - searchSize - gap;
    CGFloat searchX = CGRectGetWidth(container) - sideMargin - searchSize;

    UIVisualEffectView *barBlur = MMBarBlur(host);
    barBlur.frame = CGRectMake(barX, barY, barWidth, barHeight);
    MMApplyMaterial(barBlur, dark, barHeight * 0.5, dark ? 0.015 : 0.055);

    UIView *bar = MMBar(host);
    bar.frame = CGRectMake(barX, barY, barWidth, barHeight);
    MMApplyBarStyling(bar, dark);

    UIView *dock = MMSearchDock(host);
    dock.frame = CGRectMake(searchX, dockY, searchSize, searchSize);
    MMApplySearchStyling(dock, dark);

    UIImageView *searchIcon = MMSearchIcon(dock);
    searchIcon.image = MMSearchImage(dark);
    searchIcon.frame = CGRectMake(floor((searchSize - 30.0) * 0.5), floor((searchSize - 30.0) * 0.5), 30.0, 30.0);

    NSArray<UIControl *> *itemViews = MMTabBarItemViews(tabBar);
    NSInteger count = MIN((NSInteger)itemViews.count, 4);
    if (count <= 0) return;

    CGFloat contentLeft = 16.0;
    CGFloat contentRight = 16.0;
    CGFloat slotWidth = floor((barWidth - contentLeft - contentRight) / count);
    CGFloat slotHeight = barHeight;
    NSInteger selectedIndex = 0;
    UITabBarController *tabVC = [vc isKindOfClass:[UITabBarController class]] ? (UITabBarController *)vc : vc.tabBarController;
    if (tabVC) selectedIndex = MAX(0, MIN((NSInteger)tabVC.selectedIndex, count - 1));

    CGRect selectedSlot = CGRectMake(contentLeft + slotWidth * selectedIndex, 0.0, slotWidth, slotHeight);
    CGFloat capsuleHeight = 52.0;
    CGFloat capsuleY = floor((barHeight - capsuleHeight) * 0.5);
    CGFloat capsuleWidth = MIN(slotWidth + 18.0, MAX(capsuleHeight * 1.56, slotWidth + 10.0));
    CGFloat capsuleX = floor(CGRectGetMidX(selectedSlot) - capsuleWidth * 0.5);
    UIView *capsule = MMCapsule(bar);
    capsule.frame = CGRectMake(capsuleX, capsuleY, capsuleWidth, capsuleHeight);
    MMApplyCapsuleStyling(capsule, dark);

    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = MMButtonAtIndex(bar, i);
        if (i >= count) {
            button.hidden = YES;
            continue;
        }
        button.hidden = NO;
        CGRect slot = CGRectMake(contentLeft + slotWidth * i, 0.0, slotWidth, slotHeight);
        button.frame = slot;
        [button setImage:nil forState:UIControlStateNormal];
        [button setTitle:nil forState:UIControlStateNormal];

        UIControl *sourceView = itemViews[i];
        UIView *sourceImageView = MMImageViewInTabBarButton(sourceView);
        UILabel *sourceLabel = MMLabelInTabBarButton(sourceView);
        UITabBarItem *item = (i < tabBar.items.count) ? tabBar.items[i] : nil;
        UIImage *image = (i == selectedIndex ? item.selectedImage : item.image) ?: item.image;
        image = MMRenderedOriginalImage(image);

        [button setImage:image forState:UIControlStateNormal];
        [button setTitle:(item.title ?: @"") forState:UIControlStateNormal];

        CGFloat imageSide = 26.0;
        CGFloat imageY = 8.0;
        CGFloat titleY = 36.0;

        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightRegular)];
        UIColor *titleColor = MMNormalTextColor(dark);
        if (i == selectedIndex) {
            UIColor *sourceTextColor = sourceLabel.textColor ?: tabBar.tintColor ?: MMRGBA(7, 193, 96, 1.0);
            [button setTitleColor:sourceTextColor forState:UIControlStateNormal];
        } else {
            [button setTitleColor:titleColor forState:UIControlStateNormal];
        }

        CGFloat totalWidth = CGRectGetWidth(slot);
        button.imageEdgeInsets = UIEdgeInsetsMake(imageY, floor((totalWidth - imageSide) * 0.5), slotHeight - imageY - imageSide, floor((totalWidth - imageSide) * 0.5));
        button.titleEdgeInsets = UIEdgeInsetsMake(titleY, -button.imageView.frame.size.width, 0.0, 0.0);

        if ([sourceImageView isKindOfClass:[UIImageView class]] && sourceImageView.tintColor && image.renderingMode != UIImageRenderingModeAlwaysOriginal) {
            button.tintColor = (i == selectedIndex) ? sourceImageView.tintColor : MMNormalTextColor(dark);
        } else {
            button.tintColor = (i == selectedIndex) ? (sourceLabel.textColor ?: MMRGBA(7, 193, 96, 1.0)) : MMNormalTextColor(dark);
        }
    }
}

%hook UIViewController

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdateFloatingBar(self);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    MMUpdateFloatingBar(self);
}

%end
