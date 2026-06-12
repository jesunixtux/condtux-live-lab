#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/image/wallpapers"
DST="$ROOT/config/includes.chroot/usr/share/backgrounds/condtux"

if [ ! -f "$SRC/defaultwallpaper.png" ]; then
    echo "[ Condtux ] ERROR: falta $SRC/defaultwallpaper.png" >&2
    exit 1
fi

mkdir -p "$DST"
rsync -a --delete "$SRC/" "$DST/"

echo "[ Condtux ] Wallpapers sincronizados en config/includes.chroot/usr/share/backgrounds/condtux"
