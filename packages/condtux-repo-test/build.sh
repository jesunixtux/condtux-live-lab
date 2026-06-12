#!/bin/sh
set -eu

VERSION="0.8.0"
ARCH="amd64"
PKG="condtux-repo-test"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build/${PKG}_${VERSION}_${ARCH}"
OUT_DIR="$ROOT/dist"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN" "$BUILD_DIR/usr/bin" "$BUILD_DIR/usr/share/doc/$PKG" "$OUT_DIR"

cat > "$BUILD_DIR/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: Condtux Project <support@jeval.cl>
Depends: bash, apt
Description: Condtux repository test command
 Small command used to verify that repo-condtux.jeval.cl can publish
 and install Condtux packages through APT.
EOF

install -m 0755 "$ROOT/src/condtux-repo-test" "$BUILD_DIR/usr/bin/condtux-repo-test"
install -m 0644 "$ROOT/src/README" "$BUILD_DIR/usr/share/doc/$PKG/README"

dpkg-deb --build --root-owner-group "$BUILD_DIR" "$OUT_DIR/${PKG}_${VERSION}_${ARCH}.deb"
