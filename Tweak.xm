#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface MainTabBarViewController : UIViewController
- (void)setSelectedIndex:(NSUInteger)index;
@end

static UIView *host;
static UIVisualEffectView *blurView;

static UITabBar *findTabBar(UIView *view){
    for(UIView *v in view.subviews){
        if([v isKindOfClass:[UITabBar class]]) return (UITabBar *)v;
    }
    return nil;
}

static void updateBar(MainTabBarViewController *vc){
    UITabBar *tabBar = findTabBar(vc.view);
    if(!tabBar) return;

    tabBar.hidden = YES;

    if(!host){
        host = [[UIView alloc] init];
        host.layer.cornerRadius = 30;
        host.clipsToBounds = NO;

        blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialLight]];
        blurView.layer.cornerRadius = 30;
        blurView.clipsToBounds = YES;
        blurView.frame = host.bounds;
        [host addSubview:blurView];

        [vc.view addSubview:host];
    }

    CGFloat h = 60;
    CGFloat bottom = vc.view.safeAreaInsets.bottom;

    host.frame = CGRectMake(20, vc.view.bounds.size.height - h - bottom + 10, vc.view.bounds.size.width - 40, h);
    blurView.frame = host.bounds;

    NSArray *items = tabBar.items;
    NSInteger count = items.count;

    for(UIView *v in host.subviews){
        if(v != blurView) [v removeFromSuperview];
    }

    CGFloat w = host.bounds.size.width / count;

    for(int i=0;i<count;i++){
        UITabBarItem *item = items[i];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(i*w, 0, w, h);
        btn.tag = i;

        UIImage *img = item.image;
        if(i == tabBar.selectedItem.tag && item.selectedImage){
            img = item.selectedImage;
        }

        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake((w-24)/2, 8, 24, 24)];
        iv.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        iv.tintColor = (i == tabBar.selectedItem.tag) ? [UIColor systemGreenColor] : [UIColor grayColor];
        [btn addSubview:iv];

        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, 32, w, 16)];
        lab.text = item.title;
        lab.font = [UIFont systemFontOfSize:10];
        lab.textAlignment = NSTextAlignmentCenter;
        lab.textColor = (i == tabBar.selectedItem.tag) ? [UIColor systemGreenColor] : [UIColor grayColor];
        [btn addSubview:lab];

        [btn addTarget:vc action:@selector(setSelectedIndex:) forControlEvents:UIControlEventTouchUpInside];

        [host addSubview:btn];
    }
}

%hook MainTabBarViewController

- (void)viewDidLayoutSubviews{
    %orig;
    updateBar(self);
}

%end
