#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

static NSInteger const kMMFloatingHostTag = 990201;
static NSInteger const kMMFloatingBlurTag = 990202;
static NSInteger const kMMFloatingCapsuleTag = 990203;
static NSInteger const kMMFloatingButtonsTag = 990206;

static BOOL kMMUpdatingLayout = NO;

static BOOL MMIsDark(UITraitCollection *trait){return trait.userInterfaceStyle==UIUserInterfaceStyleDark;}
static CGFloat MMBottomInset(UIView *v){return v.safeAreaInsets.bottom;}
static void MMSetRadius(UIView *v,CGFloat r){v.layer.cornerRadius=r;if([v.layer respondsToSelector:@selector(setCornerCurve:)])v.layer.cornerCurve=kCACornerCurveContinuous;}

static UITabBar *MMFindTabBar(UIViewController *vc){
    for(UIView *v in vc.view.subviews){
        if([v isKindOfClass:[UITabBar class]])return (UITabBar*)v;
    }
    return nil;
}

static UIView *MMHost(UIView *root){
    UIView *v=[root viewWithTag:kMMFloatingHostTag];
    if(!v){
        v=[UIView new];
        v.tag=kMMFloatingHostTag;
        v.backgroundColor=UIColor.clearColor;
        [root addSubview:v];
    }
    return v;
}

static UIVisualEffectView *MMBlur(UIView *host){
    UIVisualEffectView *b=(UIVisualEffectView*)[host viewWithTag:kMMFloatingBlurTag];
    if(!b){
        b=[[UIVisualEffectView alloc]initWithEffect:nil];
        b.tag=kMMFloatingBlurTag;
        [host addSubview:b];
    }
    b.frame=host.bounds;
    if(@available(iOS13,*)){
        b.effect=[UIBlurEffect effectWithStyle:MMIsDark(host.traitCollection)?UIBlurEffectStyleSystemThinMaterialDark:UIBlurEffectStyleSystemThinMaterialLight];
    }
    MMSetRadius(b,host.bounds.size.height/2);
    return b;
}

static void MMStyleHost(UIView *host){
    MMSetRadius(host,host.bounds.size.height/2);
    host.layer.shadowColor=[UIColor blackColor].CGColor;
    host.layer.shadowOpacity=0.12;
    host.layer.shadowRadius=18;
    host.layer.shadowOffset=CGSizeMake(0,8);
}

static void MMHideTabBar(UITabBar *tabBar){
    tabBar.alpha=0.01;
    tabBar.userInteractionEnabled=NO;
    for(UIView *v in tabBar.subviews){
        v.hidden=YES;
    }
}

static void MMSelectIndex(UIView *view,NSInteger idx){
    UIResponder *r=view;
    while(r){
        r=[r nextResponder];
        if([r isKindOfClass:[UIViewController class]]){
            UIViewController *vc=(UIViewController*)r;
            if([vc respondsToSelector:@selector(setSelectedIndex:)]){
                [(id)vc setSelectedIndex:idx];
            }
            break;
        }
    }
}

static void MMUpdateButtons(UIViewController *vc,UITabBar *tabBar,UIView *host){
    NSArray *items=tabBar.items;
    NSInteger count=items.count;
    CGFloat w=host.bounds.size.width/count;
    for(int i=0;i<count;i++){
        UIButton *btn=[host viewWithTag:5000+i];
        if(!btn){
            btn=[UIButton buttonWithType:UIButtonTypeCustom];
            btn.tag=5000+i;
            [btn addTarget:nil action:nil forControlEvents:UIControlEventAllEvents];
            [btn addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action){
                MMSelectIndex(btn,i);
            }] forControlEvents:UIControlEventTouchUpInside];
            [host addSubview:btn];
        }
        btn.frame=CGRectMake(i*w,0,w,host.bounds.size.height);
    }
}

static void MMUpdateFloatingBar(UIViewController *vc){
    if(kMMUpdatingLayout)return;
    kMMUpdatingLayout=YES;

    UIView *root=vc.view;
    UITabBar *tabBar=MMFindTabBar(vc);
    if(!tabBar){kMMUpdatingLayout=NO;return;}

    UIView *host=MMHost(root);

    CGFloat h=80;
    CGFloat margin=16;
    CGFloat inset=MMBottomInset(root);
    CGFloat y=root.bounds.size.height-inset-h-12;

    host.frame=CGRectMake(margin,y,root.bounds.size.width-margin*2,h);

    MMStyleHost(host);
    MMBlur(host);
    MMHideTabBar(tabBar);
    MMUpdateButtons(vc,tabBar,host);

    [root bringSubviewToFront:host];

    kMMUpdatingLayout=NO;
}

%hook MainTabBarViewController

-(void)viewDidLayoutSubviews{
    %orig;
    MMUpdateFloatingBar(self);
}

-(void)setSelectedIndex:(NSUInteger)index{
    %orig(index);
    MMUpdateFloatingBar(self);
}

%end
