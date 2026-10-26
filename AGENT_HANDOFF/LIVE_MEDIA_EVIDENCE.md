# Live and prerecorded-media evidence

## Confirmed package metadata

- Main bundle: `com.zhiliaoapp.musically`, iOS minimum 13.0, arm64.
- Broadcast extension: `com.zhiliaoapp.musically.VideoBroadcastExtension1`, iOS minimum 12.0, arm64.
- Extension point: `com.apple.broadcast-services-upload`.
- Principal class: `SampleHandler`.
- ReplayKit process mode: `RPBroadcastProcessModeSampleBuffer`.
- No application-group entitlement was present in the extracted plist files; the extension binary nevertheless contains an app-group/socket transport implementation.

## Main-process / MusicallyCore evidence

Objective-C metadata and readable selector strings in `Frameworks/MusicallyCore.framework/MusicallyCore` identify:

- Live-pusher objects: `VeLivePusher`, `VeLivePusherConfiguration`, `VeLiveVideoCaptureConfiguration`, `VeLiveAudioCaptureConfiguration`, `VeLiveVideoFrame`, `VeLiveAudioFrame`.
- External capture objects: `VEExternalVideoCapture`, `VEExternalAudioCapture`, `VEVideoSampleBuffer`.
- Media readers: `AVAssetReader`, `AVAssetReaderTrackOutput`, `AVAssetReaderAudioMixOutput`, `AVAssetReaderVideoCompositionOutput`.
- Picker/photo classes: `PHPhotoLibrary`, `PHPickerViewController`, `UIImagePickerController`.
- CoreMedia symbols: `CMSampleBufferCreate`, `CMSampleBufferCreateReady`, `CMSampleBufferCreateForImageBuffer`, `CMSampleBufferCreateReadyWithImageBuffer`, `CMSampleBufferCreateCopyWithNewTiming`, `CMSampleBufferGetPresentationTimeStamp`, `CMSampleBufferGetImageBuffer`, `CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer`, and related APIs.
- Live-push selectors: `startPush`, `stopPush`, `startPushData`, `pushVideoBuffer:andCMTime:`, `pushVideoBufferV2:andCMTime:`, `pushAudioBuffer:andInNumberFrames:andBytesPerSample:andNumberOfChannels:andSampleRate:andTimestampUs:`, `setVideoSource:`, `setVideoSourceArray:`, `setAudioSourceArray:`, `setupLiveStreamGraph`, and `setGetAudioCallback:`.

These are strong implementation hooks, but static strings do not establish which concrete object owns each selector at runtime or whether the app accepts caller-created buffers for a live session.

## Extension evidence

The extension contains the following confirmed metadata/selectors:

- `SampleHandler` and inherited ReplayKit callbacks, including `broadcastStartedWithSetupInfo:`, `processSampleBuffer:withType:`, and `broadcastFinished`.
- `IESBroadcastVideoBufferProcessor` with `processVideoSampleBuffer:`, `sendToEncode:pts_ms:`, `encodeVideoPixelBuffer:timestamp:`, `didEncodeData:timestamp:dts:videoFrameType:sourceBuffer:`, and `releaseSourceBuffer:`.
- `IESBroadcastAppCommunicator` with `initWithAppGroupIdentifier:socketStyle:`, `tellContainerAppEncodedVideoData:`, `tellContainerAppAudioBinaryData:length:`, `tellContainerAppVideoFrameData:`, `listenEncodedVideoDataFromHost:`, and socket lifecycle methods.
- Socket-related strings: `com.iesLive.socket.send`, `com.iesLive.socket.receive`, `fifo_or_socket`, and `socket_style`.

This establishes a plausible path: ReplayKit sample buffers enter `SampleHandler`, are processed/encoded by `IESBroadcastVideoBufferProcessor`, then encoded video/audio data is sent through `IESBroadcastAppCommunicator`. It does not prove that replacing the original `CMSampleBuffer` source will be accepted by the encoder or host app.

## Implemented checkpoint

`TWEAKS/PrerecordedPipelineProbe` is a non-invasive dual-process diagnostic tweak. It is filtered into both the main app and broadcast extension. It logs class availability and relevant selectors, then logs ReplayKit sample-buffer callbacks, video processing, and encoded video/audio transport while calling original methods unchanged.

Build result:

```text
com.manus.prerecordedpipelineprobe_0.1.0-1+debug_iphoneos-arm64.deb
SHA-256: feb0fba8fc8636633f46d45df12d8ee278c68548fa8b8d50059249bf4f6ff161
```

Compilation, arm64 linking, ldid signing, rootless staging, Debian package creation, metadata inspection, and package-content inspection passed. Device injection and runtime logs remain unverified.

## Current conclusion

A Theos tweak is technically viable for instrumentation and likely for the eventual source substitution, but a working prerecorded broadcast still requires runtime confirmation of the owning classes and whether the host process consumes the encoded transport messages from the extension. The next smallest evidence-gathering step is device-side installation of `PrerecordedPipelineProbe`, followed by log capture during an ordinary LIVE broadcast.
