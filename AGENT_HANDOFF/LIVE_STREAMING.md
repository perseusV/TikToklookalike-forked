# Live-streaming architecture findings

The supplied IPA has a real ReplayKit upload extension at `Payload/TikTok.app/PlugIns/AwemeBroadcastExtension.appex`. Its `Info.plist` declares extension point `com.apple.broadcast-services-upload`, principal class `SampleHandler`, and `RPBroadcastProcessModeSampleBuffer`.

The extension executable imports or references ReplayKit, CoreMedia, CoreVideo, VideoToolbox, Metal, UIKit, Foundation, and related system frameworks. Static symbols and Objective-C metadata include `RPBroadcastSampleHandler`, `IESBroadcastAppCommunicator`, `IESBroadcastLaunchConfig`, `IESBroadcastVideoBufferProcessor`, `IESLiveBroadcastMetalRender`, `CMSampleBuffer` accessors, `CVPixelBufferPool` operations, and video/audio duration counters. This establishes a sample-buffer processing pipeline, not the exact network submission contract.

The main app and `MusicallyCore.framework` contain many camera, live, video, audio, and broadcast-related class names. Names alone do not establish call relationships or provide safe patch offsets. The extension also contains TikTok-specific frameworks and app-group metadata, so a new media source would need to respect the existing app/extension communication and signing model.

A prerecorded mode can be implemented legitimately only by adding an explicit UI choice in the host app and a corresponding extension-side media producer. The host must not silently replace camera frames. The selected asset must be clearly identified as prerecorded to the user and viewers where the product UI supports that disclosure.

## New executable evidence

Objective-C metadata and ARM64 disassembly now resolve the concrete hierarchy and selectors. `SampleHandler` subclasses `IESSampleHandler` and exposes only `init` and `appGroupId`. `IESSampleHandler` implements `broadcastStartedWithSetupInfo:`, `processSampleBuffer:withType:`, `processVideoSampleBuffer:`, `processMicAudioSampleBuffer:`, `processAppAudioSampleBuffer:`, pause/resume handlers, encoder callbacks, and host-session methods. `IESBroadcastVideoBufferProcessor` implements `processVideoSampleBuffer:`, `sendToEncode:pts_ms:`, `didEncodeData:timestamp:dts:videoFrameType:sourceBuffer:`, pixel-buffer pool creation, frame pacing, and pause-frame handling. `IESBroadcastAppCommunicator` implements encoded-video, audio-binary, message-listener, and app-group socket methods.

The disassembly of `processSampleBuffer:withType:` shows a type switch for ReplayKit sample types 1, 2, and 3, followed by dispatch into the private handler paths. This confirms that the existing extension accepts media only through its private handler and encoder/communicator chain; there is no public arbitrary-sample injection method visible in the extension.
