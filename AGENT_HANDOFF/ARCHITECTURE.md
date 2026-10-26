# Architecture

The main executable is `Payload/TikTok.app/TikTok`. The app embeds `MusicallyCore.framework/MusicallyCore` and seven-plus app extensions, including the ReplayKit broadcast extension at `PlugIns/AwemeBroadcastExtension.appex`. The extension is arm64 and uses the system ReplayKit upload extension point.

The available evidence supports a host-app plus broadcast-extension architecture with app-group communication and a sample-buffer media processing layer. It does not expose the private network upload protocol or enough source-level call graph to safely patch the binary.
