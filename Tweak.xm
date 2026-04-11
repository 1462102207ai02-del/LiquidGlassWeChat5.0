#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface MainTabBarViewController : UIViewController
@end

static NSInteger const kHostTag = 990201;
static NSInteger const kBlurTag = 990202;
static NSInteger const kCapsuleTag = 990203;

static BOOL updating = NO;

static BOOL isDark(UITraitCollection *t){return t.userInterfaceStyle==UIUserInterfaceStyleDark;}

static void radius(UIView *v,CGFloat r){
    v.layer.cornerRadius=r;
    if([v.layer respondsToSelector:@selector(setCornerCurve:)])
        v.layer.cornerCurve=kCACornerCurveContinuous;
}

static UITabBar *findTabBar(UIViewController *vc){
    for(UIView *v in vc.view.subviews){
        if([v isKindOfClass:[UITabBar class]]) return (UITabBar*)v;
    }
    return nil;
}

static NSArray *itemViews(UITabBar *tb){
    NSMutableArray *arr=[NSMutableArray array];
    for(UIView *v in tb.subviews){
        NSString *n=NSStringFromClass(v.class);
        if([n containsString:@"UITabBarButton"]||[n containsString:@"MMTabBarItemView"])
            [arr addObject:v];
    }
    [arr sortUsingComparator:^NSComparisonResult(UIView*a,UIView*b){
        return a.frame.origin.x>b.frame.origin.x;
    }];
    return arr;
}

static UIView *host(UIView *root){
    UIView *v=[root viewWithTag:kHostTag];
    if(!v){
        v=[UIView new];
        v.tag=kHostTag;
        v.userInteractionEnabled=NO;
        v.backgroundColor=UIColor.clearColor;
        [root addSubview:v];
    }
    return v;
}

static void makeTabBarTransparent(UITabBar *tb){
    tb.backgroundImage=[UIImage new];
    tb.shadowImage=[UIImage new];
    tb.backgroundColor=UIColor.clearColor;
    tb.barTintColor=UIColor.clearColor;
}

static UIVisualEffectView *blur(UIView *h){
    UIVisualEffectView *b=[h viewWithTag:kBlurTag];
    if(!b){
        b=[[UIVisualEffectView alloc]initWithEffect:nil];
        b.tag=kBlurTag;
        b.userInteractionEnabled=NO;
        [h addSubview:b];
    }
    b.frame=h.bounds;
    if(@available(iOS13,*)){
        b.effect=[UIBlurEffect effectWithStyle:
            isDark(h.traitCollection)?
            UIBlurEffectStyleSystemUltraThinMaterialDark:
            UIBlurEffectStyleSystemThinMaterialLight];
    }
    radius(b,h.bounds.size.height/2);
    return b;
}

static UIView *capsule(UIView *h){
    UIView *c=[h viewWithTag:kCapsuleTag];
    if(!c){
        c=[UIView new];
        c.tag=kCapsuleTag;
        c.userInteractionEnabled=NO;
        [h addSubview:c];
    }
    return c;
}

static void update(UIViewController *vc){
    if(updating)return;
    updating=YES;

    UITabBar *tb=findTabBar(vc);
    if(!tb){updating=NO;return;}

    makeTabBarTransparent(tb);

    UIView *root=vc.view;
    UIView *h=host(root);

    CGFloat hgt=64;
    CGFloat y=tb.frame.origin.y+(tb.frame.size.height-hgt)/2;
    h.frame=CGRectMake(16,y,root.bounds.size.width-32,hgt);

    blur(h);

    h.layer.shadowColor=[UIColor blackColor].CGColor;
    h.layer.shadowOpacity=0.15;
    h.layer.shadowRadius=20;
    h.layer.shadowOffset=CGSizeMake(0,10);
    radius(h,hgt/2);

    NSArray *views=itemViews(tb);
    NSInteger sel=[tb.items indexOfObject:tb.selectedItem];

    UIView *cap=capsule(h);
    if(sel>=0 && sel<views.count){
        UIView *v=views[sel];
        CGRect r=[tb convertRect:v.frame toView:h];
        CGFloat w=MIN(r.size.width+16,72);
        CGFloat x=CGRectGetMidX(r)-w/2;
        cap.frame=CGRectMake(x,6,w,hgt-12);
        cap.backgroundColor=isDark(h.traitCollection)?
            [UIColor colorWithWhite:1 alpha:0.1]:
            [UIColor colorWithWhite:1 alpha:0.2];
        radius(cap,cap.bounds.size.height/2);
        cap.hidden=NO;
    }else cap.hidden=YES;

    [root insertSubview:h belowSubview:tb];
    [root bringSubviewToFront:tb];

    updating=NO;
}

%hook MainTabBarViewController

-(void)viewDidLayoutSubviews{
    %orig;
    update((UIViewController*)self);
}

-(void)setSelectedIndex:(NSUInteger)i{
    %orig(i);
    update((UIViewController*)self);
}

%end
