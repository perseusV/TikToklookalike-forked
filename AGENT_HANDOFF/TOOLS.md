# Tools and commands

Available tools used: Git 2.x, GitHub CLI 2.103.2, Python 3, GNU `file`, `strings`, `nm`, `unzip`, `zip`, `sha256sum`, and a repository-local Python Mach-O header parser. The IPA was retrieved with `gh release download`, verified with `sha256sum`, tested with `unzip -tq`, and extracted with `unzip`.

The repository-local parser is `evidence/macho_inventory.py`. It does not execute any extracted file. It records Mach-O architecture, encryption-info fields, code-signature command ranges, and dynamic library load commands.

Unavailable: Xcode, xcodebuild, iPhoneOS SDK, Apple clang, codesign, security, provisioning profiles, and iOS simulator. No unverified external binary tools were installed.
