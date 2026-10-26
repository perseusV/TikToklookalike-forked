# Extension pipeline compatibility assessment

## Verified class relationship

Objective-C metadata parsing of `AwemeBroadcastExtension` shows:

```text
SampleHandler : IESSampleHandler
IESSampleHandler : NSObject
```

`SampleHandler` itself exposes only `init` and `appGroupId`. The actual ReplayKit lifecycle and media dispatch are implemented by the private `IESSampleHandler` class.

## Verified dispatch path

The extension's `Info.plist` registers `SampleHandler` as an `RPBroadcastSampleHandler` principal class. The private handler exposes `broadcastStartedWithSetupInfo:`, `broadcastFinished`, `finishBroadcastWithError:`, and `processSampleBuffer:withType:`. The disassembly of `processSampleBuffer:withType:` compares the ReplayKit sample type against 1, 2, and 3, then dispatches to the handler's video, app-audio, or microphone-audio processing path. These values correspond to ReplayKit's video, app-audio, and microphone-audio sample types.

The verified internal path is:

```text
ReplayKit callback
  -> IESSampleHandler processSampleBuffer:withType:
     -> processVideoSampleBuffer:
        -> IESBroadcastVideoBufferProcessor processVideoSampleBuffer:
           -> pixel-buffer rotation/mixing/pacing
           -> VideoToolbox encoder
           -> processor:didEncodeData:timestamp:dts:videoFrameType:
           -> IESBroadcastAppCommunicator tellContainerAppEncodedVideoData:
     -> processMicAudioSampleBuffer:
        -> audio conversion/packing
        -> IESBroadcastAppCommunicator tellContainerAppAudioBinaryData:length:
     -> processAppAudioSampleBuffer:
        -> audio conversion/packing
        -> IESBroadcastAppCommunicator tellContainerAppAudioBinaryData:length:
```

The extension also exposes `IESBroadcastAppCommunicator` methods for `passMessage:forKey:`, message listeners, encoded video data, audio binary data, and host connection state. This is strong evidence that the extension is not a generic file player: it depends on a private host handshake, encoder parameters, app-group/socket communication, and private status messages.

## Prototype compatibility

`PrerecordedReplayKitSampleHandler.swift` is not compatible with this exact extension as written. A ReplayKit upload handler receives sample buffers from ReplayKit; it does not expose a public API that lets a replacement handler push arbitrary sample buffers into TikTok's private `IESSampleHandler`/`IESBroadcastVideoBufferProcessor` chain. The prototype reads one video sample and then discards it. It does not create a timed audio stream, call the private processor, perform host handshake, or submit encoded data through the private communicator.

Replacing the principal class with the prototype would also bypass the existing launch configuration, setup messages, encoder parameters, orientation, pause/resume state, performance reporting, and host socket setup. Therefore independent compilation of a generic ReplayKit sample handler would not establish compatibility with this app.

## Approach decision

The evidence favors modifying source-level host and extension targets, preserving `IESSampleHandler` setup and adding a documented media-source mode before or inside the existing processor. A supported external media-input integration is not visible in the IPA. A binary patch would require adding substantial ARM64 code or a new signed library, reproducing private host messages and encoder contracts, and resigning the app and every nested bundle. It is not reliable from the available artifact alone.
