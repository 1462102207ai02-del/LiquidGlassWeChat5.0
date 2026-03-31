#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

%hook MMTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    UIView *container = [self valueForKey:@"view"];
    if (!container) return;

    UIVisualEffectView *glass = [container viewWithTag:8888];
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
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
                             width - margin*2,
                             height);

    [container bringSubviewToFront:glass];
}

%end
