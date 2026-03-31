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
    CAGradientLayer *highlightLayer = nil;
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

        highlightLayer = [CAGradientLayer layer];
        highlightLayer.colors = @[(__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0].CGColor,
                                  (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor,
                                  (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0].CGColor];
        highlightLayer.startPoint = CGPointMake(0, 0.5);
        highlightLayer.endPoint = CGPointMake(1, 0.5);
        highlightLayer.frame = CGRectMake(-glass.bounds.size.width, 0, glass.bounds.size.width*3, glass.bounds.size.height);
        [glass.layer addSublayer:highlightLayer];

        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"position.x"];
        anim.fromValue = @(-glass.bounds.size.width);
        anim.toValue = @(glass.bounds.size.width*2);
        anim.duration = 2.0;
        anim.repeatCount = HUGE_VALF;
        [highlightLayer addAnimation:anim forKey:@"liquidglass_highlight"];

        UIView *tint = [[UIView alloc] initWithFrame:glass.bounds];
        tint.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
        tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [glass.contentView addSubview:tint];

        [container addSubview:glass];
    }

    CGFloat width = container.bounds.size.width;
    CGFloat height = 87;
    CGFloat margin = 18;
    glass.frame = CGRectMake(margin,
                             container.bounds.size.height - height - 22,
                             width - margin * 2,
                             height);

    NSMutableArray *clonedButtons = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"TabBarButton"]) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = sub.frame;
            for (UIView *label in sub.subviews) {
                if ([label isKindOfClass:[UILabel class]]) {
                    UILabel *lbl = [[UILabel alloc] initWithFrame:label.frame];
                    lbl.text = ((UILabel *)label).text;
                    lbl.font = ((UILabel *)label).font;
                    lbl.textColor = ((UILabel *)label).textColor;
                    [btn addSubview:lbl];
                }
            }
            btn.tag = sub.tag;
            [glass addSubview:btn];
            [clonedButtons addObject:btn];
            [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

            btn.layer.shadowColor = [UIColor whiteColor].CGColor;
            btn.layer.shadowRadius = 10;
            btn.layer.shadowOpacity = 0.08;
            btn.layer.shadowOffset = CGSizeMake(0, 0);
        }
    }

    for (UIView *btn in clonedButtons) {
        CGRect f = btn.frame;
        f.origin.y = 0;
        f.size.height = glass.bounds.size.height;
        btn.frame = f;
    }

    [container bringSubviewToFront:glass];
}

- (void)tabButtonTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    NSArray *viewControllers = [self valueForKey:@"viewControllers"];
    if (index < viewControllers.count) {
        [self setValue:@(index) forKey:@"selectedIndex"];
    }
}

%end
