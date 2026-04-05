
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

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    loadOpacitySettings();
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
