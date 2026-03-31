#import <UIKit/UIKit.h>

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (![self isKindOfClass:NSClassFromString(@"MMTabBarController")]) return;

    UITabBar *tabBar = self.tabBarController.tabBar;
    if (!tabBar) return;

    UIVisualEffectView *glassView = [tabBar viewWithTag:9999];

    if (!glassView) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        glassView = [[UIVisualEffectView alloc] initWithEffect:blur];
        glassView.tag = 9999;
        glassView.layer.cornerRadius = 28;
        glassView.layer.masksToBounds = YES;

        UIView *tintView = [[UIView alloc] initWithFrame:glassView.bounds];
        tintView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.12];
        tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [glassView.contentView addSubview:tintView];

        [tabBar insertSubview:glassView atIndex:0];
    }

    CGFloat margin = 12;
    glassView.frame = CGRectMake(
        margin,
        6,
        tabBar.bounds.size.width - margin * 2,
        tabBar.bounds.size.height - 12
    );

    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.backgroundColor = [UIColor clearColor];
}

%end
