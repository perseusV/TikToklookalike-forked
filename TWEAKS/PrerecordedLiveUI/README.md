# PrerecordedLiveUI 0.2.0

This build pivots from the earlier ReplayKit-only experiment to the camera path used by the supplied working `TikTokFakeLiveCam` package.

## Reference package finding

Static analysis of `com.mohamedjj.tiktokfakelivecam_1.0.0-1_iphoneos-arm64.deb` found:

- Its tweak filter targets only `com.zhiliaoapp.musically`.
- It wraps `AVCaptureVideoDataOutput`'s sample-buffer delegate.
- Its proxy forwards `captureOutput:didOutputSampleBuffer:fromConnection:` to TikTok with a replacement video buffer.
- It uses `AVAssetReader`/`AVAssetReaderTrackOutput` and matches the incoming camera pixel format and dimensions.
- It reads `selected.mov` from `Documents/TikTokFakeLiveCam` inside TikTok's own data container.
- It does not replace ReplayKit `SampleHandler` buffers.

That architecture explains why the earlier build could select a file but never affect TikTok's LIVE preview or outgoing camera path.

## Corrected implementation

This package now:

1. Stores the selected video in TikTok's own container:

```text
< TikTok home >/Documents/TikTokFakeLiveCam/selected.mov
```

2. Removes the previous selected file when a new asset is chosen, so a failed replacement cannot silently leave the old video active.
3. Injects into TikTok's main process only.
4. Wraps each `AVCaptureVideoDataOutput` delegate when TikTok installs it.
5. Detects the incoming camera width, height, and pixel format.
6. Creates an AVAssetReader output matching those values.
7. Rewrites the prerecorded frame timestamp to the live camera callback timestamp.
8. Calls TikTok's original camera delegate with the replacement buffer.
9. Places the floating control only when the camera pipeline is active, avoiding message screens.

The earlier settings menu, scaling preview, loop control, custom local Music-library track, and relative video-volume control remain in the source. The custom audio track is composed into the reader when available.

## Device logs

Use SSH or a terminal app on the device:

```sh
log stream --style compact --level debug \\
  --predicate 'eventMessage CONTAINS[c] "PrerecordedLiveUI"'
```

Expected evidence for the corrected path:

```text
wrapped AVCaptureVideoDataOutput delegate ...
camera delegate source active target=... fourcc=...
AVCapture replacement sample #30
AVCapture replacement sample #60
```

These messages prove that the camera delegate is receiving replacement buffers. Verify the final outgoing stream from another account/device; local logs cannot prove what TikTok's server accepted.

## Install

Remove the prior package, then install this version:

```sh
dpkg -r com.manus.prerecordedliveui
dpkg -i com.manus.projecttiky-reference-camera_0.2.0-2+debug_iphoneos-arm64.deb
```

Respring or restart the injection framework, relaunch TikTok, enter the camera-based LIVE screen, and select the video there.

## Build

```sh
export THEOS=/home/ubuntu/workspace/upstream/theos
./build.sh
```

Rootless arm64 package, target iOS 15+.
