#import <UIKit/UIKit.h>

static UIView *MMGetOrCreateHost(UIView *root) {
    UIView *host = [root viewWithTag:999001];
    if (!host) {
        host = [[UIView alloc] init];
        host.tag = 999001;
        host.userInteractionEnabled = NO;
        [root addSubview:host];
    }
    return host;
}

static void MMUpdateLayout(UIViewController *vc) {
    UIView *root = vc.view;
    if (!root) return;

    CGFloat screenH = CGRectGetHeight(root.bounds);
    CGFloat screenW = CGRectGetWidth(root.bounds);
    CGFloat inset = 34.0;

    CGFloat containerHeight = 104.0;
    CGFloat containerY = screenH - inset - containerHeight;

    CGFloat barHeight = 64.0;
    CGFloat barY = containerY + floor((containerHeight - barHeight) * 0.5);

    CGFloat searchSize = 64.0;
    CGFloat searchY = containerY + floor((containerHeight - searchSize) * 0.5);

    CGFloat sideMargin = 18.0;
    CGFloat searchWidth = 64.0;

    CGFloat barWidth = screenW - sideMargin * 2 - searchWidth - 10.0;
    CGFloat barX = sideMargin;

    CGFloat searchX = screenW - sideMargin - searchWidth;

    UIView *host = MMGetOrCreateHost(root);
    host.frame = CGRectMake(0, containerY, screenW, containerHeight);

    UIVisualEffectView *blur = [host viewWithTag:1001];
    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight]];
        blur.tag = 1001;
        [host addSubview:blur];
    }
    blur.frame = host.bounds;

    UIView *bar = [host viewWithTag:1002];
    if (!bar) {
        bar = [[UIView alloc] init];
        bar.tag = 1002;
        [host addSubview:bar];
    }
    bar.frame = CGRectMake(barX, barY - containerY, barWidth, barHeight);
    bar.layer.cornerRadius = 32.0;
    bar.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    bar.layer.borderWidth = 0.8;
    bar.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor;

    UIView *search = [host viewWithTag:1003];
    if (!search) {
        search = [[UIView alloc] init];
        search.tag = 1003;
        [host addSubview:search];
    }
    search.frame = CGRectMake(searchX, searchY - containerY, searchSize, searchSize);
    search.layer.cornerRadius = 32.0;
    search.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.18];
    search.layer.borderWidth = 0.8;
    search.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.45].CGColor;
}

%hook UIViewController

- (void)viewDidLayoutSubviews {
    %orig;
    MMUpdateLayout(self);
}

%end
