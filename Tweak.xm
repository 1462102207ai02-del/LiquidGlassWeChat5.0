#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static NSInteger const kMMGlassHostTag = 990001;
static NSInteger const kMMButtonsContainerTag = 990003;
static NSInteger const kMMCapsuleTag = 990005;

static const void *kMMStoredItemViewsKey = &kMMStoredItemViewsKey;

static void MMSetRadius(UIView *view, CGFloat radius) {
    view.layer.cornerRadius = radius;
    if ([view.layer respondsToSelector:@selector(setCornerCurve:)]) {
        view.layer.cornerCurve = kCACornerCurveContinuous;
    }
}

static NSArray<UIView *> *MMItemViews(UITabBar *tabBar) {
    NSArray *stored = objc_getAssociatedObject(tabBar, kMMStoredItemViewsKey);
    if (stored) return stored;

    NSMutableArray *arr = [NSMutableArray array];
    for (UIView *v in tabBar.subviews) {
        if ([NSStringFromClass(v.class) containsString:@"Item"]) {
            [arr addObject:v];
        }
    }
    [arr sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.frame.origin.x > b.frame.origin.x;
    }];
    objc_setAssociatedObject(tabBar, kMMStoredItemViewsKey, arr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return arr;
}

static CGRect MMSlot(UIView *host, NSInteger i, NSInteger count) {
    CGFloat side = 10.0;
    CGFloat w = (host.bounds.size.width - side * 2) / count;
    CGFloat h = host.bounds.size.height;
    return CGRectMake(side + w * i, 0, w, h);
}

static void MMLayout(UITabBar *tabBar, UIView *host) {
    NSArray *items = MMItemViews(tabBar);
    NSInteger count = items.count;
    if (count == 0) return;

    NSInteger selected = tabBar.selectedItem ? [tabBar.items indexOfObject:tabBar.selectedItem] : 0;

    UIView *capsule = [host viewWithTag:kMMCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        [host addSubview:capsule];
    }

    CGRect selFrame = MMSlot(host, selected, count);
    capsule.frame = CGRectInset(selFrame, 6, 8);
    MMSetRadius(capsule, capsule.bounds.size.height / 2);

    for (NSInteger i = 0; i < count; i++) {
        UIView *item = items[i];
        CGRect slot = MMSlot(host, i, count);

        CGFloat w = slot.size.width;
        CGFloat h = slot.size.height;

        item.frame = CGRectMake(slot.origin.x, slot.origin.y, w, h);
        item.center = CGPointMake(CGRectGetMidX(slot), CGRectGetMidY(slot));
        item.transform = CGAffineTransformIdentity;
    }
}

%hook UITabBar

- (void)layoutSubviews {
    %orig;

    UIView *host = [self.superview viewWithTag:kMMGlassHostTag];
    if (!host) {
        host = [UIView new];
        host.tag = kMMGlassHostTag;
        [self.superview addSubview:host];
    }

    host.frame = CGRectMake(16, self.superview.bounds.size.height - 90, self.superview.bounds.size.width - 32, 64);
    MMSetRadius(host, 32);

    self.hidden = YES;

    MMLayout(self, host);
}

%end
