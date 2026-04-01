#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 90001;
static NSInteger const kLGHighlightTag = 90002;

@interface MMTabBarController : UITabBarController
@end

@interface MMTabBarController (LiquidGlass)
- (BOOL)lg_isInChatPage;
- (NSArray<UIControl *> *)lg_buttons;
- (UIVisualEffectView *)lg_glass;
- (UIView *)lg_highlight;
- (void)lg_cleanSystemBackground;
- (void)lg_layout;
@end

%hook MMTabBarController

%new
- (BOOL)lg_isInChatPage {
    for (UIWindow *win in [UIApplication sharedApplication].windows) {
        for (UIView *v in win.subviews) {
            NSString *cls = NSStringFromClass([v class]);
            if ([cls containsString:@"MinimizeBaseView"]) {
                return YES;
            }
        }
    }
    return NO;
}

%new
- (NSArray<UIControl *> *)lg_buttons {
    NSMutableArray<UIControl *> *arr = [NSMutableArray array];

    for (UIView *v in self.tabBar.subviews) {
        if (![v isKindOfClass:[UIControl class]]) continue;
        if (CGRectGetWidth(v.frame) <= 60.0) continue;
        [arr addObject:(UIControl *)v];
    }

    [arr sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return arr;
}

%new
- (UIVisualEffectView *)lg_glass {
    UIVisualEffectView *g = (UIVisualEffectView *)[self.tabBar viewWithTag:kLGGlassTag];
    if (g) return g;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
    g = [[UIVisualEffectView alloc] initWithEffect:blur];
    g.tag = kLGGlassTag;
    g.layer.cornerRadius = 32.0;
    g.clipsToBounds = YES;
    g.hidden = YES;
    g.alpha = 0.0;

    [self.tabBar insertSubview:g atIndex:0];
    return g;
}

%new
- (UIView *)lg_highlight {
    UIView *v = [[self lg_glass] viewWithTag:kLGHighlightTag];
    if (v) return v;

    v = [[UIView alloc] init];
    v.tag = kLGHighlightTag;
    v.layer.cornerRadius = 20.0;
    v.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
    [[[self lg_glass] contentView] addSubview:v];
    return v;
}

%new
- (void)lg_cleanSystemBackground {
    for (UIView *v in self.tabBar.subviews) {
        NSString *cls = NSStringFromClass([v class]);
        if ([cls containsString:@"_UIBarBackground"] ||
            [cls containsString:@"UIImageView"]) {
            v.alpha = 0.0;
        }
    }
}

%new
- (void)lg_layout {
    UIVisualEffectView *glass = [self lg_glass];

    if ([self lg_isInChatPage]) {
        glass.hidden = YES;
        glass.alpha = 0.0;
        return;
    }

    [self lg_cleanSystemBackground];

    CGFloat margin = 18.0;
    CGFloat h = 64.0;

    glass.hidden = NO;
    glass.alpha = 1.0;
    glass.frame = CGRectMake(
        margin,
        6.0,
        CGRectGetWidth(self.tabBar.bounds) - margin * 2.0,
        h
    );
    glass.layer.cornerRadius = h * 0.5;

    NSArray<UIControl *> *btns = [self lg_buttons];
    if (btns.count == 0) return;

    CGFloat itemW = CGRectGetWidth(glass.frame) / MAX((NSInteger)btns.count, 1);

    for (NSInteger i = 0; i < (NSInteger)btns.count; i++) {
        UIView *b = btns[i];
        CGRect f = b.frame;
        f.origin.x = CGRectGetMinX(glass.frame) + i * itemW;
        f.size.width = itemW;
        f.origin.y = -4.0;
        b.frame = f;
    }

    if (self.selectedIndex < btns.count) {
        UIView *hl = [self lg_highlight];
        UIView *sel = btns[self.selectedIndex];
        CGRect r = [glass convertRect:sel.frame fromView:sel.superview];
        CGFloat w = 60.0;
        hl.frame = CGRectMake(
            CGRectGetMidX(r) - w * 0.5,
            8.0,
            w,
            40.0
        );
    }

    [self.tabBar sendSubviewToBack:glass];
    for (UIView *b in btns) {
        [self.tabBar bringSubviewToFront:b];
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    [self lg_layout];
}

- (void)setSelectedIndex:(NSUInteger)i {
    %orig;
    [self lg_layout];
}

%end
