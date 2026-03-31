#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static BOOL enableGlass = YES;

#pragma mark - 工具函数

static BOOL isMainTabBarView(UIView *view) {
    NSString *cls = NSStringFromClass([view class]);

    // 精准命中微信主界面底部
    if ([cls containsString:@"TabBar"] ||
        [cls containsString:@"ToolBar"] ||
        [cls containsString:@"Container"]) {
        return YES;
    }

    return NO;
}

#pragma mark - 顶栏（导航栏）

%hook UINavigationBar

- (void)layoutSubviews {
    %orig;

    if (!enableGlass) return;

    if ([self viewWithTag:8888]) return;

    self.translucent = YES;
    self.backgroundColor = [UIColor clearColor];

    [self setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    [self setShadowImage:[UIImage new]];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];

    blur.frame = self.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.tag = 8888;

    [self insertSubview:blur atIndex:0];
}

%end

#pragma mark - 底栏（精准命中）

%hook UIView

- (void)didMoveToWindow {
    %orig;

    if (!enableGlass) return;

    // 只处理主界面
    if (![self window]) return;

    CGRect frame = self.frame;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;

    // 必须在底部区域
    if (frame.origin.y < screenHeight - 120) return;

    // 高度过滤（底栏一般 60~100）
    if (frame.size.height < 50 || frame.size.height > 120) return;

    // 类名过滤（避免污染）
    if (!isMainTabBarView(self)) return;

    // 避免重复
    if ([self viewWithTag:9999]) return;

    // 清空背景
    self.backgroundColor = [UIColor clearColor];

    // 毛玻璃（核心）
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];

    blur.frame = self.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.tag = 9999;

    [self addSubview:blur];

    // 流光（增强版）
    CAGradientLayer *glow = [CAGradientLayer layer];
    glow.frame = self.bounds;

    glow.colors = @[
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.4].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.05].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.4].CGColor
    ];

    glow.startPoint = CGPointMake(0, 0.5);
    glow.endPoint = CGPointMake(1, 0.5);
    glow.locations = @[@0, @0.5, @1];

    [self.layer addSublayer:glow];

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"locations"];
    anim.fromValue = @[@-1, @-0.5, @0];
    anim.toValue = @[@1, @1.5, @2];
    anim.duration = 2.0;
    anim.repeatCount = HUGE_VALF;

    [glow addAnimation:anim forKey:@"flow"];
}

%end
