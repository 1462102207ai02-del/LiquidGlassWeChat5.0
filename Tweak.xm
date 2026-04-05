
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingCapsuleTag = 990203;
static NSInteger const kMMFloatingCapsuleBorderTag = 990204;
static NSInteger const kMMFloatingCapsuleGlowTag = 990205;
static NSInteger const kMMFloatingButtonsTag = 990206;

static BOOL kMMUpdatingLayout = NO;

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static CGFloat kBackgroundOpacity = 0.18;
static CGFloat kCapsuleOpacity = 0.35;

void loadOpacitySettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat backgroundOpacity = [defaults floatForKey:@"backgroundOpacity"];
    if (backgroundOpacity >= 0.0 && backgroundOpacity <= 1.0) {
        kBackgroundOpacity = backgroundOpacity;
    }

    CGFloat capsuleOpacity = [defaults floatForKey:@"capsuleOpacity"];
    if (capsuleOpacity >= 0.0 && capsuleOpacity <= 1.0) {
        kCapsuleOpacity = capsuleOpacity;
    }
}

void saveOpacitySettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:kBackgroundOpacity forKey:@"backgroundOpacity"];
    [defaults setFloat:kCapsuleOpacity forKey:@"capsuleOpacity"];
    [defaults synchronize];
}

CGFloat getBackgroundOpacity() {
    return kBackgroundOpacity;
}

CGFloat getCapsuleOpacity() {
    return kCapsuleOpacity;
}

static void MMSetRadius(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static void MMUpdateLayout(UIViewController *vc) {
    if (kMMUpdatingLayout) return;
    kMMUpdatingLayout = YES;

    UIView *root = vc.view;
    UITabBar *tabBar = [root viewWithTag:kMMFloatingHostTag];
    if (!root || !tabBar) {
        kMMUpdatingLayout = NO;
        return;
    }

    UIView *host = [root viewWithTag:kMMFloatingHostTag];
    host.hidden = NO;

    CGFloat backgroundOpacity = getBackgroundOpacity();
    CGFloat capsuleOpacity = getCapsuleOpacity();

    tabBar.transform = CGAffineTransformIdentity;
    tabBar.frame = root.bounds;
    tabBar.backgroundColor = MMIsDark(root.traitCollection) ? MMRGBA(255, 255, 255, backgroundOpacity) : MMRGBA(255, 255, 255, backgroundOpacity);

    UIView *capsule = [host viewWithTag:kMMFloatingCapsuleTag];
    capsule.backgroundColor = MMIsDark(root.traitCollection) ? MMRGBA(255,255,255,capsuleOpacity) : MMRGBA(255,255,255,capsuleOpacity);

    kMMUpdatingLayout = NO;
}

static void MMAddFloatingBar(UIView *view) {
    UIView *floatingBar = [view viewWithTag:kMMFloatingHostTag];
    if (!floatingBar) {
        floatingBar = [[UIView alloc] initWithFrame:CGRectMake(0, view.frame.size.height - 60, view.frame.size.width, 60)];
        floatingBar.tag = kMMFloatingHostTag;
        floatingBar.backgroundColor = MMRGBA(255, 255, 255, getBackgroundOpacity());
        floatingBar.layer.shadowColor = [UIColor blackColor].CGColor;
        floatingBar.layer.shadowOpacity = 0.5;
        floatingBar.layer.shadowOffset = CGSizeMake(0, -3);
        floatingBar.layer.shadowRadius = 10;
        [view addSubview:floatingBar];
    }
    MMSetRadius(floatingBar, 30);
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    loadOpacitySettings();
    MMAddFloatingBar(self.view); // 添加悬浮底栏
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdateLayout((UIViewController *)self);
}

%end

%hook UITabBar

- (void)setSelectedItem:(UITabBarItem *)item {
    %orig(item);
    loadOpacitySettings();
}

%end
