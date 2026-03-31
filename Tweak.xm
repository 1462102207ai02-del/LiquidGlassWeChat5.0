#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static BOOL enableGlass = YES;

%hook UIView

- (void)didMoveToWindow {
    %orig;

    if (!enableGlass) return;

    NSString *cls = NSStringFromClass([self class]);

    // 命中微信底部容器（比 UITabBar 更准）
    if ([cls containsString:@"TabBar"] || [cls containsString:@"ToolBar"]) {

        self.backgroundColor = [UIColor clearColor];

        // 毛玻璃
        UIVisualEffectView *blur = [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];

        blur.frame = self.bounds;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blur.userInteractionEnabled = NO;

        // 避免重复添加
        if (![self viewWithTag:9991]) {
            blur.tag = 9991;
            [self insertSubview:blur atIndex:0];
        }

        // 流光
        if (![self.layer valueForKey:@"glow"]) {
            CAGradientLayer *glow = [CAGradientLayer layer];
            glow.frame = self.bounds;

            glow.colors = @[
                (__bridge id)[UIColor colorWithWhite:1 alpha:0.25].CGColor,
                (__bridge id)[UIColor colorWithWhite:1 alpha:0.05].CGColor,
                (__bridge id)[UIColor colorWithWhite:1 alpha:0.25].CGColor
            ];

            glow.startPoint = CGPointMake(0, 0.5);
            glow.endPoint = CGPointMake(1, 0.5);
            glow.locations = @[@0, @0.5, @1];

            [self.layer addSublayer:glow];
            [self.layer setValue:glow forKey:@"glow"];

            CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"locations"];
            anim.fromValue = @[@-1, @-0.5, @0];
            anim.toValue = @[@1, @1.5, @2];
            anim.duration = 2.5;
            anim.repeatCount = HUGE_VALF;

            [glow addAnimation:anim forKey:@"flow"];
        }
    }
}

%end
