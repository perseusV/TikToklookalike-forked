# PrerecordedLiveUI

This is the first actual UI implementation. It is injected into `com.zhiliaoapp.musically` only. When a visible view controller appears whose class, title, navigation title, or visible labels identify it as LIVE, livestream, room, studio, broadcast, or creator-live, the tweak adds a red `Prerecorded` video button at the top-right safe-area position.

Tapping the button opens the system Photos video picker, copies the selected movie into:

```text
Library/Caches/PrerecordedLiveUI/selected-video.mov
```

and displays a confirmation alert. The selected file is not yet connected to TikTok’s live encoder or ReplayKit extension. That requires the runtime class/selector evidence from `PrerecordedPipelineProbe` and is a separate implementation stage.

## Build

```sh
export THEOS=/home/ubuntu/workspace/upstream/theos
./build.sh
```

The package is rootless, arm64, and targets iOS 15+.

## Important limitation

The LIVE controller’s concrete class name is not available from the supplied static artifact because the relevant implementation is in the large MusicallyCore binary and may be dynamically constructed. The implementation therefore uses conservative runtime detection rather than claiming a statically confirmed controller hook. If the button does not appear, collect a screenshot and the `[PrerecordedLiveUI]` log lines; the detection predicate can then be narrowed to the actual controller.
