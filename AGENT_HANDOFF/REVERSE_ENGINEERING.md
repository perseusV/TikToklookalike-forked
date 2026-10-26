# Reverse-engineering record

The original IPA was downloaded from the authenticated GitHub release, hashed, ZIP-tested, and extracted. Property lists were parsed with Python `plistlib`. Executable candidates were identified with `file`; strings were searched only as data; Mach-O headers were parsed with the included Python script. No extracted program or embedded script was executed.

The parser found 27 arm64 files. Every parsed file reported `cryptid=0` in its encryption-info command and a code-signature load command. These are structural indicators only. The app has no embedded provisioning profile, and cryptographic signature verification could not be performed because Apple signing tools are absent.

The original repository's prior `ANALYSIS.md` findings were rechecked against the current release asset. They agree on the bundle identity, version, architecture count, extension inventory, and SHA-256.
