#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <ReplayKit/ReplayKit.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>

static const void *kPRPButtonKey = &kPRPButtonKey;
static const void *kPRPTargetKey = &kPRPTargetKey;
static const void *kPRPPickerDelegateKey = &kPRPPickerDelegateKey;
static const void *kPRPWindowButtonKey = &kPRPWindowButtonKey;

static NSString *PRPSharedVideoPath(void) {
    return @"/var/mobile/Media/PrerecordedLiveUI/selected-video.mov";
}

static NSString *PRPPrivateVideoPath(void) {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"PrerecordedLiveUI"];
    return [dir stringByAppendingPathComponent:@"selected-video.mov"];
}

static NSString * const kPRPScaleModeKey = @"PrerecordedLiveUI.scaleMode";
static NSString * const kPRPLoopKey = @"PrerecordedLiveUI.loop";
static NSString * const kPRPVolumeKey = @"PrerecordedLiveUI.volume";

static NSString *PRPScaleMode(void) {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:kPRPScaleModeKey];
    return mode.length ? mode : @"fit";
}

static BOOL PRPLoopEnabled(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:kPRPLoopKey] ? [defaults boolForKey:kPRPLoopKey] : YES;
}

static float PRPVolume(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:kPRPVolumeKey] ? MAX(0.0f, MIN(2.0f, [defaults floatForKey:kPRPVolumeKey])) : 1.0f;
}

static BOOL PRPStoreVideoData(NSData *data, NSURL **resultURL, NSError **resultError) {
    if (data.length == 0) {
        if (resultError) *resultError = [NSError errorWithDomain:@"PrerecordedLiveUI" code:4 userInfo:@{NSLocalizedDescriptionKey: @"The selected video provider returned no data."}];
        return NO;
    }
    NSString *privatePath = PRPPrivateVideoPath();
    NSString *privateDir = [privatePath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:privateDir withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:privatePath error:nil];
    NSError *error = nil;
    if (![data writeToFile:privatePath options:NSDataWritingAtomic error:&error]) {
        if (resultError) *resultError = error;
        return NO;
    }
    NSString *sharedPath = PRPSharedVideoPath();
    NSString *sharedDir = [sharedPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:sharedDir withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:sharedPath error:nil];
    if (![[NSFileManager defaultManager] copyItemAtPath:privatePath toPath:sharedPath error:&error]) {
        if (resultError) *resultError = error;
        return NO;
    }
    if (resultURL) *resultURL = [NSURL fileURLWithPath:privatePath];
    return YES;
}

static BOOL PRPStoreVideoFile(NSURL *sourceURL, NSURL **resultURL, NSError **resultError) {
    NSString *privatePath = PRPPrivateVideoPath();
    NSString *privateDir = [privatePath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:privateDir withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:privatePath error:nil];
    NSError *error = nil;
    BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:privatePath] error:&error];
    if (!copied) {
        NSData *fallbackData = [NSData dataWithContentsOfURL:sourceURL options:0 error:&error];
        if (fallbackData) return PRPStoreVideoData(fallbackData, resultURL, resultError);
        if (resultError) *resultError = error;
        return NO;
    }
    NSData *data = [NSData dataWithContentsOfFile:privatePath options:0 error:&error];
    if (!data || data.length == 0) {
        if (resultError) *resultError = error ?: [NSError errorWithDomain:@"PrerecordedLiveUI" code:5 userInfo:@{NSLocalizedDescriptionKey: @"The copied video is empty."}];
        return NO;
    }
    BOOL stored = PRPStoreVideoData(data, resultURL, resultError);
    return stored;
}

@interface PRPAssetPump : NSObject
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) AVAssetReader *reader;
@property(nonatomic, strong) AVAssetReaderTrackOutput *videoOutput;
@property(nonatomic, strong) AVAssetReaderOutput *audioOutput;
- (BOOL)startWithURL:(NSURL *)url;
- (CMSampleBufferRef)nextVideoBufferForTime:(CMTime)time;
- (CMSampleBufferRef)nextAudioBufferForTime:(CMTime)time;
@end

@implementation PRPAssetPump

- (BOOL)startWithURL:(NSURL *)url {
    self.url = url;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if (videoTracks.count == 0) {
        NSLog(@"[PrerecordedLiveUI] asset has no video track: %@", url.path);
        return NO;
    }
    NSError *error = nil;
    self.reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (!self.reader || error) {
        NSLog(@"[PrerecordedLiveUI] AVAssetReader init failed: %@", error);
        return NO;
    }
    NSString *scalingMode = PRPScaleMode();
    NSString *avScalingMode = [scalingMode isEqualToString:@"fill"] ? AVVideoScalingModeResizeAspectFill : ([scalingMode isEqualToString:@"stretch"] ? AVVideoScalingModeResize : AVVideoScalingModeResizeAspect);
    NSDictionary *videoSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        AVVideoScalingModeKey: avScalingMode,
        AVVideoWidthKey: @1280,
        AVVideoHeightKey: @720
    };
    self.videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTracks.firstObject outputSettings:videoSettings];
    self.videoOutput.alwaysCopiesSampleData = NO;
    if ([self.reader canAddOutput:self.videoOutput]) [self.reader addOutput:self.videoOutput];
    if (audioTracks.count > 0) {
        NSDictionary *audioSettings = @{
            AVFormatIDKey: @(kAudioFormatLinearPCM),
            AVLinearPCMIsFloatKey: @NO,
            AVLinearPCMBitDepthKey: @16,
            AVLinearPCMIsBigEndianKey: @NO,
            AVLinearPCMIsNonInterleaved: @NO,
            AVSampleRateKey: @44100,
            AVNumberOfChannelsKey: @2
        };
        AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
        AVMutableAudioMixInputParameters *audioParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTracks.firstObject];
        [audioParameters setVolume:PRPVolume() atTime:kCMTimeZero];
        audioMix.inputParameters = @[audioParameters];
        AVAssetReaderAudioMixOutput *audioOutput = [[AVAssetReaderAudioMixOutput alloc] initWithAudioTracks:audioTracks audioSettings:audioSettings];
        audioOutput.audioMix = audioMix;
        self.audioOutput = audioOutput;
        self.audioOutput.alwaysCopiesSampleData = NO;
        if ([self.reader canAddOutput:self.audioOutput]) [self.reader addOutput:self.audioOutput];
    }
    BOOL started = [self.reader startReading];
    NSLog(@"[PrerecordedLiveUI] asset pump %@ video=%d audio=%d scale=%@ loop=%d volume=%.2f", started ? @"started" : @"failed", self.videoOutput != nil, self.audioOutput != nil, scalingMode, PRPLoopEnabled(), PRPVolume());
    return started;
}

- (CMSampleBufferRef)copyBuffer:(CMSampleBufferRef)source forTime:(CMTime)time {
    if (!source) return NULL;
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    if (CMSampleBufferGetSampleTimingInfo(source, 0, &timing) != noErr) return (CMSampleBufferRef)CFRetain(source);
    timing.presentationTimeStamp = time;
    timing.decodeTimeStamp = kCMTimeInvalid;
    CMSampleBufferRef adjusted = NULL;
    OSStatus status = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, source, 1, &timing, &adjusted);
    return status == noErr ? adjusted : (CMSampleBufferRef)CFRetain(source);
}

- (CMSampleBufferRef)nextFromOutput:(AVAssetReaderOutput *)output forTime:(CMTime)time {
    if (!output) return NULL;
    CMSampleBufferRef source = [output copyNextSampleBuffer];
    if (!source && PRPLoopEnabled() && self.reader.status == AVAssetReaderStatusCompleted) {
        if ([self startWithURL:self.url]) source = [output copyNextSampleBuffer];
    }
    CMSampleBufferRef adjusted = [self copyBuffer:source forTime:time];
    if (source) CFRelease(source);
    return adjusted;
}

- (CMSampleBufferRef)nextVideoBufferForTime:(CMTime)time {
    return [self nextFromOutput:self.videoOutput forTime:time];
}

- (CMSampleBufferRef)nextAudioBufferForTime:(CMTime)time {
    return [self nextFromOutput:self.audioOutput forTime:time];
}
@end

static PRPAssetPump *gPRPAssetPump;

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
            NSLog(@"[PrerecordedLiveUI] file representation failed, trying data representation: %@", error);
            [provider loadDataRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSData *data, NSError *dataError) {
                NSURL *storedURL = nil;
                NSError *storeError = dataError;
                BOOL stored = data && PRPStoreVideoData(data, &storedURL, &storeError);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.completion) self.completion(stored ? storedURL : nil, stored ? nil : (storeError ?: error));
                });
            }];
            return;
        }
        NSURL *storedURL = nil;
        NSError *storeError = nil;
        BOOL stored = PRPStoreVideoFile(url, &storedURL, &storeError);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(stored ? storedURL : nil, stored ? nil : storeError);
        });
    }];
}
@end

@interface PRPButtonTarget : NSObject
@property(nonatomic, weak) UIViewController *viewController;
- (void)chooseVideo:(UIButton *)sender;
- (void)dragButton:(UIPanGestureRecognizer *)gesture;
- (void)showSettings:(UILongPressGestureRecognizer *)gesture;
- (void)showSettingsForButton:(UIButton *)sender;
@end

@implementation PRPButtonTarget
- (void)showSettings:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || !self.viewController) return;
    [self showSettingsForButton:(UIButton *)gesture.view];
}

- (void)showSettingsForButton:(UIButton *)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = self.viewController;
        if (!vc) return;
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Prerecorded Stream Settings" message:[NSString stringWithFormat:@"Scaling: %@\nLoop: %@\nVolume: %.0f%%", PRPScaleMode().capitalizedString, PRPLoopEnabled() ? @"On" : @"Off", PRPVolume() * 100.0f] preferredStyle:UIAlertControllerStyleActionSheet];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Scaling: change" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSArray *modes = @[@"fit", @"fill", @"stretch"];
            NSUInteger index = [modes indexOfObject:PRPScaleMode()];
            [[NSUserDefaults standardUserDefaults] setObject:modes[(index == NSNotFound ? 0 : (index + 1) % modes.count)] forKey:kPRPScaleModeKey];
            [self showSettingsForButton:sender];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:PRPLoopEnabled() ? @"Loop: turn off" : @"Loop: turn on" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setBool:!PRPLoopEnabled() forKey:kPRPLoopKey];
            [self showSettingsForButton:sender];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Volume: change" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            float next = PRPVolume() + 0.5f;
            if (next > 2.0f) next = 0.0f;
            [[NSUserDefaults standardUserDefaults] setFloat:next forKey:kPRPVolumeKey];
            [self showSettingsForButton:sender];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
        if (sheet.popoverPresentationController) {
            sheet.popoverPresentationController.sourceView = sender;
            sheet.popoverPresentationController.sourceRect = sender.bounds;
        }
        [vc presentViewController:sheet animated:YES completion:nil];
    });
}

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
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Video Selected" message:@"Saved for the prerecorded broadcast. Long-press the floating icon for scaling, loop, and volume settings. Settings apply when the next broadcast starts." preferredStyle:UIAlertControllerStyleAlert];
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

static UIButton *PRPFindFloatingButton(UIView *view) {
    if ([view isKindOfClass:[UIButton class]] && [((UIButton *)view).accessibilityIdentifier isEqualToString:@"PrerecordedLiveUI.button"]) {
        return (UIButton *)view;
    }
    for (UIView *child in view.subviews) {
        UIButton *found = PRPFindFloatingButton(child);
        if (found) return found;
    }
    return nil;
}

static void PRPInstallButton(UIViewController *vc) {
    if (!vc.viewIfLoaded || !PRPIsLiveController(vc)) return;
    if (objc_getAssociatedObject(vc, kPRPButtonKey)) return;
    UIWindow *window = vc.view.window;
    UIButton *existing = window ? (UIButton *)objc_getAssociatedObject(window, kPRPWindowButtonKey) : nil;
    if (!existing && window) existing = PRPFindFloatingButton(window);
    if (existing) {
        PRPButtonTarget *existingTarget = objc_getAssociatedObject(existing, kPRPTargetKey);
        if (existingTarget) {
            existingTarget.viewController = vc;
            objc_setAssociatedObject(vc, kPRPButtonKey, existing, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(window, kPRPWindowButtonKey, existing, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
        [existing removeFromSuperview];
    }
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
    UILongPressGestureRecognizer *settings = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:@selector(showSettings:)];
    settings.minimumPressDuration = 0.65;
    [button addGestureRecognizer:settings];
    [vc.view addSubview:button];
    CGPoint defaultCenter = CGPointMake(vc.view.bounds.size.width - vc.view.safeAreaInsets.right - 40.0,
                                        vc.view.safeAreaInsets.top + 40.0);
    NSString *savedCenter = [[NSUserDefaults standardUserDefaults] stringForKey:@"PrerecordedLiveUI.buttonCenter"];
    CGPoint center = savedCenter.length ? CGPointFromString(savedCenter) : defaultCenter;
    button.center = center;
    objc_setAssociatedObject(vc, kPRPButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(vc, kPRPTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, kPRPTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (window) objc_setAssociatedObject(window, kPRPWindowButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[PrerecordedLiveUI] installed button on %@", NSStringFromClass(vc.class));
}

%hook SampleHandler

- (void)broadcastStartedWithSetupInfo:(NSDictionary *)setupInfo {
    %orig;
    @synchronized ([PRPAssetPump class]) {
        NSURL *url = [NSURL fileURLWithPath:PRPSharedVideoPath()];
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            gPRPAssetPump = [PRPAssetPump new];
            if (![gPRPAssetPump startWithURL:url]) gPRPAssetPump = nil;
        } else {
            NSLog(@"[PrerecordedLiveUI] broadcast started but shared video is missing: %@", url.path);
        }
    }
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    PRPAssetPump *pump = gPRPAssetPump;
    if (pump && sampleBufferType == RPSampleBufferTypeVideo) {
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMSampleBufferRef replacement = [pump nextVideoBufferForTime:pts];
        if (replacement) {
            NSLog(@"[PrerecordedLiveUI] replacing video sample at %lld/%d", pts.value, pts.timescale);
            %orig(replacement, sampleBufferType);
            CFRelease(replacement);
            return;
        }
    } else if (pump && sampleBufferType == RPSampleBufferTypeAudioApp) {
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMSampleBufferRef replacement = [pump nextAudioBufferForTime:pts];
        if (replacement) {
            NSLog(@"[PrerecordedLiveUI] replacing app audio sample at %lld/%d", pts.value, pts.timescale);
            %orig(replacement, sampleBufferType);
            CFRelease(replacement);
            return;
        }
    }
    %orig(sampleBuffer, sampleBufferType);
}

- (void)broadcastFinished {
    NSLog(@"[PrerecordedLiveUI] broadcast finished");
    gPRPAssetPump = nil;
    %orig;
}

%end

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
