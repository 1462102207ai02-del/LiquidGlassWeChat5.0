#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSInteger const kMMGlassHostTag = 960001;
static NSInteger const kMMGlassViewTag = 960002;
static NSInteger const kMMButtonsContainerTag = 960003;
static NSInteger const kMMCapsuleTag = 960004;
static NSInteger const kMMCapsuleBorderTag = 960005;
static NSInteger const kMMCapsuleGlowTag = 960006;

static BOOL kMMUpdatingLayout = NO;

static UIColor *MMRGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

static BOOL MMIsDark(UITraitCollection *trait) {
    if ([trait respondsToSelector:@selector(userInterfaceStyle)]) {
        return trait.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

static CGFloat MMBottomInset(UIView *view) {
    if ([view respondsToSelector:@selector(safeAreaInsets)]) {
        return view.safeAreaInsets.bottom;
    }
    return 0;
}

static void MMSetRadius(UIView *v, CGFloat r) {
    v.layer.cornerRadius = r;
    if ([v.layer respondsToSelector:@selector(setCornerCurve:)]) {
        v.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static CAGradientLayer *MMFindGrad(CALayer *l, NSString *n) {
    for (CALayer *s in l.sublayers) {
        if ([s isKindOfClass:[CAGradientLayer class]] && [s.name isEqualToString:n]) return (CAGradientLayer*)s;
    }
    return nil;
}

static UITabBar *MMFindTabBar(UIViewController *vc) {
    @try {
        id tb = [vc valueForKey:@"tabBar"];
        if ([tb isKindOfClass:[UITabBar class]]) return tb;
    } @catch (__unused NSException *e) {}
    for (UIView *v in vc.view.subviews) {
        if ([v isKindOfClass:[UITabBar class]]) return (UITabBar*)v;
        if ([NSStringFromClass(v.class) containsString:@"MMTabBar"]) return (UITabBar*)v;
    }
    return nil;
}

static UIViewController *MMFindVC(UIView *v) {
    UIResponder *r = v;
    while (r) {
        r = [r nextResponder];
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController*)r;
    }
    return nil;
}

static NSInteger MMIndex(UITabBar *tb) {
    if (!tb || tb.items.count == 0) return 0;
    if (tb.selectedItem) {
        NSInteger i = [tb.items indexOfObject:tb.selectedItem];
        if (i != NSNotFound) return i;
    }
    return 0;
}

static NSArray<UIView*> *MMButtons(UITabBar *tb) {
    NSMutableArray *a = [NSMutableArray array];
    for (UIView *v in tb.subviews) {
        NSString *n = NSStringFromClass(v.class);
        if ([n containsString:@"MMTabBarItemView"] || [n containsString:@"UITabBarButton"]) {
            [a addObject:v];
        }
    }
    [a sortUsingComparator:^NSComparisonResult(UIView *a1, UIView *a2) {
        return CGRectGetMinX(a1.frame) < CGRectGetMinX(a2.frame);
    }];
    return a;
}

static UIImage *MMSnap(UIView *v) {
    CGSize s = v.bounds.size;
    if (s.width<=0||s.height<=0) return nil;
    UIGraphicsBeginImageContextWithOptions(s, NO, UIScreen.mainScreen.scale);
    [v.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

static void MMClear(UITabBar *tb) {
    tb.backgroundImage = [UIImage new];
    tb.shadowImage = [UIImage new];
    tb.backgroundColor = UIColor.clearColor;
    tb.barTintColor = UIColor.clearColor;
    if (NSClassFromString(@"UITabBarAppearance")) {
        UITabBarAppearance *a = [UITabBarAppearance new];
        [a configureWithTransparentBackground];
        tb.standardAppearance = a;
        if ([tb respondsToSelector:@selector(setScrollEdgeAppearance:)]) {
            [(id)tb performSelector:@selector(setScrollEdgeAppearance:) withObject:a];
        }
    }
    for (UIView *v in tb.subviews) {
        NSString *n = NSStringFromClass(v.class);
        if ([n containsString:@"Background"]||[n containsString:@"Shadow"]) {
            v.hidden = YES;
        }
    }
}

static UIView *MMHost(UIView *c) {
    UIView *h = [c viewWithTag:kMMGlassHostTag];
    if (!h) {
        h = [UIView new];
        h.tag = kMMGlassHostTag;
        [c addSubview:h];
    }
    return h;
}

static UIVisualEffectView *MMGlass(UIView *h) {
    UIVisualEffectView *g = [h viewWithTag:kMMGlassViewTag];
    if (!g) {
        g = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        g.tag = kMMGlassViewTag;
        [h addSubview:g];
    }
    g.frame = h.bounds;
    g.backgroundColor = MMIsDark(h.traitCollection)?MMRGBA(255,255,255,0.06):MMRGBA(255,255,255,0.14);
    MMSetRadius(g, h.bounds.size.height/2);
    return g;
}

static UIView *MMContainer(UIView *h) {
    UIView *c = [h viewWithTag:kMMButtonsContainerTag];
    if (!c) {
        c = [UIView new];
        c.tag = kMMButtonsContainerTag;
        [h addSubview:c];
    }
    c.frame = h.bounds;
    return c;
}

static UIView *MMCapsule(UIView *h) {
    UIView *c = [h viewWithTag:kMMCapsuleTag];
    if (!c) {
        c = [UIView new];
        c.tag = kMMCapsuleTag;
        [h addSubview:c];
    }
    return c;
}

static void MMCapsuleLayout(UIView *h, NSInteger idx, NSInteger cnt) {
    if (cnt==0) return;
    UIView *c = MMCapsule(h);
    CGFloat side=8, top=6;
    CGFloat w=(h.bounds.size.width-side*2)/cnt;
    CGFloat hgt=h.bounds.size.height-top*2;
    c.frame = CGRectMake(side+w*idx+2, top, w-4, hgt);
    c.backgroundColor = MMIsDark(h.traitCollection)?MMRGBA(255,255,255,0.12):MMRGBA(255,255,255,0.3);
    MMSetRadius(c, hgt/2);
}

@interface MMBtn : UIControl
@property(nonatomic,strong)UIImageView *img;
@end

@implementation MMBtn
- (void)tap {
    NSInteger i=self.tag-1000;
    UIViewController *vc=MMFindVC(self);
    if ([vc respondsToSelector:@selector(setSelectedIndex:)]) {
        [(id)vc setSelectedIndex:i];
    }
}
@end

static MMBtn *MMMake(CGRect f, UIImage *img, NSInteger i) {
    MMBtn *b=[MMBtn new];
    b.frame=f;
    b.tag=1000+i;
    UIImageView *iv=[[UIImageView alloc]initWithFrame:CGRectInset(b.bounds,4,4)];
    iv.image=img;
    iv.contentMode=UIViewContentModeScaleAspectFit;
    [b addSubview:iv];
    b.img=iv;
    [b addTarget:b action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static void MMBuild(UITabBar *tb, UIView *h) {
    UIView *c=MMContainer(h);
    [c.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    NSArray *btns=MMButtons(tb);
    NSInteger cnt=btns.count;
    if (!cnt) return;

    NSInteger sel=MMIndex(tb);

    CGFloat side=8, top=6;
    CGFloat w=(c.bounds.size.width-side*2)/cnt;
    CGFloat hgt=c.bounds.size.height-top*2;

    MMCapsuleLayout(h, sel, cnt);

    for (NSInteger i=0;i<cnt;i++) {
        UIView *v=btns[i];
        UIImage *img=MMSnap(v);
        CGFloat x=side+w*i;
        CGRect f=CGRectMake(x, top, w, hgt);
        MMBtn *b=MMMake(f,img,i);
        [c addSubview:b];
    }
}

static void MMUpdate(UIViewController *vc) {
    if (kMMUpdatingLayout) return;
    kMMUpdatingLayout=YES;

    UIView *v=vc.view;
    UITabBar *tb=MMFindTabBar(vc);
    if (!tb) { kMMUpdatingLayout=NO; return; }

    CGFloat inset=MMBottomInset(v);
    CGFloat h=64, m=16;
    CGRect f=CGRectMake(m, v.bounds.size.height-inset-h-10, v.bounds.size.width-m*2, h);

    UIView *host=MMHost(v);
    host.frame=f;
    MMSetRadius(host,h/2);

    MMGlass(host);

    MMClear(tb);

    MMBuild(tb,host);

    tb.frame=CGRectMake(0, v.bounds.size.height+200,1,1);
    tb.userInteractionEnabled=NO;

    [v bringSubviewToFront:host];

    kMMUpdatingLayout=NO;
}

%hook MMTabBarController
- (void)viewDidLoad { %orig; dispatch_async(dispatch_get_main_queue(),^{MMUpdate((UIViewController*)self);}); }
- (void)viewDidLayoutSubviews { %orig; MMUpdate((UIViewController*)self); }
- (void)viewSafeAreaInsetsDidChange { %orig; MMUpdate((UIViewController*)self); }
- (void)setSelectedIndex:(NSUInteger)i { %orig(i); dispatch_async(dispatch_get_main_queue(),^{MMUpdate((UIViewController*)self);}); }
%end

%hook UITabBar
- (void)setSelectedItem:(UITabBarItem *)item {
    %orig(item);
    UIViewController *vc=MMFindVC(self);
    if (vc) dispatch_async(dispatch_get_main_queue(),^{MMUpdate(vc);});
}
%end
