#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook MMTabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *test = @"HOOK_OK";
        [test writeToFile:@"/var/mobile/test.log"
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:nil];
    });
}

%end
