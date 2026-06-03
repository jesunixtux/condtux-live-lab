#!/usr/bin/env bash
set -e

cd "$HOME/condtux-live-lab"

echo "[ Condtux Live ] Limpiando build anterior..."
sudo lb clean --purge || true

echo "[ Condtux Live ] Borrando cache vieja..."
sudo rm -rf .build chroot binary cache
rm -f *.iso live-image-* binary.*
rm -f output/*.iso

echo "[ Condtux Live ] Reconfigurando live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main" \
  --binary-images iso-hybrid \
  --debian-installer live \
  --debian-installer-gui false \
  --mirror-bootstrap https://deb.debian.org/debian \
  --mirror-chroot https://deb.debian.org/debian \
  --mirror-binary https://deb.debian.org/debian \
  --security true \
  --mirror-chroot-security https://security.debian.org/debian-security \
  --mirror-binary-security https://security.debian.org/debian-security \
  --apt-recommends false \
  --bootappend-live "boot=live components hostname=condtux username=condtux locales=es_CL.UTF-8 keyboard-layouts=latam timezone=America/Santiago"

echo "[ Condtux Live ] Construyendo ISO..."
sudo lb build

mkdir -p output

ISO_FOUND="$(find . -maxdepth 1 -type f \( -name 'live-image-amd64.hybrid.iso' -o -name 'binary.hybrid.iso' -o -name '*.iso' \) | head -n 1)"

if [ -z "$ISO_FOUND" ]; then
    echo "No se encontró ISO generada."
    exit 1
fi

cp -v "$ISO_FOUND" output/condtux-0.1-live-amd64.iso

echo
echo "[ Condtux Live ] ISO lista:"
ls -lh output/
