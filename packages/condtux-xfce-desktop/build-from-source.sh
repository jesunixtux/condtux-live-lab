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
DEB_HOST_MULTIARCH="${DEB_HOST_MULTIARCH:-$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || printf 'x86_64-linux-gnu')}"
LIBDIR="/usr/lib/$DEB_HOST_MULTIARCH"

MODULES="
libxfce4util
xfconf
libxfce4ui
garcon
exo
libxfce4windowing
thunar
thunar-volman
xfce4-panel
xfce4-power-manager
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
need_cmd dpkg-architecture

rm -rf "$WORK" "$BUILD_ROOT"
mkdir -p "$ARCHIVES" "$SOURCES" "$STAGE" "$BUILD_ROOT" "$OUT_DIR"

export PKG_CONFIG_PATH="$STAGE$LIBDIR/pkgconfig:$STAGE/usr/lib/pkgconfig:$STAGE/usr/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export LD_LIBRARY_PATH="$STAGE$LIBDIR:$STAGE/usr/lib:${LD_LIBRARY_PATH:-}"
export GI_TYPELIB_PATH="$STAGE$LIBDIR/girepository-1.0:${GI_TYPELIB_PATH:-}"
export XDG_DATA_DIRS="$STAGE/usr/share:/usr/local/share:/usr/share"
export ACLOCAL_PATH="$STAGE/usr/share/aclocal:${ACLOCAL_PATH:-}"
export CPPFLAGS="-I$STAGE/usr/include ${CPPFLAGS:-}"
export CFLAGS="${CFLAGS:--O0 -g0}"
export CXXFLAGS="${CXXFLAGS:--O0 -g0}"
export LDFLAGS="-L$STAGE$LIBDIR -L$STAGE/usr/lib ${LDFLAGS:-}"
export PATH="$STAGE/usr/bin:$PATH"

prepare_staged_metadata() {
    find "$STAGE" -name '*.la' -delete

    find "$STAGE" -path '*/pkgconfig/*.pc' -type f -print | while read -r pc_file; do
        sed -i "s#^prefix=/usr#prefix=$STAGE/usr#" "$pc_file"
        sed -i "s#^exec_prefix=/usr#exec_prefix=$STAGE/usr#" "$pc_file"
    done
}

prune_development_files() {
    rm -rf \
        "$BUILD_ROOT/usr/include" \
        "$BUILD_ROOT/usr/share/gir-1.0" \
        "$BUILD_ROOT/usr/share/gtk-doc" \
        "$BUILD_ROOT$LIBDIR/pkgconfig" \
        "$BUILD_ROOT/usr/lib/pkgconfig"

    find "$BUILD_ROOT" -name '*.la' -delete
    find "$BUILD_ROOT" -name '*.a' -delete
}

configure_args_for() {
    case "$1" in
        libxfce4ui)
            printf '%s\n' '--enable-x11 --enable-wayland --disable-gladeui2'
            ;;
        libxfce4windowing)
            printf '%s\n' '--enable-x11 --enable-wayland'
            ;;
        xfce4-settings)
            printf '%s\n' '--enable-x11 --enable-wayland --enable-upower-glib --enable-colord'
            ;;
        tumbler)
            printf '%s\n' '--disable-cover-thumbnailer --disable-ffmpeg-thumbnailer --disable-gstreamer-thumbnailer --disable-odf-thumbnailer --disable-poppler-thumbnailer --disable-raw-thumbnailer --disable-gepub-thumbnailer'
            ;;
    esac
}

echo "[ Condtux XFCE ] Descargando $URL"
curl -fL --proto '=https' --tlsv1.2 "$URL" -o "$ARCHIVES/xfce-${XFCE_VERSION}.tar.bz2"

echo "[ Condtux XFCE ] Extrayendo tarball oficial..."
tar -xf "$ARCHIVES/xfce-${XFCE_VERSION}.tar.bz2" -C "$ARCHIVES"

build_module() {
    module="$1"
    tarball="$(find "$ARCHIVES" -type f -name "${module}-[0-9]*.tar.*" | sort -V | tail -n 1)"

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
        module_configure_args="$(configure_args_for "$module")"

        if [ -x ./configure ]; then
            ./configure --prefix=/usr --sysconfdir=/etc --libdir="$LIBDIR" --libexecdir=/usr/lib --disable-debug $module_configure_args
            make -j "$JOBS"
            make DESTDIR="$STAGE" install
        elif [ -x ./autogen.sh ]; then
            ./autogen.sh --prefix=/usr --sysconfdir=/etc --libdir="$LIBDIR" --libexecdir=/usr/lib --disable-debug $module_configure_args
            make -j "$JOBS"
            make DESTDIR="$STAGE" install
        elif [ -f meson.build ]; then
            need_cmd meson
            need_cmd ninja
            meson setup --prefix=/usr --sysconfdir=/etc --libdir="$LIBDIR" --libexecdir=/usr/lib build -Ddebug=false
            ninja -C build -j "$JOBS"
            DESTDIR="$STAGE" ninja -C build install
        else
            echo "[ Condtux XFCE ] ERROR: $module no tiene meson.build, configure ni autogen.sh" >&2
            exit 1
        fi
    )

    prepare_staged_metadata
}

for module in $MODULES; do
    build_module "$module"
done

mkdir -p "$BUILD_ROOT/DEBIAN"
cp -a "$STAGE/." "$BUILD_ROOT/"
prune_development_files

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
Depends: libatk1.0-0t64, libc6, libcairo2, libcairo-gobject2, libcolord2, libdbusmenu-gtk3-4, libdisplay-info2, libepoxy0, libexif12, libfontconfig1, libfreetype6, libgdk-pixbuf-2.0-0, libglib2.0-0t64, libgtk-3-0t64, libgtk-layer-shell0, libgtop-2.0-11, libgudev-1.0-0, libice6, libjpeg62-turbo, libnotify4, libpango-1.0-0, libpangocairo-1.0-0, libpcre2-8-0, libpng16-16t64, libpolkit-gobject-1-0, libsm6, libstartup-notification0, libupower-glib3, libwayland-client0, libwnck-3-0, libx11-6, libxcomposite1, libxcursor1, libxdamage1, libxext6, libxfixes3, libxi6, libxinerama1, libxklavier16, libxpresent1, libxrandr2, libxrender1, libxres1, libyaml-0-2, dbus-x11, hicolor-icon-theme, shared-mime-info, xdg-utils
Description: Condtux XFCE desktop built from upstream Xfce source
 Monolithic Condtux XFCE desktop package built from the official upstream
 Xfce ${XFCE_VERSION} source collection. This package is intended to be
 published in repo-condtux.jeval.cl and consumed by the Condtux Live ISO.
EOF

dpkg-deb --build --root-owner-group "$BUILD_ROOT" "$OUT_DIR/${PKG}_${PKG_VERSION}_${ARCH}.deb"

echo "[ Condtux XFCE ] Paquete listo: $OUT_DIR/${PKG}_${PKG_VERSION}_${ARCH}.deb"
