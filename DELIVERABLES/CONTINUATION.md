# TikTok prerecorded-camera handoff

This repository contains the latest source and two verified arm64 Debian packages.

## Packages

### 1. Reference-camera implementation

`com.manus.projecttiky-reference-camera_0.2.0-2+debug_iphoneos-arm64.deb`

SHA-256:

```text
d7f8f63ecef092bb343eb6bdb79011a535f909d0f7fcf5c108cc76a2af5e8ca3
```

This build follows the supplied working reference package: it wraps TikTok's `AVCaptureVideoDataOutput` delegate, stores the video under TikTok's data container, and substitutes camera sample buffers matching the incoming dimensions and pixel format.

### 2. Crash-safe debug implementation

`com.manus.projecttiky-crashsafe-debug_0.3.0-3+debug_iphoneos-arm64.deb`

SHA-256:

```text
6fd3d3494f85722b6bec6d6f2c0be3e19a63b814a153dccc9e853f3be8d08270
```

This is the continuation build to test first. It disables the ReplayKit hook, leaves camera replacement off by default, adds strict frame validation, supports Files-app video import, and adds the in-app persistent debug screen.

## Install

```sh
dpkg -r com.manus.prerecordedliveui
dpkg -i DELIVERABLES/com.manus.projecttiky-crashsafe-debug_0.3.0-3+debug_iphoneos-arm64.deb
```

Do not install both packages simultaneously. The reference-camera package is preserved for comparison; the crash-safe debug package is the recommended continuation artifact.

## Debug data

The device-side diagnostic file is:

```text
<TikTok home>/Documents/TikTokFakeLiveCam/diagnostic.log
```

The floating icon's long-press settings include **Open debug screen**. The pipeline is intentionally `Safe/off` by default and must be enabled followed by a TikTok restart before buffer replacement is attempted.

## Current technical status

Builds are verified as arm64 Mach-O rootless packages. Physical-device behavior has not been verified from this environment. If the app crashes while the pipeline is `Safe/off`, collect the device crash report because that indicates injection/class compatibility rather than media substitution. If it crashes only after enabling the pipeline, inspect `diagnostic.log` and the system log for the last camera-reader event.
