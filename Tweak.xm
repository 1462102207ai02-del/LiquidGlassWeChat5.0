#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kLGGlassTag = 90001;
static NSInteger const kLGHighlightTag = 90002;

@interface MMTabBarController : UITabBarController
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
    NSMutableArray *arr = [NSMutableArray array];

    for (UIView *v in self.tabBar.subviews) {
        if ([v isKindOfClass:[UIControl class]] &&
            v.frame.size.width > 60) {
            [arr addObject:v];
        }
    }

    [arr sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.frame.origin.x > b.frame.origin.x;
    }];

    return arr;
}

%new
- (UIVisualEffectView *)lg_glass {
    UIVisualEffectView *g = [self.tabBar viewWithTag:kLGGlassTag];
    if (g) return g;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];

    g = [[UIVisualEffectView alloc] initWithEffect:blur];
    g.tag = kLGGlassTag;
    g.layer.cornerRadius = 32;
    g.clipsToBounds = YES;

    [self.tabBar insertSubview:g atIndex:0];
    return g;
}

%new
- (UIView *)lg_highlight {
    UIView *v = [[self lg_glass] viewWithTag:kLGHighlightTag];
    if (v) return v;

    v = [[UIView alloc] init];
    v.tag = kLGHighlightTag;
    v.layer.cornerRadius = 20;
    v.backgroundColor = [UIColor colorWithWhite:1 alpha:0.25];

    [[self lg_glass].contentView addSubview:v];
    return v;
}

%new
- (void)lg_cleanSystemBackground {
    for (UIView *v in self.tabBar.subviews) {
        NSString *cls = NSStringFromClass([v class]);
        if ([cls containsString:@"_UIBarBackground"] ||
            [cls containsString:@"UIImageView"]) {
            v.alpha = 0;
        }
    }
}

%new
- (void)lg_layout {
    if ([self lg_isInChatPage]) {
        [self lg_glass].hidden = YES;
        return;
    }

    [self lg_cleanSystemBackground];

    UIVisualEffectView *glass = [self lg_glass];

    CGFloat margin = 18;
    CGFloat h = 64;

    glass.frame = CGRectMake(
        margin,
        6,
        self.tabBar.bounds.size.width - margin*2,
        h
    );

    NSArray *btns = [self lg_buttons];
    if (btns.count == 0) return;

    CGFloat itemW = glass.frame.size.width / btns.count;

    for (int i = 0; i < btns.count; i++) {
        UIView *b = btns[i];

        CGRect f = b.frame;
        f.origin.x = glass.frame.origin.x + i * itemW;
        f.size.width = itemW;
        f.origin.y = -4;
        b.frame = f;
    }

    UIView *hl = [self lg_highlight];
    UIView *sel = btns[self.selectedIndex];

    CGRect r = [glass convertRect:sel.frame fromView:sel.superview];

    CGFloat w = 60;
    hl.frame = CGRectMake(
        CGRectGetMidX(r) - w/2,
        8,
        w,
        40
    );
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
