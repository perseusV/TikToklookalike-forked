# Build environment

The analysis ran on Linux 6.18 x86_64 in the Manus sandbox. Git, GNU binutils, Python 3, ZIP tools, and `file` are available. `xcode-select`, `xcodebuild`, Apple clang, iPhoneOS SDKs, `codesign`, `security`, provisioning profiles, and an iOS simulator are unavailable.

The reusable `evidence/macho_inventory.py` parser reads Mach-O headers without executing extracted binaries. It records architecture, encryption metadata, code-signature load-command ranges, and dylib load commands. It found 27 arm64 Mach-O files; each reports `cryptid=0` in its encryption-info command and has a code-signature load command. This is header evidence only, not cryptographic signature validation.

No IPA executable, embedded script, or binary-provided command was executed. Strings and plist contents were treated as untrusted data.
