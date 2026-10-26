#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
THEOS=${THEOS:-/home/ubuntu/workspace/upstream/theos}
export THEOS
export THEOS_PACKAGE_SCHEME=${THEOS_PACKAGE_SCHEME:-rootless}
cd "$ROOT"
make clean || true
make package messages=yes
pkg=$(find packages -maxdepth 1 -type f -name '*.deb' -printf '%p\n' | sort | tail -1)
test -n "$pkg"
sha256sum "$pkg"
dpkg-deb --info "$pkg"
dpkg-deb --contents "$pkg"
