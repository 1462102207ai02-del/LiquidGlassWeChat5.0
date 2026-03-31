#import <UIKit/UIKit.h>

static UITabBar *findTabBar(UIView *view) {
    if ([view isKindOfClass:[UITabBar class]]) {
        return (UITabBar *)view;
    }
    for (UIView *sub in view.subviews) {
        UITabBar *result = findTabBar(sub);
        if (result) return result;
    }
    return nil;
}

%hook UIApplication

- (void)didFinishLaunching {
    %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

        UIWindow *targetWindow = nil;

        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            if (windowScene.activationState != UISceneActivationStateForegroundActive) continue;

            for (UIWindow *win in windowScene.windows) {
                if (win.isKeyWindow) {
                    targetWindow = win;
                    break;
                }
            }

            if (targetWindow) break;
        }

        if (!targetWindow) return;

        UITabBar *tabBar = findTabBar(targetWindow);
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

    });
}

%end
