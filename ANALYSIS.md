# Static Analysis Findings — Supplied iOS IPA

## Executive summary

The supplied archive is a compiled iOS application bundle whose main metadata identifies the app as **TikTok**, not as a source project or a separate TikTok-like application. Its bundle identifier is `com.zhiliaoapp.musically`; the bundle reports version `39.3.0` (build `393020`). This report covers static archive inspection only. It does not establish provenance, authorization to redistribute, safety, or runtime behavior.

**Do not publish the IPA as-is without reviewing distribution rights and the embedded `private_key.p12` file described below.** This report does not include the IPA or any key/certificate contents.

## Artifact integrity and identity

- Original filename: `f67ccdbb3d086642301f1cfceea333e260186949(8).ipa`
- Size: 305,079,477 bytes (about 291 MiB)
- SHA-256: `8b0fcefcb292de833f523395f4976014b300c11eb76cfa93b41baa0ba14b1393`
- ZIP integrity test: passed
- Archive entries: 5,620; total uncompressed size: 500,867,073 bytes
- Main bundle path: `Payload/TikTok.app`
- Bundle identifier: `com.zhiliaoapp.musically`
- Main executable: `TikTok`
- App version/build: `39.3.0` / `393020`
- Minimum OS in the main app plist: iOS 13.0
- Build SDK metadata: `iphoneos18.1`
- Device family metadata: iPhone and iPad

## Decryption / architecture indicators

Static parsing found **27 Mach-O executables/libraries**, all `arm64`. Each contains an `LC_ENCRYPTION_INFO`/`LC_ENCRYPTION_INFO_64` command with `cryptid = 0`, which is consistent with those Mach-O binaries not being FairPlay-encrypted. This is a binary-header check; it is not a complete determination of every file's contents or a runtime test.

The largest individual file is `Payload/TikTok.app/Frameworks/MusicallyCore.framework/MusicallyCore` (376,342,512 bytes uncompressed).

## App extensions

Seven app-extension bundles were identified:

| Extension | Bundle identifier | Version | Minimum iOS |
|---|---|---:|---:|
| AwemeNotificationService | `com.zhiliaoapp.musically.PushNotificationAttachment` | 39.3.0 | 12.0 |
| TikTokIntentExtension | `com.zhiliaoapp.musically.IntentExtension` | 39.3.0 | 13.0 |
| TikTokMessageExtension | `com.zhiliaoapp.musically.imessage` | 39.3.0 | 13.0 |
| AwemeWidgetExtension | `com.zhiliaoapp.musically.TTWidgetExtension` | 39.3.0 | 14.0 |
| AwemeShareExtension | `com.zhiliaoapp.musically.ShareExtension` | 39.3.0 | 12.0 |
| AWEVideoWidget | `com.zhiliaoapp.musically.TodayWidget` | 39.3.0 | 12.0 |
| AwemeBroadcastExtension | `com.zhiliaoapp.musically.VideoBroadcastExtension1` | 39.3.0 | 12.0 |

## Privacy-manifest inventory

The archive contains 36 parseable `.xcprivacy` manifests. Across those manifests, declarations were found for these Required Reason API categories:

- File timestamp: 13 declarations
- User defaults: 14 declarations
- System boot time: 10 declarations
- Disk space: 11 declarations
- Active keyboards: 9 declarations

Eight distinct tracking-domain strings were present across the parsed manifests. These are **manifest declarations**, not evidence of actual runtime access, tracking behavior, or a complete privacy assessment.

## Sensitive-file warning

The archive contains:

`Payload/TikTok.app/SessionCheck.bundle/private_key.p12` (1,525 bytes)

An OpenSSL check using an empty password could not parse it (`Mac verify error: invalid password?`). Its contents therefore remain unverified. The filename suggests it may contain private-key material, but this inspection did **not** establish what it contains. Treat it as potentially sensitive; do not publish or extract it for public analysis until the owner has independently reviewed it. The report intentionally excludes its contents.

No `embedded.mobileprovision` file was found. Code-resource signature files are present, but the app's code signature was not cryptographically verified; static inspection does not establish that the decrypted package is installable or signature-valid.

## Limitations and safe handling

This was static inspection of ZIP structure, plist metadata, Mach-O headers, and privacy manifests. The app was not installed or executed; no dynamic traffic, behavior, malware, or vulnerability assessment was performed. No source project was present in the archive. This report alone does not grant rights to redistribute TikTok software or its bundled components. Keep the binary private unless you have the right to distribute it and have resolved the `private_key.p12` warning.
