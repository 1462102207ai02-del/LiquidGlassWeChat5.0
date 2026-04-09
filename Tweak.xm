// 完整 tweak.xm（已调：若隐若现毛玻璃 + 自适应深浅色）

static void MMUpdateNativeBackdrop(UIViewController *vc, UITabBar *tabBar) {
    if (!vc || !vc.isViewLoaded || !tabBar) return;

    UIView *root = vc.view;
    UIView *host = MMNativeBackdropHost(root);

    CGFloat inset = MMBottomInset(root);
    CGFloat floatingHeight = 74.0;
    CGFloat floatingY = CGRectGetHeight(root.bounds) - inset - floatingHeight - 14.0;

    CGFloat blurTop = floatingY - 8.0;
    CGFloat blurHeight = CGRectGetHeight(root.bounds) - blurTop;

    host.frame = CGRectMake(0.0, blurTop, CGRectGetWidth(root.bounds), blurHeight);
    host.layer.cornerRadius = 0;
    host.layer.masksToBounds = YES;

    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMNativeBackdropBlurTag];
    blur.frame = host.bounds;

    if (MMIsDark(root.traitCollection)) {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    } else {
        blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
    }

    UIView *tint = [host viewWithTag:kMMNativeBackdropTintTag];
    tint.frame = host.bounds;

    if (MMIsDark(root.traitCollection)) {
        tint.backgroundColor = MMRGBA(255,255,255,0.015);
        host.alpha = 0.14;
    } else {
        tint.backgroundColor = MMRGBA(255,255,255,0.045);
        host.alpha = 0.18;
    }

    [root insertSubview:host belowSubview:MMHost(root)];
}
