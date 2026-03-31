%hook MMTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    UITabBarController *tabVC = (UITabBarController *)self;
    UITabBar *tabBar = tabVC.tabBar;
    if (!tabBar) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        for (UIView *v in tabBar.subviews) {
            NSString *cls = NSStringFromClass([v class]);

            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"TABBAR"
                                                            message:cls
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    });
}

%end
