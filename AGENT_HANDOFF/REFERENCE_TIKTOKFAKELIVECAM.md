# Reference TikTokFakeLiveCam reverse-engineering record

Analyzed package: `com.mohamedjj.tiktokfakelivecam_1.0.0-1_iphoneos-arm64.deb`

The package contains a separate helper app plus `TikTokFakeLiveCamTikTok.dylib`. Its filter is only `com.zhiliaoapp.musically`. Static strings and imports show `AVCaptureVideoDataOutput`, `AVCaptureVideoDataOutputSampleBufferDelegate`, `setSampleBufferDelegate:queue:`, `captureOutput:didOutputSampleBuffer:fromConnection:`, `AVAssetReader`, and `AVAssetReaderTrackOutput`.

The central classes are `LCVideoFrameSource` and `LCVideoDelegateProxy`. The binary logs `video reader READY`, wraps the original camera delegate, reads a selected `selected.mov`, matches target width/height/fourcc, and passes replacement camera sample buffers into the original delegate. The helper app uses Photos picker APIs and MobileContainerManager private entitlements to locate TikTok's data container. The tweak itself reads `Documents/TikTokFakeLiveCam/selected.mov` relative to the injected TikTok process home.

This is the evidence basis for `TWEAKS/PrerecordedLiveUI` version 0.2.0. No embedded scripts or binary payloads were executed.
