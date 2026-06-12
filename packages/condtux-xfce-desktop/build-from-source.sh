#!/bin/sh
set -eu

XFCE_VERSION="${XFCE_VERSION:-4.20}"
PKG_VERSION="${PKG_VERSION:-0.8.0}"
ARCH="${ARCH:-amd64}"
PKG="condtux-xfce-desktop"
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/build/work"
ARCHIVES="$WORK/archives"
SOURCES="$WORK/sources"
STAGE="$WORK/stage"
BUILD_ROOT="$ROOT/build/${PKG}_${PKG_VERSION}_${ARCH}"
OUT_DIR="$ROOT/dist"
URL="https://archive.xfce.org/xfce/${XFCE_VERSION}/fat_tarballs/xfce-${XFCE_VERSION}.tar.bz2"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')}"

MODULES="
libxfce4util
xfconf
libxfce4ui
garcon
exo
thunar
xfce4-panel
xfce4-settings
xfce4-session
xfdesktop
xfwm4
xfce4-appfinder
tumbler
"

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Falta comando requerido: $1" >&2
        exit 1
    fi
}

need_cmd curl
need_cmd tar
need_cmd make
need_cmd dpkg-deb

rm -rf "$WORK" "$BUILD_ROOT"
mkdir -p "$ARCHIVES" "$SOURCES" "$STAGE" "$BUILD_ROOT" "$OUT_DIR"

echo "[ Condtux XFCE ] Descargando $URL"
curl -fL --proto '=https' --tlsv1.2 "$URL" -o "$ARCHIVES/xfce-${XFCE_VERSION}.tar.bz2"

echo "[ Condtux XFCE ] Extrayendo tarball oficial..."
tar -xf "$ARCHIVES/xfce-${XFCE_VERSION}.tar.bz2" -C "$ARCHIVES"

build_module() {
    module="$1"
    tarball="$(find "$ARCHIVES" -type f -name "${module}-*.tar.*" | sort -V | tail -n 1)"

    if [ -z "$tarball" ]; then
        echo "[ Condtux XFCE ] ERROR: no se encontro tarball para $module" >&2
        exit 1
    fi

    echo "[ Condtux XFCE ] Compilando $module desde $(basename "$tarball")"
    rm -rf "$SOURCES/$module"
    mkdir -p "$SOURCES/$module"
    tar -xf "$tarball" -C "$SOURCES/$module" --strip-components=1

    (
        cd "$SOURCES/$module"

        if [ -f meson.build ]; then
            need_cmd meson
            need_cmd ninja
            meson setup --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib build -Ddebug=false
            ninja -C build -j "$JOBS"
            DESTDIR="$STAGE" ninja -C build install
        elif [ -x ./configure ]; then
            ./configure --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib --disable-debug
            make -j "$JOBS"
            make DESTDIR="$STAGE" install
        elif [ -x ./autogen.sh ]; then
            ./autogen.sh --prefix=/usr --sysconfdir=/etc --libexecdir=/usr/lib --disable-debug
            make -j "$JOBS"
            make DESTDIR="$STAGE" install
        else
            echo "[ Condtux XFCE ] ERROR: $module no tiene meson.build, configure ni autogen.sh" >&2
            exit 1
        fi
    )
}

for module in $MODULES; do
    build_module "$module"
done

mkdir -p "$BUILD_ROOT/DEBIAN"
cp -a "$STAGE/." "$BUILD_ROOT/"

mkdir -p "$BUILD_ROOT/usr/share/doc/$PKG" "$BUILD_ROOT/usr/share/xsessions"

cat > "$BUILD_ROOT/usr/share/xsessions/condtux-xfce.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Name=Condtux XFCE
Comment=Condtux desktop session
Exec=startxfce4
TryExec=startxfce4
Type=Application
DesktopNames=XFCE
EOF

cat > "$BUILD_ROOT/usr/share/doc/$PKG/README" <<EOF
Condtux XFCE desktop package built from the official Xfce ${XFCE_VERSION} source tarball.
Source: ${URL}
EOF

cat > "$BUILD_ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $PKG_VERSION
Section: x11
Priority: optional
Architecture: $ARCH
Maintainer: Condtux Project <support@jeval.cl>
Depends: libc6, libglib2.0-0t64 | libglib2.0-0, libgtk-3-0t64 | libgtk-3-0, libgdk-pixbuf-2.0-0, libcairo2, libpango-1.0-0, libwnck-3-0, libx11-6, libxext6, dbus-x11
Description: Condtux XFCE desktop built from upstream Xfce source
 Monolithic Condtux XFCE desktop package built from the official upstream
 Xfce ${XFCE_VERSION} source collection. This package is intended to be
 published in repo-condtux.jeval.cl and consumed by the Condtux Live ISO.
EOF

dpkg-deb --build --root-owner-group "$BUILD_ROOT" "$OUT_DIR/${PKG}_${PKG_VERSION}_${ARCH}.deb"

echo "[ Condtux XFCE ] Paquete listo: $OUT_DIR/${PKG}_${PKG_VERSION}_${ARCH}.deb"
