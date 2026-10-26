# Reconstructed prototype compatibility

The prototype imports only public `AVFoundation` and `ReplayKit` APIs and would require an Xcode project targeting iOS 13 or later, an iPhoneOS SDK, Swift compiler, and an app-group entitlement matching the signed host and extension. It cannot be compiled or compatibility-tested in the current Linux sandbox because no Swift/Xcode/iOS SDK toolchain is available.

More importantly, source compatibility is not integration compatibility. The prototype subclasses `RPBroadcastSampleHandler`, reads a shared asset, and discards the first sample buffer. It has no public mechanism to insert that buffer into the private TikTok pipeline. It would need an authorized source project exposing the private processor or a redesigned extension that owns encoding and host communication. The existing IPA demonstrates neither a documented public injection interface nor a way to safely replace the private classes while retaining the app’s handshake.

A compile test on a Mac would answer only whether the public prototype syntax is accepted. It would not prove that the exact app can link, sign, launch, communicate with its host, or broadcast. Those questions require the original source/build configuration and the user’s signing identities.
