# Live-streaming architecture findings

The supplied IPA has a real ReplayKit upload extension at `Payload/TikTok.app/PlugIns/AwemeBroadcastExtension.appex`. Its `Info.plist` declares extension point `com.apple.broadcast-services-upload`, principal class `SampleHandler`, and `RPBroadcastProcessModeSampleBuffer`.

The extension executable imports or references ReplayKit, CoreMedia, CoreVideo, VideoToolbox, Metal, UIKit, Foundation, and related system frameworks. Static symbols and Objective-C metadata include `RPBroadcastSampleHandler`, `IESBroadcastAppCommunicator`, `IESBroadcastLaunchConfig`, `IESBroadcastVideoBufferProcessor`, `IESLiveBroadcastMetalRender`, `CMSampleBuffer` accessors, `CVPixelBufferPool` operations, and video/audio duration counters. This establishes a sample-buffer processing pipeline, not the exact network submission contract.

The main app and `MusicallyCore.framework` contain many camera, live, video, audio, and broadcast-related class names. Names alone do not establish call relationships or provide safe patch offsets. The extension also contains TikTok-specific frameworks and app-group metadata, so a new media source would need to respect the existing app/extension communication and signing model.

A prerecorded mode can be implemented legitimately only by adding an explicit UI choice in the host app and a corresponding extension-side media producer. The host must not silently replace camera frames. The selected asset must be clearly identified as prerecorded to the user and viewers where the product UI supports that disclosure.
