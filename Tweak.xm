#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 730001;
static NSInteger const kLGStrokeTag = 730002;
static NSInteger const kLGHighlightTag = 730003;

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBarController (LiquidGlass)
- (UIVisualEffectView *)lg_glassBar;
- (UIView *)lg_strokeView;
- (UIView *)lg_highlightView;
- (NSArray<UIControl *> *)lg_tabButtons;
- (UIBlurEffectStyle)lg_blurStyle;
- (UIColor *)lg_strokeColor;
- (UIColor *)lg_highlightColor;
- (void)lg_prepareTabBar;
- (void)lg_layoutGlassBar;
- (void)lg_layoutRealButtons;
- (void)lg_updateSelectionHighlightAnimated:(BOOL)animated;
@end

%hook MMTabBarController

%new
- (UIBlurEffectStyle)lg_blurStyle {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemUltraThinMaterialDark
        : UIBlurEffectStyleSystemThinMaterialLight;
}

%new
- (UIColor *)lg_strokeColor {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.10]
        : [UIColor colorWithWhite:1.0 alpha:0.30];
}

%new
- (UIColor *)lg_highlightColor {
    return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : [UIColor colorWithWhite:1.0 alpha:0.24];
}

%new
- (UIVisualEffectView *)lg_glassBar {
    UIVisualEffectView *glass = (UIVisualEffectView *)[self.view viewWithTag:kLGGlassTag];
    if (glass) return glass;

    glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self lg_blurStyle]]];
    glass.tag = kLGGlassTag;
    glass.userInteractionEnabled = NO;
    glass.clipsToBounds = YES;
    glass.layer.masksToBounds = YES;

    UIView *stroke = [[UIView alloc] init];
    stroke.tag = kLGStrokeTag;
    stroke.userInteractionEnabled = NO;
    stroke.backgroundColor = UIColor.clearColor;
    [glass.contentView addSubview:stroke];

    UIView *highlight = [[UIView alloc] init];
    highlight.tag = kLGHighlightTag;
    highlight.userInteractionEnabled = NO;
    highlight.hidden = YES;
    [glass.contentView addSubview:highlight];

    [self.view addSubview:glass];
    return glass;
}

%new
- (UIView *)lg_strokeView {
    return [[self lg_glassBar].contentView viewWithTag:kLGStrokeTag];
}

%new
- (UIView *)lg_highlightView {
    return [[self lg_glassBar].contentView viewWithTag:kLGHighlightTag];
}

%new
- (NSArray<UIControl *> *)lg_tabButtons {
    NSMutableArray<UIControl *> *arr = [NSMutableArray array];

    for (UIView *sub in self.tabBar.subviews) {
        if (![sub isKindOfClass:[UIControl class]]) continue;
        if (CGRectGetWidth(sub.frame) < 20 || CGRectGetHeight(sub.frame) < 20) continue;
        [arr addObject:(UIControl *)sub];
    }

    [arr sortUsingComparator:^NSComparisonResult(UIControl *a, UIControl *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return arr;
}

%new
- (void)lg_prepareTabBar {
    UITabBar *tabBar = self.tabBar;
    if (!tabBar) return;

    tabBar.hidden = NO;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = UIColor.clearColor;
    tabBar.barTintColor = UIColor.clearColor;
    tabBar.translucent = YES;
    tabBar.opaque = NO;
    tabBar.clipsToBounds = NO;

    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithTransparentBackground];
        appearance.backgroundEffect = nil;
        appearance.backgroundColor = UIColor.clearColor;
        appearance.shadowColor = UIColor.clearColor;
        tabBar.standardAppearance = appearance;

        if (@available(iOS 15.0, *)) {
            tabBar.scrollEdgeAppearance = appearance;
        }
    }
}

%new
- (void)lg_layoutGlassBar {
    UITabBar *tabBar = self.tabBar;
    UIVisualEffectView *glass = [self lg_glassBar];
    if (!tabBar || !glass) return;

    CGRect sourceFrame = tabBar.frame;
    CGFloat margin = 20.0;
    CGFloat height = 62.0;
    CGFloat lift = 12.0;
    CGFloat x = margin;
    CGFloat y = CGRectGetMinY(sourceFrame) + (CGRectGetHeight(sourceFrame) - height) * 0.5 - lift;
    CGFloat width = CGRectGetWidth(self.view.bounds) - margin * 2.0;

    glass.effect = [UIBlurEffect effectWithStyle:[self lg_blurStyle]];
    glass.frame = CGRectMake(x, y, width, height);
    glass.layer.cornerRadius = height * 0.5;

    UIView *stroke = [self lg_strokeView];
    stroke.frame = glass.contentView.bounds;
    stroke.layer.cornerRadius = glass.layer.cornerRadius;
    stroke.layer.borderWidth = 0.6;
    stroke.layer.borderColor = [self lg_strokeColor].CGColor;

    UIView *highlight = [self lg_highlightView];
    highlight.backgroundColor = [self lg_highlightColor];

    [self.view bringSubviewToFront:glass];
    [self.view bringSubviewToFront:tabBar];
}

%new
- (void)lg_layoutRealButtons {
    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    if (buttons.count == 0) return;

    UIVisualEffectView *glass = [self lg_glassBar];
    CGRect glassFrame = glass.frame;

    CGFloat itemW = CGRectGetWidth(glassFrame) / MAX((NSInteger)buttons.count, 1);
    CGFloat contentOffsetY = -9.0;
    CGFloat selectedLift = -1.5;

    for (NSInteger i = 0; i < (NSInteger)buttons.count; i++) {
        UIControl *btn = buttons[i];
        BOOL selected = (i == (NSInteger)self.selectedIndex);

        CGRect f = btn.frame;
        f.origin.x = CGRectGetMinX(glassFrame) + i * itemW;
        f.size.width = itemW;
        f.origin.y = CGRectGetMinY(glassFrame) + contentOffsetY + (selected ? selectedLift : 0.0);
        f.size.height = CGRectGetHeight(glassFrame) + 10.0;
        btn.frame = f;

        btn.alpha = 1.0;
        btn.hidden = NO;
        btn.transform = CGAffineTransformIdentity;
        btn.clipsToBounds = NO;
    }
}

%new
- (void)lg_updateSelectionHighlightAnimated:(BOOL)animated {
    NSArray<UIControl *> *buttons = [self lg_tabButtons];
    UIView *highlight = [self lg_highlightView];
    UIVisualEffectView *glass = [self lg_glassBar];

    if (buttons.count == 0 || self.selectedIndex >= buttons.count) {
        highlight.hidden = YES;
        return;
    }

    UIControl *selectedButton = buttons[self.selectedIndex];
    CGRect r = [glass.contentView convertRect:selectedButton.frame fromView:selectedButton.superview];

    CGFloat pillW = MIN(62.0, MAX(48.0, CGRectGetWidth(r) - 16.0));
    CGFloat pillH = 38.0;
    CGRect target = CGRectMake(CGRectGetMidX(r) - pillW * 0.5, 6.5, pillW, pillH);

    highlight.layer.cornerRadius = pillH * 0.5;
    highlight.layer.borderWidth = 0.6;
    highlight.layer.borderColor = [self lg_strokeColor].CGColor;

    void (^changes)(void) = ^{
        highlight.hidden = NO;
        highlight.frame = target;
        highlight.alpha = 1.0;
    };

    if (animated) {
        [UIView animateWithDuration:0.24
                              delay:0.0
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self lg_prepareTabBar];
    [self lg_layoutGlassBar];
    [self lg_layoutRealButtons];
    [self lg_updateSelectionHighlightAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self lg_prepareTabBar];
    [self lg_layoutGlassBar];
    [self lg_layoutRealButtons];
    [self lg_updateSelectionHighlightAnimated:NO];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    [self lg_layoutRealButtons];
    [self lg_updateSelectionHighlightAnimated:YES];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    [self lg_layoutGlassBar];
    [self lg_layoutRealButtons];
    [self lg_updateSelectionHighlightAnimated:NO];
}

%end
