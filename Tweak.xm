#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

%hook MMTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    UITabBarController *tabVC = (UITabBarController *)self;
    UITabBar *tabBar = tabVC.tabBar;
    if (!tabBar) return;

    UIView *container = tabVC.view;

    UIVisualEffectView *glass = [container viewWithTag:8888];

    if (!glass) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
        glass = [[UIVisualEffectView alloc] initWithEffect:blur];
        glass.tag = 8888;

        glass.layer.cornerRadius = 34;
        glass.layer.masksToBounds = YES;

        glass.layer.borderWidth = 0.6;
        glass.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5].CGColor;

        glass.layer.shadowColor = [UIColor blackColor].CGColor;
        glass.layer.shadowOpacity = 0.12;
        glass.layer.shadowRadius = 30;
        glass.layer.shadowOffset = CGSizeMake(0, 10);

        CAGradientLayer *highlight = [CAGradientLayer layer];
        highlight.colors = @[
            (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor,
            (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor,
            (__bridge id)[[UIColor clearColor] CGColor]
        ];
        highlight.startPoint = CGPointMake(0.5, 0);
        highlight.endPoint = CGPointMake(0.5, 1);
        highlight.cornerRadius = 34;

        [glass.layer addSublayer:highlight];

        UIView *tint = [[UIView alloc] initWithFrame:CGRectZero];
        tint.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
        tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [glass.contentView addSubview:tint];

        [container insertSubview:glass belowSubview:tabBar];
    }

    CGFloat height = tabBar.bounds.size.height;
    CGFloat width = container.bounds.size.width;
    CGFloat margin = 18;

    CGRect frame = CGRectMake(
        margin,
        container.bounds.size.height - height - 22,
        width - margin * 2,
        height - 8
    );

    glass.frame = frame;
    glass.layer.sublayers.firstObject.frame = glass.bounds;
    ((UIView *)glass.contentView.subviews.firstObject).frame = glass.bounds;

    tabBar.frame = frame;

    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.translucent = YES;

    UITabBarAppearance *appearance = [UITabBarAppearance new];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = [UIColor clearColor];
    appearance.shadowColor = nil;
    tabBar.standardAppearance = appearance;
    tabBar.scrollEdgeAppearance = appearance;

    for (UIView *sub in tabBar.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"Background"] ||
            [cls containsString:@"BarBackground"] ||
            [cls containsString:@"VisualEffect"]) {
            sub.hidden = YES;
        }
    }

    tabBar.clipsToBounds = NO;

    [container bringSubviewToFront:tabBar];
}

%end
