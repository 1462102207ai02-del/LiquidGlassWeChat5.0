#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

%hook MMTabBarController

- (void)viewDidLayoutSubviews {
    %orig;

    UIView *container = self.view;
    UITabBar *tabBar = nil;
    for (UIView *sub in container.subviews) {
        if ([sub isKindOfClass:NSClassFromString(@"MMTabBar")]) {
            tabBar = (UITabBar *)sub;
            sub.hidden = YES;
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
        glass.layer.borderWidth = 0.6;
        glass.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5].CGColor;
        glass.layer.shadowColor = [UIColor blackColor].CGColor;
        glass.layer.shadowOpacity = 0.12;
        glass.layer.shadowRadius = 30;
        glass.layer.shadowOffset = CGSizeMake(0, 10);

        CAGradientLayer *highlight = [CAGradientLayer layer];
        highlight.colors = @[(__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor,
                             (__bridge id)[[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor,
                             (__bridge id)[[UIColor clearColor] CGColor]];
        highlight.startPoint = CGPointMake(0.5, 0);
        highlight.endPoint = CGPointMake(0.5, 1);
        highlight.frame = glass.bounds;
        highlight.cornerRadius = 34;
        [glass.layer addSublayer:highlight];

        UIView *tint = [[UIView alloc] initWithFrame:glass.bounds];
        tint.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
        tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [glass.contentView addSubview:tint];

        [container addSubview:glass];
    }

    CGFloat width = container.bounds.size.width;
    CGFloat height = 87;
    CGFloat margin = 18;
    CGRect glassFrame = CGRectMake(margin,
                                   container.bounds.size.height - height - 22,
                                   width - margin * 2,
                                   height);
    glass.frame = glassFrame;

    NSArray *buttons = @[];
    NSMutableArray *clonedButtons = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"TabBarButton"]) {
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
    if (index < self.viewControllers.count) {
        self.selectedIndex = index;
    }
}

%end
