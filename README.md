# TikToklookalike-forked

Public analysis and binary distribution for the iOS IPA supplied by the maintainer.

The main app metadata identifies the package as TikTok (`com.zhiliaoapp.musically`), version 39.3.0 (build 393020). The maintainer states that the app is theirs and has directed public distribution; this repository does not independently verify provenance or distribution rights.

- [Download the IPA release (v39.3.0)](https://github.com/perseusV/TikToklookalike-forked/releases/tag/v39.3.0)
- [Read the static analysis](ANALYSIS.md)

The release asset is the supplied IPA without modification. SHA-256: `8b0fcefcb292de833f523395f4976014b300c11eb76cfa93b41baa0ba14b1393`.

## Safety note

Static inspection found `Payload/TikTok.app/SessionCheck.bundle/private_key.p12` (1,525 bytes). Its contents could not be verified using an empty password; treat it as potentially sensitive. The report intentionally does not include its contents. This repository contains no source project or editable app code.
