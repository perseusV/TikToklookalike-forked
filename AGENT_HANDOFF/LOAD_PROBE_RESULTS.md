# Load-probe stage record

## Stage A: source build and package

**Passed on Ubuntu:** yes.

The harmless constructor-only tweak compiled with the official Theos Linux iOS toolchain and iPhoneOS16.5 SDK. The final build is arm64-only because the extracted TikTok executable is arm64 and the bundled toolchain emitted an incompatible-ABI warning for arm64e.

Verified package:

```text
Package: com.manus.tiktokloadprobe
Version: 0.1.0-1+debug
Architecture: iphoneos-arm64
Path: packages/com.manus.tiktokloadprobe_0.1.0-1+debug_iphoneos-arm64.deb
SHA-256: 1c413f091f31c146ffd21b5bc3909de253e422f925f2ddcbf23ce2c1111c7224
```

The package contains:

```text
/var/jb/Library/MobileSubstrate/DynamicLibraries/TikTokLoadProbe.dylib
/var/jb/Library/MobileSubstrate/DynamicLibraries/TikTokLoadProbe.plist
```

The dylib is a Mach-O arm64 dynamic library. The build log records successful Logos preprocessing, compilation, linking, ldid signing, staging, and Debian package creation. `dpkg-deb --info` and `dpkg-deb --contents` were run against the final artifact.

## Stages not passed

- **Stage A device injection:** not tested; no access to the iPhone.
- **Stage B visible UI option:** not attempted; the probe intentionally does not modify UI.
- **Stage C app-to-extension media handoff:** not attempted.
- **Stage D prerecorded media generation:** not attempted.
- **Stage E acceptance by the existing private pipeline:** not attempted.
- **Stage F end-to-end iPhone test:** not possible without the user's device.

## Installation is intentionally deferred

Do not install until the user reports iOS version, hardware architecture, jailbreak name/version, rootful/rootless mode, injection framework/version, and TikTok version/build. The package is rootless and declares `firmware (>= 15.0)`; a rootful device requires a separate clean build.
