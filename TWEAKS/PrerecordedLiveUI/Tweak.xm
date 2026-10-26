#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <ReplayKit/ReplayKit.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>
#include <stdarg.h>

static const void *kPRPButtonKey = &kPRPButtonKey;
static const void *kPRPTargetKey = &kPRPTargetKey;
static const void *kPRPPickerDelegateKey = &kPRPPickerDelegateKey;
static const void *kPRPWindowButtonKey = &kPRPWindowButtonKey;
static BOOL gPRPCameraPipelineActive = NO;
static void PRPInstallButton(UIViewController *vc);

static NSString *PRPSharedVideoPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/TikTokFakeLiveCam/selected.mov"];
}

static NSString *PRPPrivateVideoPath(void) {
    return PRPSharedVideoPath();
}

static NSString *PRPDebugLogPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/TikTokFakeLiveCam/diagnostic.log"];
}

static void PRPDebugLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
    NSLog(@"[PrerecordedLiveUI] %@", message);
    NSString *path = PRPDebugLogPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) {
        [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [handle seekToEndOfFile];
        [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    }
}

static NSString * const kPRPScaleModeKey = @"PrerecordedLiveUI.scaleMode";
static NSString * const kPRPLoopKey = @"PrerecordedLiveUI.loop";
static NSString * const kPRPVolumeKey = @"PrerecordedLiveUI.volume";
static NSString * const kPRPPipelineEnabledKey = @"PrerecordedLiveUI.pipelineEnabled";

static BOOL PRPPipelineEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPRPPipelineEnabledKey];
}

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
    if (![privatePath isEqualToString:sharedPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:sharedPath error:nil];
        if (![[NSFileManager defaultManager] copyItemAtPath:privatePath toPath:sharedPath error:&error]) {
            if (resultError) *resultError = error;
            return NO;
        }
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

static NSString *PRPSharedAudioPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/TikTokFakeLiveCam/selected-audio.m4a"];
}

static BOOL PRPStoreAudioFile(NSURL *sourceURL, NSURL **resultURL, NSError **resultError) {
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"PrerecordedLiveUI"];
    NSString *privatePath = [dir stringByAppendingPathComponent:@"selected-audio.m4a"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:privatePath error:nil];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:[NSURL fileURLWithPath:privatePath] error:&error]) {
        if (resultError) *resultError = error;
        return NO;
    }
    NSString *sharedPath = PRPSharedAudioPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:[sharedPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:sharedPath error:nil];
    if (![[NSFileManager defaultManager] copyItemAtPath:privatePath toPath:sharedPath error:&error]) {
        if (resultError) *resultError = error;
        return NO;
    }
    if (resultURL) *resultURL = [NSURL fileURLWithPath:privatePath];
    return YES;
}

@interface PRPAssetPump : NSObject
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) NSURL *audioURL;
@property(nonatomic, strong) AVAssetReader *reader;
@property(nonatomic, strong) AVAssetReaderTrackOutput *videoOutput;
@property(nonatomic, strong) AVAssetReaderOutput *audioOutput;
- (BOOL)startWithURL:(NSURL *)url audioURL:(NSURL *)audioURL;
- (BOOL)startWithURL:(NSURL *)url audioURL:(NSURL *)audioURL targetWidth:(size_t)width targetHeight:(size_t)height pixelFormat:(OSType)pixelFormat;
- (CMSampleBufferRef)nextVideoBufferForTime:(CMTime)time;
- (CMSampleBufferRef)nextAudioBufferForTime:(CMTime)time;
@end

@implementation PRPAssetPump

- (BOOL)startWithURL:(NSURL *)url audioURL:(NSURL *)audioURL {
    return [self startWithURL:url audioURL:audioURL targetWidth:1280 targetHeight:720 pixelFormat:kCVPixelFormatType_32BGRA];
}

- (BOOL)startWithURL:(NSURL *)url audioURL:(NSURL *)audioURL targetWidth:(size_t)width targetHeight:(size_t)height pixelFormat:(OSType)pixelFormat {
    self.url = url;
    self.audioURL = audioURL;
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAsset *asset = videoAsset;
    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (audioURL && [[NSFileManager defaultManager] fileExistsAtPath:audioURL.path]) {
        AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
        AVAssetTrack *musicTrack = [audioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (videoTrack && musicTrack) {
            AVMutableComposition *composition = [AVMutableComposition composition];
            AVMutableCompositionTrack *videoCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            AVMutableCompositionTrack *audioCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [videoCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:videoTrack atTime:kCMTimeZero error:nil];
            [audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) ofTrack:musicTrack atTime:kCMTimeZero error:nil];
            asset = composition;
            PRPDebugLog(@"using selected music track %@", audioURL.path);
        }
    }
    NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    if (videoTracks.count == 0) {
        PRPDebugLog(@"asset has no video track: %@", url.path);
        return NO;
    }
    NSError *error = nil;
    self.reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (!self.reader || error) {
        PRPDebugLog(@"AVAssetReader init failed: %@", error);
        return NO;
    }
    NSString *scalingMode = PRPScaleMode();
    NSString *avScalingMode = [scalingMode isEqualToString:@"fill"] ? AVVideoScalingModeResizeAspectFill : ([scalingMode isEqualToString:@"stretch"] ? AVVideoScalingModeResize : AVVideoScalingModeResizeAspect);
    NSDictionary *videoSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(pixelFormat),
        AVVideoScalingModeKey: avScalingMode,
        (id)kCVPixelBufferWidthKey: @(width),
        (id)kCVPixelBufferHeightKey: @(height),
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
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
    PRPDebugLog(@"asset pump %@ video=%d audio=%d scale=%@ loop=%d volume=%.2f", started ? @"started" : @"failed", self.videoOutput != nil, self.audioOutput != nil, scalingMode, PRPVolume());
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
        if ([self startWithURL:self.url audioURL:self.audioURL]) source = [output copyNextSampleBuffer];
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

static const void *kPRPCaptureProxyKey = &kPRPCaptureProxyKey;

@interface PRPCaptureDelegateProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property(nonatomic, strong) id<AVCaptureVideoDataOutputSampleBufferDelegate> originalDelegate;
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) PRPAssetPump *pump;
@property(nonatomic, assign) size_t targetWidth;
@property(nonatomic, assign) size_t targetHeight;
@property(nonatomic, assign) OSType targetPixelFormat;
@end

@implementation PRPCaptureDelegateProxy
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate = self.originalDelegate;
    if (!delegate) return;
    if (!self.pump) {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (pixelBuffer) {
            size_t width = CVPixelBufferGetWidth(pixelBuffer);
            size_t height = CVPixelBufferGetHeight(pixelBuffer);
            OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
            NSURL *url = [NSURL fileURLWithPath:PRPSharedVideoPath()];
            NSURL *audioURL = [NSURL fileURLWithPath:PRPSharedAudioPath()];
            if (![[NSFileManager defaultManager] fileExistsAtPath:audioURL.path]) audioURL = nil;
            if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
                self.targetWidth = width;
                self.targetHeight = height;
                self.targetPixelFormat = format;
                self.pump = [PRPAssetPump new];
                if (![self.pump startWithURL:url audioURL:audioURL targetWidth:width targetHeight:height pixelFormat:format]) self.pump = nil;
                else PRPDebugLog(@"camera delegate source active target=%zux%zu fourcc=%u", width, height, format);
            } else {
                PRPDebugLog(@"camera delegate source missing at %@", url.path);
            }
        }
    }
    CMSampleBufferRef replacement = self.pump ? [self.pump nextVideoBufferForTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)] : NULL;
    if (replacement) {
        CVPixelBufferRef replacementPixelBuffer = CMSampleBufferGetImageBuffer(replacement);
        BOOL compatible = replacementPixelBuffer && CVPixelBufferGetWidth(replacementPixelBuffer) == self.targetWidth && CVPixelBufferGetHeight(replacementPixelBuffer) == self.targetHeight && CVPixelBufferGetPixelFormatType(replacementPixelBuffer) == self.targetPixelFormat;
        if (!compatible) {
            PRPDebugLog(@"rejected incompatible replacement frame");
            CFRelease(replacement);
            [delegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
            return;
        }
        static NSUInteger sampleCount = 0;
        sampleCount++;
        if ((sampleCount % 30) == 0) PRPDebugLog(@"AVCapture replacement sample #%lu", (unsigned long)sampleCount);
        [delegate captureOutput:output didOutputSampleBuffer:replacement fromConnection:connection];
        CFRelease(replacement);
    } else {
        [delegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate = self.originalDelegate;
    if ([delegate respondsToSelector:@selector(captureOutput:didDropSampleBuffer:fromConnection:)]) [delegate captureOutput:output didDropSampleBuffer:sampleBuffer fromConnection:connection];
}

- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [self.originalDelegate respondsToSelector:selector];
}
@end

static BOOL PRPStringLooksLikeLive(NSString *value) {
    if (value.length == 0) return NO;
    NSString *s = value.lowercaseString;
    for (NSString *term in @[@"live", @"livestream", @"room", @"studio", @"broadcast", @"creatorlive", @"go live"]) {
        if ([s containsString:term]) return YES;
    }
    return NO;
}

static BOOL PRPIsLiveController(UIViewController *vc) {
    NSString *className = NSStringFromClass(vc.class);
    if (PRPStringLooksLikeLive(className)) return YES;
    if (PRPStringLooksLikeLive(vc.title)) return YES;
    if ([vc.navigationItem.title.lowercaseString containsString:@"live"]) return YES;
    return NO;
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
    [[NSFileManager defaultManager] removeItemAtPath:PRPSharedVideoPath() error:nil];
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

@interface PRPDocumentPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic, weak) UIViewController *viewController;
@end

@implementation PRPDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *sourceURL = urls.firstObject;
    if (!sourceURL) return;
    BOOL accessed = [sourceURL startAccessingSecurityScopedResource];
    NSError *error = nil;
    NSURL *storedURL = nil;
    BOOL stored = PRPStoreVideoFile(sourceURL, &storedURL, &error);
    if (accessed) [sourceURL stopAccessingSecurityScopedResource];
    AVURLAsset *asset = storedURL ? [AVURLAsset URLAssetWithURL:storedURL options:nil] : nil;
    if (stored && [asset tracksWithMediaType:AVMediaTypeVideo].count == 0) {
        stored = NO;
        error = [NSError errorWithDomain:@"PrerecordedLiveUI" code:11 userInfo:@{NSLocalizedDescriptionKey: @"The selected file has no iOS-decodable video track."}];
        [[NSFileManager defaultManager] removeItemAtPath:PRPSharedVideoPath() error:nil];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:stored ? @"Video Selected" : @"Video Error" message:stored ? @"The file was saved. Restart LIVE after enabling the pipeline." : (error.localizedDescription ?: @"The video could not be imported.") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self.viewController presentViewController:alert animated:YES completion:nil];
}
@end

@interface PRPPreviewController : AVPlayerViewController
@end

@implementation PRPPreviewController
- (void)viewDidLoad {
    [super viewDidLoad];
    NSURL *url = [NSURL fileURLWithPath:PRPPrivateVideoPath()];
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return;
    self.player = [AVPlayer playerWithURL:url];
    if ([PRPScaleMode() isEqualToString:@"fill"]) self.videoGravity = AVLayerVideoGravityResizeAspectFill;
    else if ([PRPScaleMode() isEqualToString:@"stretch"]) self.videoGravity = AVLayerVideoGravityResize;
    else self.videoGravity = AVLayerVideoGravityResizeAspect;
    self.title = [NSString stringWithFormat:@"Preview — %@", PRPScaleMode().capitalizedString];
    [self.player play];
}
@end

@interface PRPDebugViewController : UIViewController
@end

@implementation PRPDebugViewController {
    UITextView *_textView;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"Prerecorded Debug";
    _textView = [[UITextView alloc] initWithFrame:CGRectZero];
    _textView.editable = NO;
    _textView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    _textView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_textView];
    [NSLayoutConstraint activateConstraints:@[
        [_textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [_textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [_textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [_textView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8]
    ]];
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshLog)];
    UIBarButtonItem *clear = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(clearLog)];
    self.navigationItem.rightBarButtonItems = @[refresh, clear];
    [self refreshLog];
}
- (void)refreshLog {
    NSString *text = [NSString stringWithContentsOfFile:PRPDebugLogPath() encoding:NSUTF8StringEncoding error:nil];
    _textView.text = text.length ? text : @"No diagnostic entries yet. Start the LIVE camera after opening this screen.";
    if (_textView.text.length) [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length - 1, 1)];
}
- (void)clearLog {
    [[NSFileManager defaultManager] removeItemAtPath:PRPDebugLogPath() error:nil];
    [self refreshLog];
}
@end

@interface PRPMediaPickerDelegate : NSObject <MPMediaPickerControllerDelegate>
@property(nonatomic, weak) UIViewController *viewController;
@end

@implementation PRPMediaPickerDelegate
- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(NSArray<MPMediaItem *> *)mediaItemCollection {
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
    MPMediaItem *item = mediaItemCollection.firstObject;
    NSURL *assetURL = item.assetURL;
    if (!assetURL) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Audio Track" message:@"This music item cannot be exported. Apple Music DRM or a cloud-only item may not provide a local asset URL." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self.viewController presentViewController:alert animated:YES completion:nil];
        return;
    }
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"prerecorded-audio-%@.m4a", NSUUID.UUID.UUIDString]];
    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    exporter.outputURL = [NSURL fileURLWithPath:outputPath];
    exporter.outputFileType = AVFileTypeAppleM4A;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = exporter.error;
            NSURL *storedURL = nil;
            BOOL stored = exporter.status == AVAssetExportSessionStatusCompleted && PRPStoreAudioFile(exporter.outputURL, &storedURL, &error);
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:stored ? @"Audio Track Selected" : @"Audio Track Error" message:stored ? @"The selected music track will replace the video's audio on the next broadcast." : (error.localizedDescription ?: @"The music track could not be exported.") preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self.viewController presentViewController:alert animated:YES completion:nil];
        });
    }];
}
@end

@interface PRPButtonTarget : NSObject
@property(nonatomic, weak) UIViewController *viewController;
- (void)chooseVideo:(UIButton *)sender;
- (void)chooseVideoFromFiles;
- (void)chooseAudioTrack;
- (void)showPreview;
- (void)showDebug;
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
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Prerecorded Stream Settings" message:[NSString stringWithFormat:@"Pipeline: %@\nScaling: %@\nLoop: %@\nVolume: %.0f%%", PRPPipelineEnabled() ? @"Enabled" : @"Safe/off", PRPScaleMode().capitalizedString, PRPLoopEnabled() ? @"On" : @"Off", PRPVolume() * 100.0f] preferredStyle:UIAlertControllerStyleActionSheet];
        [sheet addAction:[UIAlertAction actionWithTitle:PRPPipelineEnabled() ? @"Pipeline: turn off" : @"Pipeline: enable" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [[NSUserDefaults standardUserDefaults] setBool:!PRPPipelineEnabled() forKey:kPRPPipelineEnabledKey];
            UIAlertController *restart = [UIAlertController alertControllerWithTitle:@"Restart TikTok" message:@"The camera replacement setting takes effect after force-closing and relaunching TikTok." preferredStyle:UIAlertControllerStyleAlert];
            [restart addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [vc presentViewController:restart animated:YES completion:nil];
        }]];
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
        [sheet addAction:[UIAlertAction actionWithTitle:@"Preview current scaling" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self showPreview];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Choose music audio track" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self chooseAudioTrack];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Choose video from Files" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self chooseVideoFromFiles];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Open debug screen" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self showDebug];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
        if (sheet.popoverPresentationController) {
            sheet.popoverPresentationController.sourceView = sender;
            sheet.popoverPresentationController.sourceRect = sender.bounds;
        }
        [vc presentViewController:sheet animated:YES completion:nil];
    });
}

- (void)showPreview {
    UIViewController *vc = self.viewController;
    if (!vc) return;
    if (![[NSFileManager defaultManager] fileExistsAtPath:PRPPrivateVideoPath()]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Preview" message:@"Select a prerecorded video first." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:alert animated:YES completion:nil];
        return;
    }
    PRPPreviewController *preview = [PRPPreviewController new];
    preview.modalPresentationStyle = UIModalPresentationFullScreen;
    [vc presentViewController:preview animated:YES completion:nil];
}

- (void)showDebug {
    if (!self.viewController) return;
    PRPDebugViewController *debug = [PRPDebugViewController new];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:debug];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    [self.viewController presentViewController:navigation animated:YES completion:nil];
}

- (void)chooseAudioTrack {
    UIViewController *vc = self.viewController;
    if (!vc) return;
    MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
    picker.allowsPickingMultipleItems = NO;
    picker.prompt = @"Choose audio for the prerecorded stream";
    PRPMediaPickerDelegate *delegate = [PRPMediaPickerDelegate new];
    delegate.viewController = vc;
    objc_setAssociatedObject(picker, kPRPPickerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    picker.delegate = delegate;
    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)chooseVideoFromFiles {
    if (!self.viewController) return;
    NSArray *types = @[[UTType typeWithIdentifier:@"public.movie"], [UTType typeWithIdentifier:@"public.video"]];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.allowsMultipleSelection = NO;
    PRPDocumentPickerDelegate *delegate = [PRPDocumentPickerDelegate new];
    delegate.viewController = self.viewController;
    objc_setAssociatedObject(picker, kPRPPickerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    picker.delegate = delegate;
    [self.viewController presentViewController:picker animated:YES completion:nil];
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
    if (!vc.viewIfLoaded || (!PRPIsLiveController(vc) && !gPRPCameraPipelineActive)) return;
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

%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate queue:(dispatch_queue_t)queue {
    gPRPCameraPipelineActive = delegate != nil;
    if (!PRPPipelineEnabled()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive) continue;
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                    if (!window.isKeyWindow || !window.rootViewController) continue;
                    PRPInstallButton(PRPVisibleController(window.rootViewController));
                    break;
                }
            }
        });
        %orig(delegate, queue);
        return;
    }
    if (delegate && ![delegate isKindOfClass:[PRPCaptureDelegateProxy class]]) {
        PRPCaptureDelegateProxy *proxy = [PRPCaptureDelegateProxy new];
        proxy.originalDelegate = delegate;
        proxy.queue = queue;
        objc_setAssociatedObject(self, kPRPCaptureProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        PRPDebugLog(@"wrapped AVCaptureVideoDataOutput delegate %@", NSStringFromClass(delegate.class));
        dispatch_async(dispatch_get_main_queue(), ^{
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive) continue;
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                    if (!window.isKeyWindow || !window.rootViewController) continue;
                    PRPInstallButton(PRPVisibleController(window.rootViewController));
                    break;
                }
            }
        });
        %orig(proxy, queue);
        return;
    }
    if (!delegate) gPRPCameraPipelineActive = NO;
    %orig(delegate, queue);
}

%end

#if 0
%hook SampleHandler

- (void)broadcastStartedWithSetupInfo:(NSDictionary *)setupInfo {
    %orig;
    @synchronized ([PRPAssetPump class]) {
        NSURL *url = [NSURL fileURLWithPath:PRPSharedVideoPath()];
        NSURL *audioURL = [NSURL fileURLWithPath:PRPSharedAudioPath()];
        if (![[NSFileManager defaultManager] fileExistsAtPath:audioURL.path]) audioURL = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            gPRPAssetPump = [PRPAssetPump new];
            if (![gPRPAssetPump startWithURL:url audioURL:audioURL]) gPRPAssetPump = nil;
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
#endif

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
