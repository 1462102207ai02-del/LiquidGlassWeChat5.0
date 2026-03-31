#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

%hook MMTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    UITabBarController *tabVC = (UITabBarController *)self;
    UITabBar *tabBar = tabVC.tabBar;
    if (!tabBar) return;

    UIView *container = tabVC.view;

    CGFloat height = tabBar.bounds.size.height;
    CGFloat width = container.bounds.size.width;
    CGFloat margin = 18;

    CGRect frame = CGRectMake(
        margin,
        container.bounds.size.height - height - 22,
        width - margin * 2,
        height - 8
    );

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

    for (UIView *sub in tabBar.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"Background"] ||
            [cls containsString:@"BarBackground"] ||
            [cls containsString:@"VisualEffect"]) {
            sub.hidden = YES;
        }
    }

    UIVisualEffectView *glass = [tabBar viewWithTag:9999];

    if (!glass) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        glass = [[UIVisualEffectView alloc] initWithEffect:blur];
        glass.userInteractionEnabled = NO;
        glass.tag = 9999;

        glass.layer.cornerRadius = 34;
        glass.layer.masksToBounds = YES;

        glass.layer.borderWidth = 0.6;
        glass.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6].CGColor;

        glass.layer.shadowColor = [UIColor blackColor].CGColor;
        glass.layer.shadowOpacity = 0.15;
        glass.layer.shadowRadius = 40;
        glass.layer.shadowOffset = CGSizeMake(0, 12);

        CAGradientLayer *highlight = [CAGradientLayer layer];
        highlight.colors = @[
            (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.6].CGColor,
            (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor,
            (__bridge id)[[UIColor clearColor] CGColor]
        ];
        highlight.startPoint = CGPointMake(0.5, 0);
        highlight.endPoint = CGPointMake(0.5, 1);
        highlight.cornerRadius = 34;

        [glass.layer addSublayer:highlight];

        [tabBar insertSubview:glass atIndex:0];
    }

    glass.frame = tabBar.bounds;
    glass.layer.sublayers.firstObject.frame = glass.bounds;

    tabBar.clipsToBounds = NO;
}

%end
