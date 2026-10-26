#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <objc/runtime.h>

static void PRPLogClass(NSString *name) {
    Class cls = NSClassFromString(name);
    if (!cls) {
        NSLog(@"[PrerecordedPipelineProbe] class missing: %@", name);
        return;
    }
    NSMutableArray *selectors = [NSMutableArray array];
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *sel = NSStringFromSelector(method_getName(methods[i]));
        if ([sel containsString:@"Push"] || [sel containsString:@"push"] ||
            [sel containsString:@"Sample"] || [sel containsString:@"sample"] ||
            [sel containsString:@"Audio"] || [sel containsString:@"Video"] ||
            [sel containsString:@"Buffer"] || [sel containsString:@"Asset"] ||
            [sel containsString:@"Picker"] || [sel containsString:@"broadcast"] ||
            [sel containsString:@"Broadcast"]) {
            [selectors addObject:sel];
        }
    }
    free(methods);
    NSLog(@"[PrerecordedPipelineProbe] class present: %@; selectors=%@", name, selectors);
}

%hook SampleHandler

- (void)broadcastStartedWithSetupInfo:(NSDictionary *)setupInfo {
    NSLog(@"[PrerecordedPipelineProbe] broadcastStartedWithSetupInfo keys=%@", setupInfo.allKeys);
    %orig;
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(NSInteger)sampleBufferType {
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    NSLog(@"[PrerecordedPipelineProbe] processSampleBuffer type=%ld pts=%lld/%d valid=%d", (long)sampleBufferType, pts.value, pts.timescale, (int)CMTIME_IS_VALID(pts));
    %orig;
}

- (void)broadcastFinished {
    NSLog(@"[PrerecordedPipelineProbe] broadcastFinished");
    %orig;
}

%end

%hook IESBroadcastVideoBufferProcessor

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    NSLog(@"[PrerecordedPipelineProbe] IESBroadcastVideoBufferProcessor processVideoSampleBuffer pts=%lld/%d", pts.value, pts.timescale);
    %orig;
}

%end

%hook IESBroadcastAppCommunicator

- (void)tellContainerAppEncodedVideoData:(NSData *)data {
    NSLog(@"[PrerecordedPipelineProbe] encoded video transport bytes=%lu", (unsigned long)data.length);
    %orig;
}

- (void)tellContainerAppAudioBinaryData:(NSData *)data length:(NSUInteger)length {
    NSLog(@"[PrerecordedPipelineProbe] audio transport bytes=%lu declared=%lu", (unsigned long)data.length, (unsigned long)length);
    %orig;
}

%end

%ctor {
    @autoreleasepool {
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"<none>";
        NSLog(@"[PrerecordedPipelineProbe] loaded process=%@ bundle=%@", NSProcessInfo.processInfo.processName, bundleID);
        for (NSString *name in @[
            @"SampleHandler",
            @"IESBroadcastVideoBufferProcessor",
            @"IESBroadcastAppCommunicator",
            @"VeLivePusher",
            @"VEExternalVideoCapture",
            @"VEExternalAudioCapture",
            @"VEVideoSampleBuffer",
            @"AVAssetReader",
            @"AVAssetReaderTrackOutput",
            @"PHPickerViewController",
            @"UIImagePickerController"
        ]) {
            PRPLogClass(name);
        }
    }
}
