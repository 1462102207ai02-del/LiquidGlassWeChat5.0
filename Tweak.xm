#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

%hook MMTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    if (![self isKindOfClass:NSClassFromString(@"MMTabBarController")]) return;

    UIView *container = [self valueForKey:@"view"];
    if (!container) return;

    UITabBar *tabBar = nil;
    for (UIView *sub in container.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"MMTabBar"]) {
            tabBar = (UITabBar *)sub;
            sub.hidden = YES;
            break;
        }
    }
    if (!tabBar) return;

    UIVisualEffectView *glass = [container viewWithTag:8888];
    if (!glass) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight];
        glass = [[UIVisualEffectView alloc] initWithEffect:blur];
        glass.tag = 8888;
        glass.layer.cornerRadius = 34;
        glass.layer.masksToBounds = YES;
        [container addSubview:glass];
    }

    CGFloat width = container.bounds.size.width;
    CGFloat height = 87;
    CGFloat margin = 18;
    glass.frame = CGRectMake(margin,
                             container.bounds.size.height - height - 22,
                             width - margin * 2,
                             height);

    [container bringSubviewToFront:glass];
}

%end
