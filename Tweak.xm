#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingCapsuleTag = 990203;
static NSInteger const kMMFloatingCapsuleBorderTag = 990204;
static NSInteger const kMMFloatingCapsuleGlowTag = 990205;
static NSInteger const kMMFloatingButtonsTag = 990206;

static NSInteger const kMMDockSearchHostTag = 991201;
static NSInteger const kMMDockSearchBlurTag = 991202;
static NSInteger const kMMDockSearchIconTag = 991203;
static NSInteger const kMMDockSearchHitButtonTag = 991204;

static BOOL kMMUpdatingLayout = NO;
static BOOL kMMSettingsPresented = NO;

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

static BOOL MMIsDark(UITraitCollection *trait) {
    if (trait && [trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static CGFloat MMClamp(CGFloat value, CGFloat min, CGFloat max) {
    return value < min ? min : (value > max ? max : value);
}

static NSString *MMModeSuffix(UITraitCollection *trait) {
    return MMIsDark(trait) ? @"dark" : @"light";
}

static NSString *MMKey(NSString *prefix, UITraitCollection *trait, NSString *component) {
    return [NSString stringWithFormat:@"%@_%@_%@", prefix, MMModeSuffix(trait), component];
}

static CGFloat MMUserFloat(NSString *key, CGFloat fallback) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id obj = [defaults objectForKey:key];
    if (!obj) return fallback;
    return [defaults floatForKey:key];
}

static CGFloat MMUserAlpha(NSString *key, CGFloat fallback) {
    return MMClamp(MMUserFloat(key, fallback), 0.0, 1.0);
}

static NSString *MMPercentString(CGFloat alpha) {
    return [NSString stringWithFormat:@"%.0f", MMClamp(alpha, 0.0, 1.0) * 100.0];
}

static CGFloat MMPercentToAlpha(NSString *text, CGFloat fallback) {
    if (!text.length) return fallback;
    return MMClamp(([text doubleValue] / 100.0), 0.0, 1.0);
}

static void MMSaveFloat(NSString *key, CGFloat value) {
    [[NSUserDefaults standardUserDefaults] setFloat:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static UIColor *MMColorFromStored(NSString *prefix, UITraitCollection *trait, UIColor *fallback) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *rKey = MMKey(prefix, trait, @"r");
    NSString *gKey = MMKey(prefix, trait, @"g");
    NSString *bKey = MMKey(prefix, trait, @"b");

    if ([defaults objectForKey:rKey] && [defaults objectForKey:gKey] && [defaults objectForKey:bKey]) {
        CGFloat r = MMClamp([defaults floatForKey:rKey], 0.0, 1.0);
        CGFloat g = MMClamp([defaults floatForKey:gKey], 0.0, 1.0);
        CGFloat b = MMClamp([defaults floatForKey:bKey], 0.0, 1.0);
        return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
    }
    return fallback;
}

static void MMSaveColor(NSString *prefix, UITraitCollection *trait, UIColor *color) {
    CGFloat r = 0.0, g = 0.0, b = 0.0, a = 0.0;
    UIColor *resolved = color ?: [UIColor whiteColor];
    if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
        CGColorRef cgColor = resolved.CGColor;
        size_t count = CGColorGetNumberOfComponents(cgColor);
        const CGFloat *components = CGColorGetComponents(cgColor);
        if (count >= 3) {
            r = components[0];
            g = components[1];
            b = components[2];
        } else if (count == 2) {
            r = components[0];
            g = components[0];
            b = components[0];
        }
    }

    [[NSUserDefaults standardUserDefaults] setFloat:r forKey:MMKey(prefix, trait, @"r")];
    [[NSUserDefaults standardUserDefaults] setFloat:g forKey:MMKey(prefix, trait, @"g")];
    [[NSUserDefaults standardUserDefaults] setFloat:b forKey:MMKey(prefix, trait, @"b")];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void MMRemoveColor(NSString *prefix, UITraitCollection *trait) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:MMKey(prefix, trait, @"r")];
    [defaults removeObjectForKey:MMKey(prefix, trait, @"g")];
    [defaults removeObjectForKey:MMKey(prefix, trait, @"b")];
    [defaults synchronize];
}

static CGFloat MMBackgroundAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserAlpha(@"mm_bg_alpha_dark", 0.05) : MMUserAlpha(@"mm_bg_alpha_light", 0.13);
}

static CGFloat MMCapsuleAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserAlpha(@"mm_capsule_alpha_dark", 0.10) : MMUserAlpha(@"mm_capsule_alpha_light", 0.24);
}

static CGFloat MMGlowTopAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserAlpha(@"mm_glow_top_alpha_dark", 0.10) : MMUserAlpha(@"mm_glow_top_alpha_light", 0.10);
}

static CGFloat MMGlowMidAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserAlpha(@"mm_glow_mid_alpha_dark", 0.03) : MMUserAlpha(@"mm_glow_mid_alpha_light", 0.03);
}

static CGFloat MMHostBorderAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserAlpha(@"mm_host_border_alpha_dark", 0.12) : MMUserAlpha(@"mm_host_border_alpha_light", 0.22);
}

static CGFloat MMCapsuleBorderAlpha(UITraitCollection *trait) {
    return MMIsDark(trait) ? MMUserAlpha(@"mm_capsule_border_alpha_dark", 0.12) : MMUserAlpha(@"mm_capsule_border_alpha_light", 0.24);
}

static UIColor *MMBackgroundTintColor(UITraitCollection *trait) {
    return MMColorFromStored(@"mm_bg_color", trait, [UIColor whiteColor]);
}

static UIColor *MMCapsuleTintColor(UITraitCollection *trait) {
    return MMColorFromStored(@"mm_capsule_color", trait, [UIColor whiteColor]);
}

static UIColor *MMSelectedColor(UITraitCollection *trait) {
    UIColor *fallback = MMIsDark(trait) ? MMRGBA(0, 216, 95, 1.0) : MMRGBA(0, 190, 80, 1.0);
    return MMColorFromStored(@"mm_selected_color", trait, fallback);
}

static UIColor *MMNormalColor(UITraitCollection *trait) {
    UIColor *fallback = MMIsDark(trait) ? MMRGBA(255, 255, 255, 0.82) : MMRGBA(60, 60, 67, 0.82);
    return MMColorFromStored(@"mm_normal_color", trait, fallback);
}

static CGFloat MMBottomInset(UIView *view) {
    if ([view respondsToSelector:@selector(safeAreaInsets)]) {
        return view.safeAreaInsets.bottom;
    }
    return 0.0;
}

static void MMSetRadius(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static id MMKVC(id obj, NSString *key) {
    @try {
        return [obj valueForKey:key];
    } @catch (__unused NSException *e) {
        return nil;
    }
}

static UITabBar *MMFindTabBar(UIViewController *vc) {
    @try {
        id tb = [vc valueForKey:@"tabBar"];
        if ([tb isKindOfClass:[UITabBar class]]) return (UITabBar *)tb;
    } @catch (__unused NSException *e) {
    }

    for (UIView *sub in vc.view.subviews) {
        if ([sub isKindOfClass:[UITabBar class]]) return (UITabBar *)sub;
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBar"]) return (UITabBar *)sub;
    }
    return nil;
}

static UIViewController *MMCurrentContentController(UIViewController *vc) {
    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {
    }

    UIViewController *content = [selected isKindOfClass:[UIViewController class]] ? (UIViewController *)selected : vc;
    if ([content isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)content;
        UIViewController *top = nav.topViewController ?: nav.visibleViewController ?: nav.viewControllers.firstObject;
        return top ?: content;
    }
    return content;
}

static BOOL MMShouldHideFloatingBar(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !vc.view.window) return YES;
    if (kMMSettingsPresented) return NO;

    UIViewController *content = MMCurrentContentController(vc);
    NSString *name = NSStringFromClass([content class]);
    if ([name isEqualToString:@"MinimizeViewController"]) return YES;

    id selected = nil;
    @try {
        if ([vc respondsToSelector:@selector(selectedViewController)]) {
            selected = [vc valueForKey:@"selectedViewController"];
        }
    } @catch (__unused NSException *e) {
    }

    UIViewController *presented = nil;
    if ([selected isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)selected;
        if (nav.viewControllers.count > 0 && nav.topViewController != nav.viewControllers.firstObject) return YES;
        presented = nav.presentedViewController;
    } else if ([content isKindOfClass:[UIViewController class]]) {
        presented = content.presentedViewController;
    }

    if (presented) {
        if ([presented isKindOfClass:[UIAlertController class]]) return NO;
        NSString *presentedName = NSStringFromClass([presented class]);
        if ([presentedName containsString:@"UIColorPickerViewController"]) return NO;
        return YES;
    }

    return NO;
}


static void MMUpdateFloatingBar(UIViewController *vc);
static void MMRequestFloatingBarRefresh(UIViewController *vc) {
    if (!vc) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        MMRequestFloatingBarRefresh(vc);
    });
}

@interface MMColorPickerProxy : NSObject <UIColorPickerViewControllerDelegate>
@property (nonatomic, assign) UIViewController *vc;
@property (nonatomic, copy) NSString *prefix;
@end

@implementation MMColorPickerProxy
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    if (self.vc && self.prefix.length) {
        MMSaveColor(self.prefix, self.vc.traitCollection, viewController.selectedColor);
        MMRequestFloatingBarRefresh(self.vc);
    }
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    if (self.vc && self.prefix.length) {
        MMSaveColor(self.prefix, self.vc.traitCollection, viewController.selectedColor);
        MMRequestFloatingBarRefresh(self.vc);
    }
    kMMSettingsPresented = NO;
}
@end

static MMColorPickerProxy *MMSharedColorPickerProxy(void) {
    static MMColorPickerProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMColorPickerProxy new];
    });
    return proxy;
}

static void MMPresentColorPicker(UIViewController *vc, NSString *prefix, UIColor *currentColor, NSString *title) {
    if (!vc) return;
    if (!NSClassFromString(@"UIColorPickerViewController")) return;

    MMColorPickerProxy *proxy = MMSharedColorPickerProxy();
    proxy.vc = vc;
    proxy.prefix = prefix;

    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.delegate = proxy;
    picker.selectedColor = currentColor ?: [UIColor whiteColor];
    picker.title = title;
    [vc presentViewController:picker animated:YES completion:nil];
}

static void MMShowNamedAlphaAlert(UIViewController *vc, NSString *key, NSString *title, NSString *placeholder, CGFloat fallback) {
    if (!vc || !key.length) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:@"请输入百分比 0 到 100" preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = placeholder;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = MMPercentString(MMUserAlpha(key, fallback));
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        kMMSettingsPresented = NO;
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"恢复默认" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        MMSaveFloat(key, fallback);
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UITextField *field = alert.textFields.count > 0 ? alert.textFields[0] : nil;
        CGFloat value = MMPercentToAlpha(field.text, fallback);
        MMSaveFloat(key, value);
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    [vc presentViewController:alert animated:YES completion:nil];
}

static void MMShowSingleAlphaAlert(UIViewController *vc, NSString *type) {
    if (!vc || !type.length) return;

    BOOL dark = MMIsDark(vc.traitCollection);
    NSString *title = nil;
    NSString *placeholder = nil;
    NSString *key = nil;
    CGFloat fallback = 0.0;

    if ([type isEqualToString:@"bg"]) {
        key = dark ? @"mm_bg_alpha_dark" : @"mm_bg_alpha_light";
        title = dark ? @"底栏背景透明度（深色模式）" : @"底栏背景透明度（浅色模式）";
        placeholder = @"底栏背景透明度 %";
        fallback = dark ? 0.05 : 0.13;
    } else if ([type isEqualToString:@"capsule"]) {
        key = dark ? @"mm_capsule_alpha_dark" : @"mm_capsule_alpha_light";
        title = dark ? @"胶囊透明度（深色模式）" : @"胶囊透明度（浅色模式）";
        placeholder = @"胶囊透明度 %";
        fallback = dark ? 0.10 : 0.24;
    } else if ([type isEqualToString:@"host_border"]) {
        key = dark ? @"mm_host_border_alpha_dark" : @"mm_host_border_alpha_light";
        title = dark ? @"底栏描边透明度（深色模式）" : @"底栏描边透明度（浅色模式）";
        placeholder = @"底栏描边透明度 %";
        fallback = dark ? 0.12 : 0.22;
    } else if ([type isEqualToString:@"capsule_border"]) {
        key = dark ? @"mm_capsule_border_alpha_dark" : @"mm_capsule_border_alpha_light";
        title = dark ? @"胶囊描边透明度（深色模式）" : @"胶囊描边透明度（浅色模式）";
        placeholder = @"胶囊描边透明度 %";
        fallback = dark ? 0.12 : 0.24;
    } else if ([type isEqualToString:@"glow_top"]) {
        key = dark ? @"mm_glow_top_alpha_dark" : @"mm_glow_top_alpha_light";
        title = dark ? @"高光顶部透明度（深色模式）" : @"高光顶部透明度（浅色模式）";
        placeholder = @"高光顶部透明度 %";
        fallback = 0.10;
    } else if ([type isEqualToString:@"glow_mid"]) {
        key = dark ? @"mm_glow_mid_alpha_dark" : @"mm_glow_mid_alpha_light";
        title = dark ? @"高光中段透明度（深色模式）" : @"高光中段透明度（浅色模式）";
        placeholder = @"高光中段透明度 %";
        fallback = 0.03;
    }

    MMShowNamedAlphaAlert(vc, key, title, placeholder, fallback);
}

static void MMShowColorMenu(UIViewController *vc) {
    if (!vc) return;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:(MMIsDark(vc.traitCollection) ? @"颜色设置（深色模式）" : @"颜色设置（浅色模式）") message:@"调用系统取色盘" preferredStyle:UIAlertControllerStyleActionSheet];

    [menu addAction:[UIAlertAction actionWithTitle:@"背景颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_bg_color", MMBackgroundTintColor(vc.traitCollection), @"背景颜色");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"胶囊颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_capsule_color", MMCapsuleTintColor(vc.traitCollection), @"胶囊颜色");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"选中图标文字颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_selected_color", MMSelectedColor(vc.traitCollection), @"选中颜色");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"未选中图标文字颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMPresentColorPicker(vc, @"mm_normal_color", MMNormalColor(vc.traitCollection), @"未选中颜色");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"恢复当前模式默认颜色" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        MMRemoveColor(@"mm_bg_color", vc.traitCollection);
        MMRemoveColor(@"mm_capsule_color", vc.traitCollection);
        MMRemoveColor(@"mm_selected_color", vc.traitCollection);
        MMRemoveColor(@"mm_normal_color", vc.traitCollection);
        kMMSettingsPresented = NO;
        MMRequestFloatingBarRefresh(vc);
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"返回" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        kMMSettingsPresented = NO;
    }]];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        popover.sourceView = vc.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMaxY(vc.view.bounds) - 80.0, 1.0, 1.0);
    }

    [vc presentViewController:menu animated:YES completion:nil];
}

static void MMShowSettingsMenu(UIViewController *vc) {
    if (!vc || kMMSettingsPresented) return;
    kMMSettingsPresented = YES;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"LiquidGlass 设置" message:@"当前模式单独保存" preferredStyle:UIAlertControllerStyleActionSheet];

    [menu addAction:[UIAlertAction actionWithTitle:@"修改底栏背景透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"bg");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"修改胶囊透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"capsule");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"修改底栏描边透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"host_border");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"修改胶囊描边透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"capsule_border");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"修改高光顶部透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"glow_top");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"修改高光中段透明度" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowSingleAlphaAlert(vc, @"glow_mid");
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"修改颜色" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        MMShowColorMenu(vc);
    }]];

    [menu addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        kMMSettingsPresented = NO;
    }]];

    UIPopoverPresentationController *popover = menu.popoverPresentationController;
    if (popover) {
        popover.sourceView = vc.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMaxY(vc.view.bounds) - 80.0, 1.0, 1.0);
    }

    [vc presentViewController:menu animated:YES completion:nil];
}

@interface MMGestureProxy : NSObject
@end

@implementation MMGestureProxy
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIResponder *r = gesture.view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            MMShowSettingsMenu((UIViewController *)r);
            break;
        }
    }
}
@end

static MMGestureProxy *MMSharedGestureProxy(void) {
    static MMGestureProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMGestureProxy new];
    });
    return proxy;
}

static UIView *MMHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMFloatingHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMFloatingHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = YES;
        host.clipsToBounds = NO;
        [root addSubview:host];

        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:MMSharedGestureProxy() action:@selector(handleLongPress:)];
        [host addGestureRecognizer:press];
    }
    return host;
}

static UIVisualEffectView *MMBlur(UIView *host) {
    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMFloatingBlurTag];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        blur.tag = kMMFloatingBlurTag;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];
    }
    blur.frame = host.bounds;

    UIColor *tint = MMBackgroundTintColor(host.traitCollection);
    CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
    [tint getRed:&r green:&g blue:&b alpha:&a];
    blur.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:MMBackgroundAlpha(host.traitCollection)];

    MMSetRadius(blur, host.bounds.size.height * 0.5);
    blur.layer.masksToBounds = YES;
    blur.clipsToBounds = YES;
    return blur;
}

static UIView *MMCapsule(UIView *host) {
    UIView *capsule = [host viewWithTag:kMMFloatingCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMFloatingCapsuleTag;
        capsule.userInteractionEnabled = NO;
        capsule.backgroundColor = [UIColor clearColor];
        capsule.clipsToBounds = YES;
        [host addSubview:capsule];
    }

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    if (!border) {
        border = [UIView new];
        border.tag = kMMFloatingCapsuleBorderTag;
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        border.clipsToBounds = YES;
        [capsule addSubview:border];
    }

    UIView *glow = [capsule viewWithTag:kMMFloatingCapsuleGlowTag];
    if (!glow) {
        glow = [UIView new];
        glow.tag = kMMFloatingCapsuleGlowTag;
        glow.userInteractionEnabled = NO;
        glow.backgroundColor = [UIColor clearColor];
        glow.clipsToBounds = YES;
        [capsule addSubview:glow];
    }

    return capsule;
}

static UIView *MMButtonsContainer(UIView *host) {
    UIView *container = [host viewWithTag:kMMFloatingButtonsTag];
    if (!container) {
        container = [UIView new];
        container.tag = kMMFloatingButtonsTag;
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = YES;
        container.clipsToBounds = NO;
        [host addSubview:container];
    }
    container.frame = host.bounds;
    return container;
}

static void MMStyleHost(UIView *host) {
    MMSetRadius(host, host.bounds.size.height * 0.5);
    host.layer.borderWidth = 0.36;
    host.layer.borderColor = MMRGBA(255,255,255,MMHostBorderAlpha(host.traitCollection)).CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(host.traitCollection) ? 0.22 : 0.10)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 14.0;
    host.layer.shadowOffset = CGSizeMake(0, 7);
}

static CGRect MMSlotFrame(UIView *host, NSInteger index, NSInteger count) {
    CGFloat side = 16.0;
    CGFloat top = 6.0;
    CGFloat totalW = host.bounds.size.width - side * 2.0;
    CGFloat slotW = floor(totalW / MAX(count, 1));
    CGFloat slotH = host.bounds.size.height - top * 2.0;
    CGFloat x = side + slotW * index;
    CGFloat w = (index == count - 1) ? (host.bounds.size.width - side - x) : slotW;
    return CGRectMake(x, top, w, slotH);
}

static CGRect MMCapsuleFrame(UIView *host, NSInteger index, NSInteger count) {
    return CGRectInset(MMSlotFrame(host, index, count), 4.0, 2.0);
}

static void MMStyleCapsule(UIView *host, NSInteger selectedIndex, NSInteger count) {
    if (count <= 0) return;

    UIView *capsule = MMCapsule(host);
    CGRect frame = MMCapsuleFrame(host, selectedIndex, count);
    capsule.frame = frame;

    UIColor *capsuleTint = MMCapsuleTintColor(host.traitCollection);
    CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
    [capsuleTint getRed:&r green:&g blue:&b alpha:&a];
    capsule.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:MMCapsuleAlpha(host.traitCollection)];

    MMSetRadius(capsule, frame.size.height * 0.5);
    capsule.clipsToBounds = YES;
    capsule.layer.masksToBounds = YES;

    UIView *border = [capsule viewWithTag:kMMFloatingCapsuleBorderTag];
    border.frame = capsule.bounds;
    border.layer.borderWidth = 0.48;
    border.layer.borderColor = MMRGBA(255,255,255,MMCapsuleBorderAlpha(host.traitCollection)).CGColor;
    MMSetRadius(border, border.bounds.size.height * 0.5);
    border.clipsToBounds = YES;
    border.layer.masksToBounds = YES;

    UIView *glow = [capsule viewWithTag:kMMFloatingCapsuleGlowTag];
    glow.frame = CGRectInset(capsule.bounds, 1.0, 1.0);
    MMSetRadius(glow, glow.bounds.size.height * 0.5);
    glow.clipsToBounds = YES;
    glow.layer.masksToBounds = YES;

    CAGradientLayer *grad = nil;
    for (CALayer *layer in glow.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            grad = (CAGradientLayer *)layer;
            break;
        }
    }
    if (!grad) {
        grad = [CAGradientLayer layer];
        [glow.layer addSublayer:grad];
    }
    grad.frame = glow.bounds;
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint = CGPointMake(0.5, 1.0);
    grad.colors = @[
        (__bridge id)MMRGBA(255,255,255,MMGlowTopAlpha(host.traitCollection)).CGColor,
        (__bridge id)MMRGBA(255,255,255,MMGlowMidAlpha(host.traitCollection)).CGColor,
        (__bridge id)MMRGBA(255,255,255,0.0).CGColor
    ];
}

@interface MMFloatingTabButton : UIControl
@property (nonatomic, retain) UIImageView *mm_imageView;
@property (nonatomic, retain) UILabel *mm_titleLabel;
@property (nonatomic, retain) UILabel *mm_badgeLabel;
@property (nonatomic, assign) NSInteger mm_index;
@end

@implementation MMFloatingTabButton
@end

static MMFloatingTabButton *MMEnsureButton(UIView *container, NSInteger index) {
    MMFloatingTabButton *button = (MMFloatingTabButton *)[container viewWithTag:6000 + index];
    if (!button) {
        button = [MMFloatingTabButton new];
        button.tag = 6000 + index;
        button.backgroundColor = [UIColor clearColor];
        button.opaque = NO;
        button.clipsToBounds = NO;

        UIImageView *imageView = [UIImageView new];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.opaque = NO;
        button.mm_imageView = imageView;
        [button addSubview:imageView];

        UILabel *titleLabel = [UILabel new];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.72;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.opaque = NO;
        button.mm_titleLabel = titleLabel;
        [button addSubview:titleLabel];

        UILabel *badgeLabel = [UILabel new];
        badgeLabel.textAlignment = NSTextAlignmentCenter;
        badgeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        badgeLabel.textColor = [UIColor whiteColor];
        badgeLabel.backgroundColor = MMRGBA(255, 83, 83, 1.0);
        badgeLabel.clipsToBounds = YES;
        badgeLabel.hidden = YES;
        button.mm_badgeLabel = badgeLabel;
        [button addSubview:badgeLabel];

        [container addSubview:button];
    }
    return button;
}

static NSArray *MMOriginalItemViews(UITabBar *tabBar) {
    NSMutableArray *items = [NSMutableArray array];
    for (UIView *sub in tabBar.subviews) {
        NSString *name = NSStringFromClass([sub class]);
        if ([name containsString:@"MMTabBarItemView"]) {
            [items addObject:sub];
        }
    }
    [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat x1 = CGRectGetMinX(a.frame);
        CGFloat x2 = CGRectGetMinX(b.frame);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return items;
}

static void MMSelectIndex(UIView *view, NSInteger index) {
    UIResponder *r = view;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                UITabBar *tabBar = MMFindTabBar(vc);
                if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
                    @try { [(id)vc setSelectedIndex:index]; } @catch (__unused NSException *e) {}
                }
                if (tabBar && index >= 0 && index < (NSInteger)tabBar.items.count) {
                    @try { tabBar.selectedItem = [tabBar.items objectAtIndex:index]; } @catch (__unused NSException *e) {}
                }
                break;
            }
        }
    }
}

static void MMUpdateButtons(UIViewController *vc, UITabBar *tabBar, UIView *host) {
    UIView *container = MMButtonsContainer(host);
    NSArray *items = tabBar.items;
    NSArray *originalItemViews = MMOriginalItemViews(tabBar);
    NSInteger count = [items count];
    if (count <= 0) return;

    NSInteger selectedIndex = 0;
    if (tabBar.selectedItem) {
        NSInteger idx = [items indexOfObject:tabBar.selectedItem];
        if (idx != NSNotFound) selectedIndex = idx;
    }

    MMStyleCapsule(host, selectedIndex, count);

    NSMutableSet *validTags = [NSMutableSet set];
    for (NSInteger i = 0; i < count; i++) {
        [validTags addObject:[NSNumber numberWithInteger:(6000 + i)]];
        MMFloatingTabButton *button = MMEnsureButton(container, i);
        button.mm_index = i;
        [button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            MMSelectIndex(button, button.mm_index);
        }] forControlEvents:UIControlEventTouchUpInside];

        CGRect frame = (i == selectedIndex) ? MMCapsuleFrame(host, i, count) : MMSlotFrame(host, i, count);
        button.frame = frame;
        button.backgroundColor = [UIColor clearColor];
        button.layer.backgroundColor = [UIColor clearColor].CGColor;

        UITabBarItem *item = [items objectAtIndex:i];
        UIView *sourceItemView = (i < (NSInteger)[originalItemViews count]) ? [originalItemViews objectAtIndex:i] : nil;
        UIImageView *sourceImageView = MMKVC(sourceItemView, @"_imageView");
        UIImage *img = nil;
        if ([sourceImageView isKindOfClass:[UIImageView class]] && sourceImageView.image) {
            img = sourceImageView.image;
        } else if (i == selectedIndex && item.selectedImage) {
            img = item.selectedImage;
        } else {
            img = item.image;
        }

        if (img) {
            img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            button.mm_imageView.hidden = NO;
            button.mm_imageView.image = img;
        } else {
            button.mm_imageView.hidden = YES;
            button.mm_imageView.image = nil;
        }

        UIColor *titleColor = (i == selectedIndex) ? MMSelectedColor(host.traitCollection) : MMNormalColor(host.traitCollection);
        button.mm_imageView.tintColor = titleColor;
        button.mm_titleLabel.text = item.title ?: @"";
        button.mm_titleLabel.textColor = titleColor;
        button.mm_titleLabel.font = [UIFont systemFontOfSize:11 weight:(i == selectedIndex ? UIFontWeightSemibold : UIFontWeightRegular)];

        NSString *badge = item.badgeValue;
        if ([badge length] > 0) {
            button.mm_badgeLabel.hidden = NO;
            button.mm_badgeLabel.text = badge;
        } else {
            button.mm_badgeLabel.hidden = YES;
            button.mm_badgeLabel.text = nil;
        }

        CGFloat bw = button.bounds.size.width;
        CGFloat bh = button.bounds.size.height;
        CGFloat iconSize = 27.0;
        CGFloat titleH = 14.0;
        CGFloat spacing = 4.0;
        CGFloat totalH = (button.mm_imageView.hidden ? titleH : (iconSize + spacing + titleH));
        CGFloat startY = floor((bh - totalH) * 0.5);
        if (startY < 4.0) startY = 4.0;

        if (!button.mm_imageView.hidden) {
            button.mm_imageView.frame = CGRectMake(floor((bw - iconSize) * 0.5), startY, iconSize, iconSize);
            button.mm_titleLabel.frame = CGRectMake(0.0, startY + iconSize + spacing, bw, titleH);
        } else {
            button.mm_titleLabel.frame = CGRectMake(0.0, floor((bh - titleH) * 0.5), bw, titleH);
        }

        CGFloat badgeW = MAX(18.0, MIN(28.0, 10.0 + [badge length] * 8.0));
        if (!button.mm_imageView.hidden) {
            button.mm_badgeLabel.frame = CGRectMake(CGRectGetMaxX(button.mm_imageView.frame) - 2.0, CGRectGetMinY(button.mm_imageView.frame) - 4.0, badgeW, 18.0);
        }
        MMSetRadius(button.mm_badgeLabel, 9.0);
    }

    for (UIView *sub in [[container subviews] copy]) {
        if (![validTags containsObject:[NSNumber numberWithInteger:sub.tag]]) {
            [sub removeFromSuperview];
        }
    }
}

static void MMHideOriginalTabBarVisuals(UITabBar *tabBar) {
    tabBar.hidden = NO;
    tabBar.alpha = 0.01;
    tabBar.userInteractionEnabled = NO;
    tabBar.backgroundImage = [UIImage new];
    tabBar.shadowImage = [UIImage new];
    tabBar.backgroundColor = [UIColor clearColor];
    tabBar.barTintColor = [UIColor clearColor];
    tabBar.translucent = YES;

    if (NSClassFromString(@"UITabBarAppearance")) {
        UITabBarAppearance *appearance = [UITabBarAppearance new];
        [appearance configureWithTransparentBackground];
        appearance.backgroundColor = [UIColor clearColor];
        appearance.shadowColor = [UIColor clearColor];
        tabBar.standardAppearance = appearance;
        if ([tabBar respondsToSelector:@selector(setScrollEdgeAppearance:)]) {
            [(id)tabBar performSelector:@selector(setScrollEdgeAppearance:) withObject:appearance];
        }
    }

    for (UIView *sub in tabBar.subviews) {
        sub.hidden = YES;
        sub.alpha = 0.0;
        sub.userInteractionEnabled = NO;
    }
}



static void MMTriggerGestureTargets(UIGestureRecognizer *gesture) {
    NSArray *targets = nil;
    @try {
        targets = [gesture valueForKey:@"_targets"];
    } @catch (__unused NSException *e) {
        targets = nil;
    }

    for (id targetObj in targets) {
        id target = nil;
        SEL action = NULL;
        @try { target = [targetObj valueForKey:@"target"]; } @catch (__unused NSException *e) {}
        @try { action = NSSelectorFromString([targetObj valueForKey:@"action"]); } @catch (__unused NSException *e) {}
        if (target && action && [target respondsToSelector:action]) {
            ((void (*)(id, SEL, id))objc_msgSend)(target, action, gesture);
        }
    }
}

static void MMTriggerSearchBar(UIView *searchBar) {
    if (!searchBar) return;

    if ([searchBar isKindOfClass:[UIControl class]]) {
        UIControl *control = (UIControl *)searchBar;
        [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        [control sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
    }

    for (UIGestureRecognizer *gesture in searchBar.gestureRecognizers) {
        MMTriggerGestureTargets(gesture);
    }

    for (UIView *sub in searchBar.subviews) {
        if ([sub isKindOfClass:[UIControl class]]) {
            UIControl *control = (UIControl *)sub;
            [control sendActionsForControlEvents:UIControlEventTouchUpInside];
            [control sendActionsForControlEvents:UIControlEventPrimaryActionTriggered];
        }
        for (UIGestureRecognizer *gesture in sub.gestureRecognizers) {
            MMTriggerGestureTargets(gesture);
        }
    }

    @try {
        if ([searchBar respondsToSelector:@selector(becomeFirstResponder)]) {
            [searchBar becomeFirstResponder];
        }
    } @catch (__unused NSException *e) {
    }
}

@interface MMDockSearchTapProxy : NSObject
@property (nonatomic, assign) UIView *searchBar;
@end

@implementation MMDockSearchTapProxy
- (void)handleTap:(__unused id)sender {
    MMTriggerSearchBar(self.searchBar);
}
@end

static MMDockSearchTapProxy *MMSharedDockSearchTapProxy(void) {
    static MMDockSearchTapProxy *proxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [MMDockSearchTapProxy new];
    });
    return proxy;
}

static UIView *MMFindSearchBarInView(UIView *root) {
    if (!root) return nil;
    NSString *name = NSStringFromClass([root class]);
    if ([name containsString:@"WCSearchBar"]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = MMFindSearchBarInView(sub);
        if (found) return found;
    }
    return nil;
}

static UIViewController *MMCurrentSelectedContentControllerFromMainTab(UIViewController *vc) {
    return MMCurrentContentController(vc);
}

static UIView *MMDockSearchHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMDockSearchHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMDockSearchHostTag;
        host.backgroundColor = [UIColor clearColor];
        host.userInteractionEnabled = YES;
        host.clipsToBounds = NO;
        [root addSubview:host];

        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        blur.tag = kMMDockSearchBlurTag;
        blur.userInteractionEnabled = NO;
        [host addSubview:blur];

        UIImageView *icon = [UIImageView new];
        icon.tag = kMMDockSearchIconTag;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.userInteractionEnabled = NO;
        [host addSubview:icon];

        UIButton *hit = [UIButton buttonWithType:UIButtonTypeCustom];
        hit.tag = kMMDockSearchHitButtonTag;
        hit.backgroundColor = [UIColor clearColor];
        [host addSubview:hit];
    }
    return host;
}

static void MMHideDockSearchHost(UIView *root) {
    UIView *host = [root viewWithTag:kMMDockSearchHostTag];
    if (host) host.hidden = YES;
}

static void MMUpdateDockSearchButton(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    UIView *root = vc.view;
    UIViewController *content = MMCurrentSelectedContentControllerFromMainTab(vc);
    NSString *contentName = NSStringFromClass([content class]);
    UIView *searchBar = nil;

    if ([contentName isEqualToString:@"NewMainFrameViewController"]) {
        searchBar = MMFindSearchBarInView(content.view);
    }

    if (![contentName isEqualToString:@"NewMainFrameViewController"] || !searchBar) {
        MMHideDockSearchHost(root);
        [CATransaction commit];
        return;
    }

    CGFloat inset = MMBottomInset(root);
    CGFloat margin = 18.0;
    CGFloat dockSize = 84.0;
    CGFloat y = CGRectGetHeight(root.bounds) - inset - dockSize - 10.0;
    CGFloat x = CGRectGetWidth(root.bounds) - margin - dockSize;

    UIView *host = MMDockSearchHost(root);
    host.hidden = NO;
    host.frame = CGRectMake(x, y, dockSize, dockSize);
    MMSetRadius(host, dockSize * 0.5);
    host.layer.borderWidth = 0.36;
    host.layer.borderColor = MMRGBA(255,255,255,MMHostBorderAlpha(host.traitCollection)).CGColor;
    host.layer.shadowColor = [UIColor colorWithWhite:0 alpha:(MMIsDark(host.traitCollection) ? 0.22 : 0.10)].CGColor;
    host.layer.shadowOpacity = 1.0;
    host.layer.shadowRadius = 14.0;
    host.layer.shadowOffset = CGSizeMake(0, 7);

    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kMMDockSearchBlurTag];
    blur.frame = host.bounds;
    UIColor *tint = MMBackgroundTintColor(host.traitCollection);
    CGFloat r = 1.0, g = 1.0, b = 1.0, a = 1.0;
    [tint getRed:&r green:&g blue:&b alpha:&a];
    blur.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:MMBackgroundAlpha(host.traitCollection)];
    MMSetRadius(blur, dockSize * 0.5);
    blur.layer.masksToBounds = YES;
    blur.clipsToBounds = YES;

    UIImageView *icon = (UIImageView *)[host viewWithTag:kMMDockSearchIconTag];
    icon.frame = CGRectMake(floor((dockSize - 30.0) * 0.5), floor((dockSize - 30.0) * 0.5), 30.0, 30.0);
    icon.tintColor = MMNormalColor(host.traitCollection);
    if ([UIImage respondsToSelector:@selector(systemImageNamed:)]) {
        icon.image = [[UIImage systemImageNamed:@"magnifyingglass"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    UIButton *hit = (UIButton *)[host viewWithTag:kMMDockSearchHitButtonTag];
    hit.frame = host.bounds;
    [hit removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    MMDockSearchTapProxy *proxy = MMSharedDockSearchTapProxy();
    proxy.searchBar = searchBar;
    [hit addTarget:proxy action:@selector(handleTap:) forControlEvents:UIControlEventTouchUpInside];

    [root bringSubviewToFront:host];
    [CATransaction commit];
}



@interface MMFloatingObserver : NSObject
@end

@implementation MMFloatingObserver
- (void)appDidBecomeActive:(NSNotification *)note {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        UIViewController *root = window.rootViewController;
        if ([NSStringFromClass([root class]) isEqualToString:@"MainTabBarViewController"]) {
            MMRequestFloatingBarRefresh(root);
            break;
        }
    }
}
@end

static MMFloatingObserver *MMSharedFloatingObserver(void) {
    static MMFloatingObserver *observer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        observer = [MMFloatingObserver new];
        [[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    });
    return observer;
}

%hook MainTabBarViewController

- (void)viewDidLoad {
    %orig;
    MMSharedFloatingObserver();
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewDidLayoutSubviews {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)viewSafeAreaInsetsDidChange {
    %orig;
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

- (void)setSelectedIndex:(NSUInteger)index {
    %orig(index);
    MMRequestFloatingBarRefresh((UIViewController *)self);
}

%end

%hook UITabBar

- (void)setSelectedItem:(UITabBarItem *)item {
    %orig(item);
    UIResponder *r = self;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)r;
            if ([NSStringFromClass([vc class]) isEqualToString:@"MainTabBarViewController"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    MMRequestFloatingBarRefresh(vc);
                });
                break;
            }
        }
    }
}

%end
