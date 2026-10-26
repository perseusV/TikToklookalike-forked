#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>

static const void *kPRPButtonKey = &kPRPButtonKey;
static const void *kPRPTargetKey = &kPRPTargetKey;
static const void *kPRPPickerDelegateKey = &kPRPPickerDelegateKey;

static BOOL PRPStringLooksLikeLive(NSString *value) {
    if (value.length == 0) return NO;
    NSString *s = value.lowercaseString;
    for (NSString *term in @[@"live", @"livestream", @"room", @"studio", @"broadcast", @"creatorlive", @"go live"]) {
        if ([s containsString:term]) return YES;
    }
    return NO;
}

static BOOL PRPViewContainsLiveText(UIView *view) {
    if ([view isKindOfClass:[UILabel class]] && PRPStringLooksLikeLive(((UILabel *)view).text)) return YES;
    if ([view isKindOfClass:[UIButton class]]) {
        NSString *title = [((UIButton *)view) titleForState:UIControlStateNormal];
        if (PRPStringLooksLikeLive(title)) return YES;
    }
    for (UIView *child in view.subviews) {
        if (PRPViewContainsLiveText(child)) return YES;
    }
    return NO;
}

static BOOL PRPIsLiveController(UIViewController *vc) {
    NSString *className = NSStringFromClass(vc.class);
    if (PRPStringLooksLikeLive(className)) return YES;
    if (PRPStringLooksLikeLive(vc.title)) return YES;
    if ([vc.navigationItem.title.lowercaseString containsString:@"live"]) return YES;
    return PRPViewContainsLiveText(vc.view);
}

static UIViewController *PRPVisibleController(UIViewController *vc) {
    if (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) {
        return PRPVisibleController(vc.presentedViewController);
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return PRPVisibleController(((UINavigationController *)vc).visibleViewController);
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        return PRPVisibleController(((UITabBarController *)vc).selectedViewController);
    }
    return vc;
}

@interface PRPPhotoPickerDelegate : NSObject <PHPickerViewControllerDelegate>
@property(nonatomic, copy) void (^completion)(NSURL *url, NSError *error);
@end

@implementation PRPPhotoPickerDelegate
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    PHPickerResult *result = results.firstObject;
    if (!result) {
        if (self.completion) self.completion(nil, [NSError errorWithDomain:@"PrerecordedLiveUI" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No video was selected."}]);
        return;
    }
    NSItemProvider *provider = result.itemProvider;
    if (![provider hasItemConformingToTypeIdentifier:@"public.movie"]) {
        if (self.completion) self.completion(nil, [NSError errorWithDomain:@"PrerecordedLiveUI" code:2 userInfo:@{NSLocalizedDescriptionKey: @"The selected asset is not a video."}]);
        return;
    }
    [provider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL *url, NSError *error) {
        if (error || !url) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.completion) self.completion(nil, error ?: [NSError errorWithDomain:@"PrerecordedLiveUI" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Could not read the selected video."}]);
            });
            return;
        }
        NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"PrerecordedLiveUI"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *path = [dir stringByAppendingPathComponent:@"selected-video.mov"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        NSError *copyError = nil;
        BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:path] error:&copyError];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(copied ? [NSURL fileURLWithPath:path] : nil, copied ? nil : copyError);
        });
    }];
}
@end

@interface PRPButtonTarget : NSObject
@property(nonatomic, weak) UIViewController *viewController;
- (void)chooseVideo:(UIButton *)sender;
- (void)dragButton:(UIPanGestureRecognizer *)gesture;
@end

@implementation PRPButtonTarget
- (void)chooseVideo:(UIButton *)sender {
    UIViewController *vc = self.viewController;
    if (!vc) return;
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
    configuration.filter = [PHPickerFilter videosFilter];
    configuration.selectionLimit = 1;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    PRPPhotoPickerDelegate *delegate = [PRPPhotoPickerDelegate new];
    delegate.completion = ^(NSURL *url, NSError *error) {
        if (error || !url) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Prerecorded Video" message:error.localizedDescription ?: @"No video selected." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [vc presentViewController:alert animated:YES completion:nil];
            return;
        }
        NSLog(@"[PrerecordedLiveUI] selected video cached at %@", url.path);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Video Selected" message:@"Saved for the prerecorded broadcast integration. TikTok is still using its normal live source until that integration is enabled." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:alert animated:YES completion:nil];
    };
    objc_setAssociatedObject(picker, kPRPPickerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    picker.delegate = delegate;
    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)dragButton:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    UIViewController *vc = self.viewController;
    if (!view || !vc) return;
    CGPoint translation = [gesture translationInView:vc.view];
    view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:vc.view];

    CGFloat margin = 8.0;
    UIEdgeInsets safe = vc.view.safeAreaInsets;
    CGFloat minX = safe.left + margin + view.bounds.size.width / 2.0;
    CGFloat maxX = vc.view.bounds.size.width - safe.right - margin - view.bounds.size.width / 2.0;
    CGFloat minY = safe.top + margin + view.bounds.size.height / 2.0;
    CGFloat maxY = vc.view.bounds.size.height - safe.bottom - margin - view.bounds.size.height / 2.0;
    view.center = CGPointMake(MIN(MAX(view.center.x, minX), maxX), MIN(MAX(view.center.y, minY), maxY));

    if (gesture.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromCGPoint(view.center) forKey:@"PrerecordedLiveUI.buttonCenter"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
@end

static void PRPInstallButton(UIViewController *vc) {
    if (!vc.viewIfLoaded || !PRPIsLiveController(vc)) return;
    if (objc_getAssociatedObject(vc, kPRPButtonKey)) return;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.accessibilityIdentifier = @"PrerecordedLiveUI.button";
    if (@available(iOS 13.0, *)) [button setImage:[UIImage systemImageNamed:@"video.fill"] forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithRed:0.85 green:0.05 blue:0.25 alpha:0.95];
    button.frame = CGRectMake(0, 0, 48, 48);
    button.layer.cornerRadius = 24.0;
    button.layer.masksToBounds = YES;
    button.accessibilityLabel = @"Choose prerecorded video";
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.baseBackgroundColor = [UIColor colorWithRed:0.85 green:0.05 blue:0.25 alpha:0.95];
        configuration.baseForegroundColor = UIColor.whiteColor;
        button.configuration = configuration;
    }
    PRPButtonTarget *target = [PRPButtonTarget new];
    target.viewController = vc;
    [button addTarget:target action:@selector(chooseVideo:) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(dragButton:)];
    [button addGestureRecognizer:pan];
    [vc.view addSubview:button];
    CGPoint defaultCenter = CGPointMake(vc.view.bounds.size.width - vc.view.safeAreaInsets.right - 40.0,
                                        vc.view.safeAreaInsets.top + 40.0);
    NSString *savedCenter = [[NSUserDefaults standardUserDefaults] stringForKey:@"PrerecordedLiveUI.buttonCenter"];
    CGPoint center = savedCenter.length ? CGPointFromString(savedCenter) : defaultCenter;
    button.center = center;
    objc_setAssociatedObject(vc, kPRPButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, kPRPTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[PrerecordedLiveUI] installed button on %@", NSStringFromClass(vc.class));
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *visible = PRPVisibleController(self);
        PRPInstallButton(visible);
    });
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (PRPIsLiveController(self) && !objc_getAssociatedObject(self, kPRPButtonKey)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            PRPInstallButton(self);
        });
    }
}
%end

%ctor {
    @autoreleasepool {
        NSLog(@"[PrerecordedLiveUI] loaded in %@", NSProcessInfo.processInfo.processName);
    }
}
