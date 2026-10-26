# PrerecordedLiveUI

This package now contains two parts:

1. A small, draggable 48×48 LIVE-screen video icon that opens the Photos video picker.
2. An experimental ReplayKit extension hook that attempts to substitute the selected movie's video and app-audio sample buffers into `SampleHandler` before TikTok's existing broadcast encoder.

The tweak is filtered into both:

```text
com.zhiliaoapp.musically
com.zhiliaoapp.musically.VideoBroadcastExtension1
```

## UI behavior

The floating icon can be dragged inside the safe area and remembers its position. Only one icon is retained per TikTok window, even when nested LIVE controllers appear. Tapping it selects one video. The picker first tries a temporary file URL and falls back to the provider's data representation when Photos returns a stale or nonexistent URL. The result is stored in the app cache plus the jailbreak-shared path:

```text
/var/mobile/Media/PrerecordedLiveUI/selected-video.mov
```

## Experimental pipeline behavior

When the broadcast extension receives `broadcastStartedWithSetupInfo:`, the tweak opens the shared movie with `AVAssetReader`. During `processSampleBuffer:withType:` it attempts to replace video and `RPSampleBufferTypeAudioApp` buffers, preserving the original callback presentation timestamps through `CMSampleBufferCreateCopyWithNewTiming`. The original SampleHandler is then called with the replacement buffer.

This is not yet device-verified. It may fail if the extension sandbox cannot read the shared path, if the source audio format does not match TikTok's encoder, if the `SampleHandler` implementation differs at runtime, or if the app expects additional metadata/transport state.

## Build

```sh
export THEOS=/home/ubuntu/workspace/upstream/theos
./build.sh
```

The package is rootless, arm64, and targets iOS 15+.

## Required device logs

After selecting a video and starting LIVE, collect:

```sh
log stream --level debug --predicate 'eventMessage CONTAINS[c] "PrerecordedLiveUI"'
```

Successful pipeline evidence would include:

```text
asset pump started
replacing video sample at ...
replacing app audio sample at ...
```

Absence of `asset pump started` means the extension cannot see the shared file or did not enter the expected callback. Presence of replacement logs does not alone prove the remote stream contains the prerecorded media; that still requires device-side observation.
