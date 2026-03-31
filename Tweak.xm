#import <UIKit/UIKit.h>

%hook UITabBar

- (void)layoutSubviews {
    %orig;

    UIVisualEffectView *glassView = [self viewWithTag:9999];

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

        [self insertSubview:glassView atIndex:0];
    }

    CGFloat margin = 12;
    glassView.frame = CGRectMake(
        margin,
        6,
        self.bounds.size.width - margin * 2,
        self.bounds.size.height - 12
    );

    self.backgroundImage = [UIImage new];
    self.shadowImage = [UIImage new];
    self.barTintColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
}

%end
