#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 700001;
static NSInteger const kLGStrokeTag = 700002;
static NSInteger const kLGButtonsTag = 700003;

static NSInteger const kLGButtonBaseTag = 701000;
static NSInteger const kLGPillTag = 701001;
static NSInteger const kLGIconTag = 701002;
static NSInteger const kLGTitleTag = 701003;
static NSInteger const kLGDotTag = 701004;
static NSInteger const kLGBadgeTag = 701005;

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBarController (LiquidGlass)
- (UIVisualEffectView *)lg_glassBar;
- (void)lg_prepareRealTabBar;
- (void)lg_layoutGlassBar;
- (void)lg_reloadButtonsAnimated:(BOOL)animated;
- (UIButton *)lg_buildButtonAtIndex:(NSInteger)index;
- (void)lg_handleTap:(UIButton *)sender;
- (void)lg_bounce:(UIView *)view;
- (UIBlurEffectStyle)lg_blurStyle;
- (UIColor *)lg_strokeColor;
- (UIColor *)lg_pillColor;
- (UIColor *)lg_activeTextColor;
- (UIColor *)lg_inactiveTextColor;
- (UIImage *)lg_imageForItem:(UITabBarItem *)item selected:(BOOL)selected;
- (NSString *)lg_badgeValueForItem:(UITabBarItem *)item;
@end

%hook MMTabBarController

%new
- (UIBlurEffectStyle)lg_blurStyle {
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIBlurEffectStyleSystemUltraThinMaterialDark
            : UIBlurEffectStyleSystemThinMaterialLight;
    }
    return UIBlurEffectStyleLight;
}

%new
- (UIColor *)lg_strokeColor {
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1 alpha:0.10]
            : [UIColor colorWithWhite:1 alpha:0.32];
    }
    return [UIColor colorWithWhite:1 alpha:0.28];
}

%new
- (UIColor *)lg_pillColor {
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1 alpha:0.14]
            : [UIColor colorWithWhite:1 alpha:0.24];
    }
    return [UIColor colorWithWhite:1 alpha:0.20];
}

%new
- (UIColor *)lg_activeTextColor {
    if (@available(iOS 13.0, *)) return UIColor.labelColor;
    return UIColor.blackColor;
}

%new
- (UIColor *)lg_inactiveTextColor {
    if (@available(iOS 13.0, *)) return [UIColor.secondaryLabelColor colorWithAlphaComponent:0.92];
    return [UIColor colorWithWhite:0 alpha:0.58];
}

%new
- (UIImage *)lg_imageForItem:(UITabBarItem *)item selected:(BOOL)selected {
    UIImage *img = selected ? item.selectedImage : item.image;
    if (!img) img = item.image ?: item.selectedImage;
    if (!img) return nil;
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

%new
- (NSString *)lg_badgeValueForItem:(UITabBarItem *)item {
    if (![item.badgeValue isKindOfClass:[NSString class]]) return nil;
    if (item.badgeValue.length == 0) return nil;
    return item.badgeValue;
}

%new
- (UIVisualEffectView *)lg_glassBar {
    UIVisualEffectView *glass = (UIVisualEffectView *)[self.view viewWithTag:kLGGlassTag];
    if (glass) return glass;

    glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self lg_blurStyle]]];
    glass.tag = kLGGlassTag;
    glass.clipsToBounds = YES;
    glass.layer.masksToBounds = YES;
    glass.userInteractionEnabled = YES;

    UIView *stroke = [[UIView alloc] init];
    stroke.tag = kLGStrokeTag;
    stroke.userInteractionEnabled = NO;
    stroke.backgroundColor = UIColor.clearColor;
    [glass.contentView addSubview:stroke];

    UIView *buttons = [[UIView alloc] init];
    buttons.tag = kLGButtonsTag;
    buttons.backgroundColor = UIColor.clearColor;
    [glass.contentView addSubview:buttons];

    [self.view addSubview:glass];
    return glass;
}

%new
- (UIButton *)lg_buildButtonAtIndex:(NSInteger)index {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = kLGButtonBaseTag + index;
    btn.adjustsImageWhenHighlighted = NO;
    btn.backgroundColor = UIColor.clearColor;
    btn.clipsToBounds = NO;

    UIView *pill = [[UIView alloc] init];
    pill.tag = kLGPillTag;
    pill.hidden = YES;
    pill.alpha = 0.0;
    pill.userInteractionEnabled = NO;
    [btn addSubview:pill];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.tag = kLGIconTag;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [btn addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.tag = kLGTitleTag;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    title.numberOfLines = 1;
    [btn addSubview:title];

    UIView *dot = [[UIView alloc] init];
    dot.tag = kLGDotTag;
    dot.hidden = YES;
    dot.backgroundColor = UIColor.systemRedColor;
    dot.layer.cornerRadius = 5.0;
    [btn addSubview:dot];

    UILabel *badge = [[UILabel alloc] init];
    badge.tag = kLGBadgeTag;
    badge.hidden = YES;
    badge.textAlignment = NSTextAlignmentCenter;
    badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    badge.textColor = UIColor.whiteColor;
    badge.backgroundColor = UIColor.systemRedColor;
    badge.clipsToBounds = YES;
    [btn addSubview:badge];

    [btn addTarget:self action:@selector(lg_handleTap:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

%new
- (void)lg_bounce:(UIView *)view {
    [UIView animateWithDuration:0.10 animations:^{
        view.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.22
                              delay:0
             usingSpringWithDamping:0.70
              initialSpringVelocity:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

%new
- (void)lg_handleTap:(UIButton *)sender {
    NSInteger idx = sender.tag - kLGButtonBaseTag;
    NSArray<UITabBarItem *> *items = self.tabBar.items;
    if (idx < 0 || idx >= (NSInteger)items.count) return;

    [self lg_bounce:sender];

    if (self.selectedIndex != idx) {
        ((UITabBarController *)self).selectedIndex = idx;
    }

    [self lg_reloadButtonsAnimated:YES];
}

%new
- (void)lg_prepareRealTabBar {
    UITabBar *tabBar = self.tabBar;
    if (!tabBar) return;

    tabBar.hidden = NO;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = UIColor.clearColor;
    tabBar.opaque = NO;
    tabBar.clipsToBounds = NO;
    tabBar.alpha = 0.01;
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
    CGFloat y = CGRectGetMinY(sourceFrame) + (CGRectGetHeight(sourceFrame) - height) * 0.5 - lift;
    CGFloat x = margin;
    CGFloat width = CGRectGetWidth(self.view.bounds) - margin * 2.0;

    glass.effect = [UIBlurEffect effectWithStyle:[self lg_blurStyle]];
    glass.frame = CGRectMake(x, y, width, height);
    glass.layer.cornerRadius = height * 0.5;

    UIView *stroke = [glass.contentView viewWithTag:kLGStrokeTag];
    stroke.frame = glass.contentView.bounds;
    stroke.layer.cornerRadius = glass.layer.cornerRadius;
    stroke.layer.borderWidth = 0.6;
    stroke.layer.borderColor = [self lg_strokeColor].CGColor;

    UIView *buttons = [glass.contentView viewWithTag:kLGButtonsTag];
    buttons.frame = glass.contentView.bounds;

    [self.view bringSubviewToFront:glass];
}

%new
- (void)lg_reloadButtonsAnimated:(BOOL)animated {
    UIVisualEffectView *glass = [self lg_glassBar];
    UIView *buttonsWrap = [glass.contentView viewWithTag:kLGButtonsTag];
    NSArray<UITabBarItem *> *items = self.tabBar.items;

    if (!buttonsWrap || items.count == 0) return;

    while (buttonsWrap.subviews.count < items.count) {
        UIButton *btn = [self lg_buildButtonAtIndex:buttonsWrap.subviews.count];
        [buttonsWrap addSubview:btn];
    }

    while (buttonsWrap.subviews.count > items.count) {
        [buttonsWrap.subviews.lastObject removeFromSuperview];
    }

    CGFloat totalW = buttonsWrap.bounds.size.width;
    CGFloat totalH = buttonsWrap.bounds.size.height;
    CGFloat itemW = totalW / MAX(items.count, 1);

    BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        isDark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }

    for (NSInteger i = 0; i < items.count; i++) {
        UITabBarItem *item = items[i];
        UIButton *btn = (UIButton *)[buttonsWrap viewWithTag:kLGButtonBaseTag + i];
        if (!btn) continue;

        BOOL selected = (self.selectedIndex == i);
        btn.frame = CGRectMake(i * itemW, 0, itemW, totalH);

        UIView *pill = [btn viewWithTag:kLGPillTag];
        UIImageView *icon = (UIImageView *)[btn viewWithTag:kLGIconTag];
        UILabel *title = (UILabel *)[btn viewWithTag:kLGTitleTag];
        UIView *dot = [btn viewWithTag:kLGDotTag];
        UILabel *badge = (UILabel *)[btn viewWithTag:kLGBadgeTag];

        CGFloat contentOffsetY = -4.0;
        CGFloat selectedLift = selected ? -1.5 : 0.0;

        CGFloat pillW = MIN(62.0, MAX(48.0, itemW - 16.0));
        CGFloat pillH = 38.0;
        pill.frame = CGRectMake((itemW - pillW) * 0.5,
                                7.0 + contentOffsetY + selectedLift,
                                pillW,
                                pillH);
        pill.layer.cornerRadius = pillH * 0.5;
        pill.backgroundColor = selected
            ? (isDark ? [UIColor colorWithWhite:1 alpha:0.16] : [UIColor colorWithWhite:1 alpha:0.28])
            : [UIColor clearColor];
        pill.layer.borderWidth = selected ? 0.6 : 0.0;
        pill.layer.borderColor = selected
            ? (isDark ? [UIColor colorWithWhite:1 alpha:0.14].CGColor : [UIColor colorWithWhite:1 alpha:0.30].CGColor)
            : UIColor.clearColor.CGColor;

        CGFloat iconSize = selected ? 24.5 : 23.0;
        CGFloat iconY = 9.0 + contentOffsetY + selectedLift;
        icon.frame = CGRectMake((itemW - iconSize) * 0.5, iconY, iconSize, iconSize);
        icon.image = [self lg_imageForItem:item selected:selected];
        icon.alpha = selected ? 1.0 : 0.70;

        CGFloat titleY = CGRectGetMaxY(icon.frame) + 2.5;
        title.frame = CGRectMake(4.0, titleY, itemW - 8.0, 12.0);
        title.text = item.title ?: @"";
        title.textColor = selected ? [self lg_activeTextColor] : [self lg_inactiveTextColor];
        title.alpha = selected ? 1.0 : 0.88;

        NSString *badgeValue = [self lg_badgeValueForItem:item];
        BOOL showDot = NO;
        BOOL showBadge = NO;

        if (badgeValue.length > 0) {
            if ([badgeValue isEqualToString:@"•"] || [badgeValue isEqualToString:@"dot"]) {
                showDot = YES;
            } else {
                showBadge = YES;
            }
        }

        dot.hidden = !showDot;
        dot.frame = CGRectMake(CGRectGetMaxX(icon.frame) - 1.0,
                               CGRectGetMinY(icon.frame) - 1.0,
                               10.0,
                               10.0);

        badge.hidden = !showBadge;
        if (showBadge) {
            badge.text = badgeValue;
            CGSize size = [badgeValue sizeWithAttributes:@{NSFontAttributeName: badge.font}];
            CGFloat bw = MAX(18.0, size.width + 10.0);
            CGFloat bh = 18.0;
            badge.frame = CGRectMake(CGRectGetMaxX(icon.frame) - 2.0,
                                     CGRectGetMinY(icon.frame) - 4.0,
                                     bw,
                                     bh);
            badge.layer.cornerRadius = bh * 0.5;
        }

        void (^block)(void) = ^{
            pill.hidden = NO;
            pill.alpha = selected ? 1.0 : 0.0;
            icon.transform = selected ? CGAffineTransformMakeScale(1.02, 1.02) : CGAffineTransformIdentity;
            title.transform = selected ? CGAffineTransformMakeTranslation(0, -0.5) : CGAffineTransformIdentity;
        };

        if (animated) {
            [UIView animateWithDuration:0.24
                                  delay:0
                 usingSpringWithDamping:0.82
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                             animations:block
                             completion:^(__unused BOOL finished) {
                pill.hidden = !selected;
            }];
        } else {
            block();
            pill.hidden = !selected;
        }
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self lg_prepareRealTabBar];
    [self lg_layoutGlassBar];
    [self lg_reloadButtonsAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self lg_prepareRealTabBar];
    [self lg_layoutGlassBar];
    [self lg_reloadButtonsAnimated:NO];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    [self lg_reloadButtonsAnimated:YES];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self lg_layoutGlassBar];
            [self lg_reloadButtonsAnimated:NO];
        }
    }
}

%end
