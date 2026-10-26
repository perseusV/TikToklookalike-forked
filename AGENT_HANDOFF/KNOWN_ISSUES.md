# Known issues

The supplied repository has no source code. The IPA is a proprietary compiled application with an existing ReplayKit extension, but the exact host UI, private app/extension message contract, and private broadcast transport are not recoverable safely from names and strings alone.

This environment lacks the Apple toolchain and signing credentials. Any executable or plist modification would invalidate the original signature. No embedded provisioning profile was found. A repackaged archive would therefore not be installation-ready, even if ZIP-valid.

The reconstructed prototype is intentionally incomplete: it demonstrates asset-reader setup but does not implement production timestamp pacing, audio/video pairing, looping, camera switching, or the private upload transport. It must not be presented as a working feature.
