#import <Foundation/Foundation.h>

%ctor {
    @autoreleasepool {
        NSLog(@"[TikTokLoadProbe] loaded in process %@", NSProcessInfo.processInfo.processName);
    }
}
