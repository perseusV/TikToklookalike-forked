
## Focused unresolved question resolved

The existing broadcast extension is technically capable of processing video and audio sample buffers, but the supported path is private and already occupied by `IESSampleHandler` plus `IESBroadcastVideoBufferProcessor`. The reconstructed public ReplayKit handler cannot feed arbitrary buffers into that chain. A reliable implementation therefore requires source-level access to the host and extension or a newly designed replacement extension that reproduces the app-group handshake, encoder parameters, host communication, and signing configuration. The available IPA alone does not provide a safe binary patch path.
