# Project state

## Completed

The release asset `TikTok-39.3.0-build-393020.ipa` was downloaded from the repository release and verified at 305,079,477 bytes with SHA-256 `8b0fcefcb292de833f523395f4976014b300c11eb76cfa93b41baa0ba14b1393`. The archive passes `unzip -tq`. Its main bundle is `com.zhiliaoapp.musically`, version `39.3.0`, build `393020`, minimum iOS 13.0, and arm64-only.

The extracted app contains 27 arm64 Mach-O files, including `MusicallyCore.framework/MusicallyCore` and `PlugIns/AwemeBroadcastExtension.appex/AwemeBroadcastExtension`. The broadcast extension is configured for `com.apple.broadcast-services-upload`, `RPBroadcastProcessModeSampleBuffer`, and principal class `SampleHandler`. Static strings show CoreMedia, CoreVideo, VideoToolbox, ReplayKit, pixel-buffer pools, sample-buffer processing, audio/video counters, and TikTok-specific broadcast processor classes.

A reconstructed Swift prototype demonstrates the technically appropriate path: the host app must explicitly select a video, place it in an app-group container, communicate the selection to the broadcast extension, and the extension must read video and audio tracks with `AVAssetReader`, create correctly timed `CMSampleBuffer` objects, and deliver them through the existing authorized broadcast path. The prototype is not a claim that the proprietary app already contains these changes.

## Blockers

The repository contains only `README.md` and `ANALYSIS.md`; no source files, Xcode project, or build system are available. The sandbox is Linux and has no Xcode, iPhoneOS SDK, Apple frameworks, codesign, signing identity, provisioning profile, or simulator. The existing app and extension are code-signed; modifying their executable, Info.plist, or resources invalidates the existing signature and requires an authorized Apple signing workflow. The app's internal broadcast protocol and UI call graph cannot be safely reconstructed into a working binary patch from strings alone.

## Next concrete steps on an authorized Mac

Obtain the original source or a legally authorized build project, or create a maintained fork with a normal Xcode target. Add a clearly labeled prerecorded-video mode to the live UI using `PHPickerViewController` or `PhotosPicker`; copy the selected asset into the shared app-group container; define a versioned app/extension message contract; implement the AVAssetReader-to-CMSampleBuffer path in the broadcast extension; test timing, looping, audio/video synchronization, cancellation, and camera-mode switching; then archive and sign every changed bundle with the user's own certificate and provisioning profiles. Validate on a simulator where possible and on the user's own device.
