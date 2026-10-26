# PrerecordedPipelineProbe

This is a non-invasive diagnostic checkpoint, not the prerecorded-video implementation. It is filtered into both the main TikTok process (`com.zhiliaoapp.musically`) and the ReplayKit broadcast extension (`com.zhiliaoapp.musically.VideoBroadcastExtension1`). It logs class availability, relevant selectors, ReplayKit sample-buffer callbacks, encoded video/audio transport calls, and presentation timestamps, then calls the original implementation.

It does not select Photos, create media, replace buffers, alter timestamps, or change the broadcast path.

## Build

```sh
export THEOS=/home/ubuntu/workspace/upstream/theos
./build.sh
```

The build targets rootless iOS 15+ and arm64, matching the supplied app and extension metadata.

## Device evidence to collect

Install only after confirming the jailbreak supports rootless packages and arm64 injection. Launch TikTok, enter LIVE, start the existing broadcast flow, then collect device logs filtered by:

```text
PrerecordedPipelineProbe
```

The important checkpoints are:

- Main-process class presence: `VeLivePusher`, `VEExternalVideoCapture`, `VEExternalAudioCapture`, `VEVideoSampleBuffer`, and picker classes.
- Extension callback: `processSampleBuffer type=... pts=...`.
- Extension processing: `IESBroadcastVideoBufferProcessor processVideoSampleBuffer`.
- Cross-process transport: `encoded video transport bytes=...` and `audio transport bytes=...`.

No checkpoint is considered passed from compilation alone.
