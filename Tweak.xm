%hook UITabBar

- (void)layoutSubviews {
    %orig;

    static UIVisualEffectView *glassView = nil;

    if (!glassView) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        glassView = [[UIVisualEffectView alloc] initWithEffect:blur];

        // 👉 圆角
        glassView.layer.cornerRadius = 30;
        glassView.layer.masksToBounds = YES;

        // 👉 半透明白（Liquid 느낌）
        UIView *tintView = [[UIView alloc] init];
        tintView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
        tintView.frame = glassView.bounds;
        tintView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        [glassView.contentView addSubview:tintView];

        // 👉 放到底层（关键！！！）
        [self insertSubview:glassView atIndex:0];
    }

    // 👉 悬浮 + 内缩
    CGFloat margin = 10;
    glassView.frame = CGRectMake(
        margin,
        5,
        self.bounds.size.width - margin * 2,
        self.bounds.size.height - 10
    );

    // 👉 去掉系统背景（关键）
    self.backgroundImage = [UIImage new];
    self.shadowImage = [UIImage new];
    self.barTintColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
}

%end
