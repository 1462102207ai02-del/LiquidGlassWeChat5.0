// Settings.m
#import <Foundation/Foundation.h>

static CGFloat kBackgroundOpacity = 0.18; // 默认底栏透明度
static CGFloat kCapsuleOpacity = 0.35;   // 默认胶囊透明度

// 加载设置
void loadOpacitySettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 读取保存的透明度设置
    CGFloat backgroundOpacity = [defaults floatForKey:@"backgroundOpacity"];
    if (backgroundOpacity >= 0.0 && backgroundOpacity <= 1.0) {
        kBackgroundOpacity = backgroundOpacity;
    }

    CGFloat capsuleOpacity = [defaults floatForKey:@"capsuleOpacity"];
    if (capsuleOpacity >= 0.0 && capsuleOpacity <= 1.0) {
        kCapsuleOpacity = capsuleOpacity;
    }
}

// 保存设置
void saveOpacitySettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 保存透明度设置
    [defaults setFloat:kBackgroundOpacity forKey:@"backgroundOpacity"];
    [defaults setFloat:kCapsuleOpacity forKey:@"capsuleOpacity"];
    [defaults synchronize];
}

// 获取当前的透明度值
CGFloat getBackgroundOpacity() {
    return kBackgroundOpacity;
}

CGFloat getCapsuleOpacity() {
    return kCapsuleOpacity;
}
