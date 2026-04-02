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
        CGFloat ax = CGRectGetMinX(a.frame);
        CGFloat bx = CGRectGetMinX(b.frame);
        if (ax < bx) return NSOrderedAscending;
        if (ax > bx) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    objc_setAssociatedObject(tabBar, kMMStoredItemViewsKey, arr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return arr;
}

static CGRect MMSlot(UIView *host, NSInteger i, NSInteger count) {
    CGFloat side = 10.0;
    CGFloat w = (host.bounds.size.width - side * 2.0) / count;
    CGFloat h = host.bounds.size.height;
    return CGRectMake(side + w * i, 0.0, w, h);
}

static void MMLayout(UITabBar *tabBar, UIView *host) {
    NSArray *items = MMItemViews(tabBar);
    NSInteger count = items.count;
    if (count == 0) return;

    NSInteger selected = tabBar.selectedItem ? [tabBar.items indexOfObject:tabBar.selectedItem] : 0;
    if (selected < 0 || selected >= count) selected = 0;

    UIView *capsule = [host viewWithTag:kMMCapsuleTag];
    if (!capsule) {
        capsule = [UIView new];
        capsule.tag = kMMCapsuleTag;
        [host addSubview:capsule];
    }

    CGRect selFrame = MMSlot(host, selected, count);
    capsule.frame = CGRectInset(selFrame, 6.0, 8.0);
    MMSetRadius(capsule, capsule.bounds.size.height / 2.0);

    for (NSInteger i = 0; i < count; i++) {
        UIView *item = items[i];
        CGRect slot = MMSlot(host, i, count);
        item.transform = CGAffineTransformIdentity;
        item.frame = slot;
        item.center = CGPointMake(CGRectGetMidX(slot), CGRectGetMidY(slot));
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

    host.frame = CGRectMake(16.0, self.superview.bounds.size.height - 90.0, self.superview.bounds.size.width - 32.0, 64.0);
    MMSetRadius(host, 32.0);

    self.hidden = YES;

    MMLayout(self, host);
}

%end
