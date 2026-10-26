# Jailbreak tweak toolchain record

## Ubuntu environment

The build host is Ubuntu 24.04.5 LTS, x86_64. Installed standard prerequisites include Ubuntu Clang 18.1.3, LLVM, GNU Make 4.3, Perl, rsync, xz-utils, dpkg-dev, pkg-config, and dpkg-deb 1.22.6. The package installation log is at `/home/ubuntu/workspace/logs/apt_tweak_prereqs.log`.

## Theos

Source: https://github.com/theos/theos

The cloned upstream revision is `304e0799973e8145f32e4ca2de6c747a84b758ce`. Theos documentation states that Linux builds can target iOS, that SDKs live under `$THEOS/sdks`, and that rootless packages use `THEOS_PACKAGE_SCHEME=rootless` with package architecture `iphoneos-arm64`.

## Official Theos SDK release

Source: https://github.com/theos/sdks/releases/latest

The latest upstream release observed was `master-146e41f`, published 2023-11-23. It provides iPhoneOS 10.3, 11.4, 12.4, 13.7, 14.5, 15.6, and 16.5 SDK archives. No proprietary SDK was downloaded from an unverified source.

## ldid

Source: https://github.com/ProcursusTeam/ldid/releases/latest

The observed release was `v2.1.5-procursus7`. The official `ldid_linux_x86_64` asset was installed at `/usr/local/bin/ldid`. SHA-256: `4b8862b2fefa2cd7fa8f88cb0310779619aeaa8c72d6aff22f019b470f2fa99a`.

## ElleKit

Source: https://github.com/tealbathingsuit/ellekit

The cloned upstream revision is `1017a0d09606ea49ba8bc4d6cccc530d372e640e`. Its README states that ElleKit requires an arm64 iOS device for runtime use, and its build instructions require Xcode 14 for the dynamic library. Therefore ElleKit cannot be built or runtime-tested on this Linux host; only its source and packaging layout were inspected.

## Important limitation

A Theos source build and `.deb` package can be prepared on Ubuntu if a compatible SDK and cross-toolchain are present. Successful compilation or packaging does not prove that the tweak injects into the user's jailbreak, app process, or broadcast extension. Device jailbreak, iOS version, architecture, injection framework, rootful/rootless mode, and installed app version remain unverified until the user supplies device-side facts.
