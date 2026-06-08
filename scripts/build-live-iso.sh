#!/usr/bin/env bash
set -e

cd "$HOME/condtux-live-lab"

echo "[ Condtux Live 0.5 ] Limpiando build anterior..."
sudo lb clean --purge || true

echo "[ Condtux Live 0.5 ] Borrando cache vieja..."
sudo rm -rf .build chroot binary cache
rm -f *.iso live-image-* binary.*
rm -f output/*.iso

echo "[ Condtux Live 0.5 ] Reconfigurando live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main" \
  --binary-images iso-hybrid \
  --debian-installer-preseedfile config/includes.installer/condtux.seed \
  --bootloaders "syslinux,grub-efi" \
  --debian-installer true \
  --debian-installer-gui false \
  --iso-volume "CONDTUX05" \
  --iso-application "Condtux 0.5 Minimal Orange" \
  --iso-preparer "Condtux Project" \
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-chroot http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --security true \
  --mirror-chroot-security http://security.debian.org/debian-security \
  --mirror-binary-security http://security.debian.org/debian-security \
  --apt-recommends false \
  --bootappend-install "preseed/file=/cdrom/preseed/condtux.seed" \
  --bootappend-live "boot=live components live-config.username=condtux live-config.user-fullname=Condtux hostname=condtux locales=es_CL.UTF-8 keyboard-layouts=latam timezone=America/Santiago"
echo "[ Condtux Live 0.5 ] Construyendo ISO..."
sudo lb build

mkdir -p output

ISO_FOUND="$(find . -maxdepth 1 -type f \( -name 'live-image-amd64.hybrid.iso' -o -name 'binary.hybrid.iso' -o -name '*.iso' \) | head -n 1)"

if [ -z "$ISO_FOUND" ]; then
    echo "No se encontró ISO generada."
    exit 1
fi

cp -v "$ISO_FOUND" output/condtux-0.5-minimal-orange-amd64.iso

echo
echo "[ Condtux Live 0.5 ] ISO lista:"
ls -lh output/
sha256sum output/condtux-0.5-minimal-orange-amd64.iso | tee output/condtux-0.5-minimal-orange-amd64.iso.sha256
