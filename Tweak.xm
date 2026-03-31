#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kMMGlassBarTag = 880001;
static NSInteger const kMMGlassStrokeTag = 880002;
static NSInteger const kMMGlassButtonsTag = 880003;

static NSInteger const kMMCloneBaseTag = 881000;
static NSInteger const kMMPillTag = 881001;
static NSInteger const kMMIconTag = 881002;
static NSInteger const kMMTitleTag = 881003;
static NSInteger const kMMDotTag = 881004;
static NSInteger const kMMBadgeTag = 881005;

@interface MMTabBarController : UIViewController
@property (nonatomic, assign) NSUInteger selectedIndex;
@end

@interface MMTabBarController (MMGlassInternal)
- (UITabBar *)mm_realTabBar;
- (UIBlurEffectStyle)mm_blurStyle;
- (UIColor *)mm_strokeColor;
- (UIColor *)mm_pillColor;
- (UIColor *)mm_activeTextColor;
- (UIColor *)mm_inactiveTextColor;
- (UIVisualEffectView *)mm_ensureGlassBar;
- (UIButton *)mm_makeButtonAtIndex:(NSInteger)idx;
- (void)mm_bounceButton:(UIButton *)button;
- (void)mm_handleCloneTap:(UIButton *)sender;
- (NSString *)mm_normalizedBadgeValue:(NSString *)badgeValue;
- (UIImage *)mm_imageForItem:(UITabBarItem *)item selected:(BOOL)selected;
- (void)mm_reloadCloneButtonsAnimated:(BOOL)animated;
- (void)mm_updateGlassFrameAndAppearance;
- (void)mm_prepareRealTabBarForCarrierMode;
@end

%hook MMTabBarController

%new
- (UITabBar *)mm_realTabBar {
    UIView *root = self.view;
    if (!root) return nil;

    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:[UITabBar class]] &&
            [NSStringFromClass([v class]) containsString:@"MMTabBar"]) {
            return (UITabBar *)v;
        }
    }

    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:[UITabBar class]]) {
            return (UITabBar *)v;
        }
    }

    return nil;
}

%new
- (UIBlurEffectStyle)mm_blurStyle {
    if (@available(iOS 13.0, *)) {
        return self.view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? UIBlurEffectStyleSystemUltraThinMaterialDark
            : UIBlurEffectStyleSystemThinMaterialLight;
    }
    return UIBlurEffectStyleLight;
}

%new
- (UIColor *)mm_strokeColor {
    if (@available(iOS 13.0, *)) {
        return self.view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.10]
            : [UIColor colorWithWhite:1.0 alpha:0.35];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.30];
}

%new
- (UIColor *)mm_pillColor {
    if (@available(iOS 13.0, *)) {
        return self.view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.12]
            : [UIColor colorWithWhite:1.0 alpha:0.22];
    }
    return [UIColor colorWithWhite:1.0 alpha:0.18];
}

%new
- (UIColor *)mm_activeTextColor {
    if (@available(iOS 13.0, *)) return UIColor.labelColor;
    return UIColor.blackColor;
}

%new
- (UIColor *)mm_inactiveTextColor {
    if (@available(iOS 13.0, *)) return [UIColor.secondaryLabelColor colorWithAlphaComponent:0.95];
    return [UIColor colorWithWhite:0 alpha:0.60];
}

%new
- (UIVisualEffectView *)mm_ensureGlassBar {
    UIView *root = self.view;
    if (!root) return nil;

    UIVisualEffectView *glass = (UIVisualEffectView *)[root viewWithTag:kMMGlassBarTag];
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:[self mm_blurStyle]]];
        glass.tag = kMMGlassBarTag;
        glass.clipsToBounds = YES;
        glass.layer.masksToBounds = YES;
        [root addSubview:glass];

        UIView *stroke = [[UIView alloc] init];
        stroke.tag = kMMGlassStrokeTag;
        stroke.userInteractionEnabled = NO;
        stroke.backgroundColor = UIColor.clearColor;
        [glass.contentView addSubview:stroke];

        UIView *buttons = [[UIView alloc] init];
        buttons.tag = kMMGlassButtonsTag;
        buttons.backgroundColor = UIColor.clearColor;
        [glass.contentView addSubview:buttons];
    }

    return glass;
}

%new
- (UIButton *)mm_makeButtonAtIndex:(NSInteger)idx {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = kMMCloneBaseTag + idx;
    btn.adjustsImageWhenHighlighted = NO;
    btn.backgroundColor = UIColor.clearColor;
    btn.clipsToBounds = NO;

    UIView *pill = [[UIView alloc] init];
    pill.tag = kMMPillTag;
    pill.hidden = YES;
    pill.alpha = 0.0;
    pill.userInteractionEnabled = NO;
    [btn addSubview:pill];

    UIImageView *icon = [[UIImageView alloc] init];
    icon.tag = kMMIconTag;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [btn addSubview:icon];

    UILabel *title = [[UILabel alloc] init];
    title.tag = kMMTitleTag;
    title.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    title.numberOfLines = 1;
    [btn addSubview:title];

    UIView *dot = [[UIView alloc] init];
    dot.tag = kMMDotTag;
    dot.hidden = YES;
    dot.backgroundColor = [UIColor systemRedColor];
    dot.layer.cornerRadius = 5.0;
    [btn addSubview:dot];

    UILabel *badge = [[UILabel alloc] init];
    badge.tag = kMMBadgeTag;
    badge.hidden = YES;
    badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.textColor = UIColor.whiteColor;
    badge.backgroundColor = [UIColor systemRedColor];
    badge.clipsToBounds = YES;
    [btn addSubview:badge];

    [btn addTarget:self action:@selector(mm_handleCloneTap:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

%new
- (void)mm_bounceButton:(UIButton *)button {
    [UIView animateWithDuration:0.10 animations:^{
        button.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(__unused BOOL finished) {
        [UIView animateWithDuration:0.22
                              delay:0
             usingSpringWithDamping:0.68
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            button.transform = CGAffineTransformIdentity;
        } completion:nil];
    }];
}

%new
- (void)mm_handleCloneTap:(UIButton *)sender {
    NSInteger idx = sender.tag - kMMCloneBaseTag;
    UITabBar *tabBar = [self mm_realTabBar];
    if (!tabBar) return;
    if (idx < 0) return;
    if (idx >= (NSInteger)tabBar.items.count) return;

    [self mm_bounceButton:sender];

    UITabBarItem *item = tabBar.items[idx];
    if (item) {
        tabBar.selectedItem = item;
    }

    self.selectedIndex = idx;
    [self mm_reloadCloneButtonsAnimated:YES];
}

%new
- (NSString *)mm_normalizedBadgeValue:(NSString *)badgeValue {
    if (![badgeValue isKindOfClass:[NSString class]]) return nil;
    if (badgeValue.length == 0) return nil;
    return badgeValue;
}

%new
- (UIImage *)mm_imageForItem:(UITabBarItem *)item selected:(BOOL)selected {
    UIImage *img = selected ? item.selectedImage : item.image;
    if (!img) img = item.image ?: item.selectedImage;
    if (!img) return nil;
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

%new
- (void)mm_reloadCloneButtonsAnimated:(BOOL)animated {
    UITabBar *tabBar = [self mm_realTabBar];
    UIView *root = self.view;
    UIVisualEffectView *glass = (UIVisualEffectView *)[root viewWithTag:kMMGlassBarTag];
    UIView *buttonsWrap = [glass.contentView viewWithTag:kMMGlassButtonsTag];
    if (!tabBar || !glass || !buttonsWrap) return;

    NSArray<UITabBarItem *> *items = tabBar.items;
    NSInteger count = items.count;
    if (count <= 0) return;

    while (buttonsWrap.subviews.count < count) {
        UIButton *btn = [self mm_makeButtonAtIndex:buttonsWrap.subviews.count];
        [buttonsWrap addSubview:btn];
    }

    while (buttonsWrap.subviews.count > count) {
        [buttonsWrap.subviews.lastObject removeFromSuperview];
    }

    CGFloat totalW = buttonsWrap.bounds.size.width;
    CGFloat totalH = buttonsWrap.bounds.size.height;
    CGFloat itemW = totalW / MAX(count, 1);

    for (NSInteger i = 0; i < count; i++) {
        UITabBarItem *item = items[i];
        UIButton *btn = (UIButton *)[buttonsWrap viewWithTag:kMMCloneBaseTag + i];
        if (!btn) continue;

        BOOL selected = (self.selectedIndex == i) || (tabBar.selectedItem == item);

        btn.frame = CGRectMake(i * itemW, 0, itemW, totalH);

        UIView *pill = [btn viewWithTag:kMMPillTag];
        UIImageView *icon = (UIImageView *)[btn viewWithTag:kMMIconTag];
        UILabel *title = (UILabel *)[btn viewWithTag:kMMTitleTag];
        UIView *dot = [btn viewWithTag:kMMDotTag];
        UILabel *badge = (UILabel *)[btn viewWithTag:kMMBadgeTag];

        CGFloat pillW = MIN(58.0, MAX(46.0, itemW - 18.0));
        CGFloat pillH = 36.0;
        pill.frame = CGRectMake((itemW - pillW) * 0.5, 6.0, pillW, pillH);
        pill.layer.cornerRadius = pillH * 0.5;
        pill.backgroundColor = [self mm_pillColor];

        CGFloat iconSize = 24.0;
        CGFloat iconY = selected ? 12.0 : 11.0;
        icon.frame = CGRectMake((itemW - iconSize) * 0.5, iconY, iconSize, iconSize);
        icon.image = [self mm_imageForItem:item selected:selected];
        icon.alpha = selected ? 1.0 : 0.76;

        title.frame = CGRectMake(4.0, CGRectGetMaxY(icon.frame) + 3.0, itemW - 8.0, 12.0);
        title.text = item.title ?: @"";
        title.textColor = selected ? [self mm_activeTextColor] : [self mm_inactiveTextColor];
        title.alpha = selected ? 1.0 : 0.92;

        NSString *badgeValue = [self mm_normalizedBadgeValue:item.badgeValue];
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
        dot.frame = CGRectMake(CGRectGetMaxX(icon.frame) - 1.0, CGRectGetMinY(icon.frame) - 1.0, 10.0, 10.0);

        badge.hidden = !showBadge;
        if (showBadge) {
            badge.text = badgeValue;
            CGSize size = [badgeValue sizeWithAttributes:@{NSFontAttributeName: badge.font}];
            CGFloat bw = MAX(18.0, size.width + 10.0);
            CGFloat bh = 18.0;
            badge.frame = CGRectMake(CGRectGetMaxX(icon.frame) - 2.0, CGRectGetMinY(icon.frame) - 4.0, bw, bh);
            badge.layer.cornerRadius = bh * 0.5;
        }

        void (^applyBlock)(void) = ^{
            pill.hidden = NO;
            pill.alpha = selected ? 1.0 : 0.0;
        };

        if (animated) {
            [UIView animateWithDuration:0.22
                                  delay:0
                 usingSpringWithDamping:0.82
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:applyBlock
                             completion:^(__unused BOOL finished) {
                pill.hidden = !selected;
            }];
        } else {
            applyBlock();
            pill.hidden = !selected;
        }
    }
}

%new
- (void)mm_updateGlassFrameAndAppearance {
    UIView *root = self.view;
    UIVisualEffectView *glass = [self mm_ensureGlassBar];
    if (!root || !glass) return;

    glass.effect = [UIBlurEffect effectWithStyle:[self mm_blurStyle]];

    CGFloat margin = 18.0;
    CGFloat height = 72.0;
    CGFloat bottomGap = 8.0;
    CGFloat bottomInset = root.safeAreaInsets.bottom;
    CGFloat y = root.bounds.size.height - bottomInset - height - bottomGap;

    glass.frame = CGRectMake(margin, y, root.bounds.size.width - margin * 2.0, height);
    glass.layer.cornerRadius = height * 0.5;

    UIView *stroke = [glass.contentView viewWithTag:kMMGlassStrokeTag];
    stroke.frame = glass.contentView.bounds;
    stroke.layer.cornerRadius = glass.layer.cornerRadius;
    stroke.layer.borderWidth = 0.6;
    stroke.layer.borderColor = [self mm_strokeColor].CGColor;

    UIView *buttonsWrap = [glass.contentView viewWithTag:kMMGlassButtonsTag];
    buttonsWrap.frame = glass.contentView.bounds;
}

%new
- (void)mm_prepareRealTabBarForCarrierMode {
    UITabBar *tabBar = [self mm_realTabBar];
    UIView *root = self.view;
    if (!tabBar || !root) return;

    tabBar.hidden = NO;
    tabBar.alpha = 0.01;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = UIColor.clearColor;
    tabBar.opaque = NO;
    tabBar.clipsToBounds = NO;
    tabBar.userInteractionEnabled = NO;

    CGRect f = tabBar.frame;
    f.origin.y = root.bounds.size.height - f.size.height;
    tabBar.frame = f;

    [root sendSubviewToBack:tabBar];
}

- (void)viewDidLayoutSubviews {
    %orig;

    [self mm_prepareRealTabBarForCarrierMode];
    [self mm_updateGlassFrameAndAppearance];
    [self mm_reloadCloneButtonsAnimated:NO];

    UIView *root = self.view;
    UIVisualEffectView *glass = (UIVisualEffectView *)[root viewWithTag:kMMGlassBarTag];
    if (glass) [root bringSubviewToFront:glass];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex {
    %orig;
    [self mm_reloadCloneButtonsAnimated:YES];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self mm_updateGlassFrameAndAppearance];
            [self mm_reloadCloneButtonsAnimated:NO];
        }
    }
}

%end
