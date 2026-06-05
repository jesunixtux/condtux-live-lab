#!/usr/bin/env bash
set -e

cd "$HOME/condtux-live-lab"

echo "[ Condtux Live 0.3 ] Limpiando build anterior..."
sudo lb clean --purge || true

echo "[ Condtux Live 0.3 ] Borrando cache vieja..."
sudo rm -rf .build chroot binary cache
rm -f *.iso live-image-* binary.*
rm -f output/*.iso

echo "[ Condtux Live 0.3 ] Reconfigurando live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main" \
  --binary-images iso-hybrid \
  --bootloaders "syslinux,grub-efi" \
  --debian-installer live \
  --debian-installer-gui false \
  --iso-volume "CONDTUX03" \
  --iso-application "Condtux 0.3 Minimal Orange" \
  --iso-preparer "Condtux Project" \
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-chroot http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --security true \
  --mirror-chroot-security http://security.debian.org/debian-security \
  --mirror-binary-security http://security.debian.org/debian-security \
  --apt-recommends false \
  --bootappend-live "boot=live components hostname=condtux username=condtux user-fullname=Condtux locales=es_CL.UTF-8 keyboard-layouts=latam timezone=America/Santiago"

echo "[ Condtux Live 0.3 ] Construyendo ISO..."
sudo lb build

mkdir -p output

ISO_FOUND="$(find . -maxdepth 1 -type f \( -name 'live-image-amd64.hybrid.iso' -o -name 'binary.hybrid.iso' -o -name '*.iso' \) | head -n 1)"

if [ -z "$ISO_FOUND" ]; then
    echo "No se encontró ISO generada."
    exit 1
fi

cp -v "$ISO_FOUND" output/condtux-0.3-minimal-orange-amd64.iso

echo
echo "[ Condtux Live 0.3 ] ISO lista:"
ls -lh output/
sha256sum output/condtux-0.3-minimal-orange-amd64.iso | tee output/condtux-0.3-minimal-orange-amd64.iso.sha256
