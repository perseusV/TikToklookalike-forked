# TikTokLoadProbe

This is a harmless load-probe tweak. Its only runtime action is an `NSLog` from a Logos constructor. It does not hook application methods, access user data, modify the UI, or interact with the broadcast extension.

## Build

```sh
export THEOS=/home/ubuntu/workspace/upstream/theos
export THEOS_PACKAGE_SCHEME=rootless
./build.sh
```

The default target is iOS 15.0+ rootless with one arm64 slice, matching the extracted TikTok executable. The bundled Linux toolchain emits an incompatible-ABI warning for arm64e, so arm64e is intentionally not shipped until the device and jailbreak ABI are confirmed. Do not install it until the device checklist is completed. A rootful build requires a clean rebuild with `THEOS_PACKAGE_SCHEME` unset and a confirmed rootful jailbreak environment.

## What this can and cannot prove

A successful `.deb` build proves only that the source compiles, links, packages, and contains the intended filter. It does not prove ElleKit/Substrate injection, process loading, jailbreak compatibility, or compatibility with the installed TikTok build.

## Device checklist required before installation

Please report from the device:

- iOS version and hardware/CPU architecture.
- Jailbreak name and version.
- Rootless or rootful package layout.
- Injection framework (ElleKit, Substitute, libhooker, etc.) and version.
- Whether the installed TikTok bundle identifier is `com.zhiliaoapp.musically`.
- TikTok version/build number.
- Whether a test tweak can be installed and whether the device log shows the constructor message.
