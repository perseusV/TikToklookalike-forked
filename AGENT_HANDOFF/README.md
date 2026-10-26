# Prerecorded-stream analysis handoff

This branch records an independent analysis of the supplied TikTok 39.3.0 IPA and a bounded implementation attempt. The repository contains no original source, Xcode project, or build configuration. The original IPA is preserved outside the repository under the analysis workspace.

## Current status

- Original IPA downloaded from release `v39.3.0` and preserved unchanged.
- Archive, metadata, Mach-O architecture, ReplayKit extension, dependencies, and signature-command metadata inspected.
- The app contains a genuine `AwemeBroadcastExtension.appex` configured as a ReplayKit sample-buffer upload extension with principal class `SampleHandler`.
- A source-level ReplayKit/AVAssetReader prototype is included for a legitimate, clearly labeled prerecorded source.
- The prototype was not integrated into the proprietary binaries and was not compiled: this environment has no Xcode, Apple SDK, codesign, provisioning profile, or iOS simulator.
- No functional or installation-ready modified IPA was produced. A structurally valid non-functional analysis candidate is produced separately and is explicitly not represented as the requested feature.

Read `PROJECT_STATE.md`, `LIVE_STREAMING.md`, and `KNOWN_ISSUES.md` first.
