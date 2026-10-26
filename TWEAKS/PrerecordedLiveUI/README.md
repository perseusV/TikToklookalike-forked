# PrerecordedLiveUI 0.3.0

This is a crash-safe diagnostic build based on the supplied working `TikTokFakeLiveCam` package.

## Safety changes

- The ReplayKit `SampleHandler` hook is disabled.
- Camera replacement is **off by default**. TikTok's original camera delegate is left untouched until explicitly enabled in the settings menu.
- The reader is isolated per `AVCaptureVideoDataOutput` rather than shared globally.
- Replacement frames are rejected unless their width, height, and pixel format exactly match TikTok's incoming camera frame.
- The selected file is validated for an iOS-decodable video track before it is accepted.
- New video selection removes the previous selected video first, preventing stale state.

## Video sources

Tap the floating video icon for the Photos picker. Long-press it for settings, including **Choose video from Files**. The Files picker accepts common iOS video UTIs, including MP4/MOV/M4V/3GP files that AVFoundation can decode. Unsupported codecs or containers are rejected with a visible error; iOS AVFoundation cannot promise arbitrary formats such as every MKV/WebM variant without an external transcoder.

## Debug screen

Long-press the floating icon and choose **Open debug screen**. The screen displays and can clear:

```text
< TikTok home >/Documents/TikTokFakeLiveCam/diagnostic.log
```

The log records delegate installation, source-file visibility, asset-reader failures, target dimensions/pixel format, rejected replacement frames, and replacement-frame counts.

To collect system logs as well:

```sh
log stream --style compact --level debug \\
  --predicate 'eventMessage CONTAINS[c] "PrerecordedLiveUI"'
```

## Testing order

1. Install this package and respring/restart injection.
2. Launch TikTok and enter its camera-based LIVE screen. The floating icon should appear without replacing frames yet.
3. Open settings and confirm the pipeline says `Safe/off`.
4. Select a video from Photos or Files.
5. Open the debug screen and confirm the video was accepted.
6. Enable the pipeline from settings.
7. Force-close and relaunch TikTok so the delegate is installed in the selected mode.
8. Return to LIVE and check the debug screen for `wrapped AVCaptureVideoDataOutput delegate`, `camera delegate source active`, and replacement counts.

If TikTok crashes even while the pipeline is `Safe/off`, uninstall this package and capture the device crash report; that indicates an injection/compatibility issue rather than a media-buffer issue.

## Build

```sh
export THEOS=/home/ubuntu/workspace/upstream/theos
./build.sh
```

Rootless arm64 package, iOS 15+.
