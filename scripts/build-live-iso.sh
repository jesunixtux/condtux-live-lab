#!/bin/bash
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -s VERSION ]; then
    echo "[ Condtux ] ERROR: falta el archivo VERSION." >&2
    exit 1
fi

VERSION="$(tr -d '[:space:]' < VERSION)"
VERSION_COMPACT="$(printf '%s' "$VERSION" | tr -d '.')"
PROJECT_NAME="Condtux Live ${VERSION}"
ISO_NAME="condtux-${VERSION}-amd64.iso"
ISO_OUTPUT="output/${ISO_NAME}"

case "$VERSION" in
    ''|*[!0-9.]*|.*|*.)
        echo "[ Condtux ] ERROR: VERSION no es valida: $VERSION" >&2
        exit 1
        ;;
esac

echo "[ ${PROJECT_NAME} ] Aplicando version central..."
scripts/apply-version.sh

echo "[ ${PROJECT_NAME} ] Limpiando build anterior..."
sudo lb clean --all || true
sudo rm -rf cache/bootstrap cache/packages.bootstrap cache/packages.chroot cache/packages.binary

echo "[ ${PROJECT_NAME} ] Borrando binarios ISO viejos..."
rm -f ./*.iso live-image-* binary.* chroot.files chroot.packages.install chroot.packages.live
rm -f output/*.iso output/*.sha256
mkdir -p output logs

echo "[ ${PROJECT_NAME} ] Sincronizando wallpapers..."
scripts/sync-wallpapers.sh

# El wallpaper actual del sistema queda reservado para GRUB.
install -D -m 0644 image/condtux_imagen_system/system_wallpaper_condtux.png \
  config/includes.binary/boot/grub/themes/condtux/background.png

# El escritorio usa image/wallpapers/defaultwallpaper.png, sincronizado arriba.

echo "[ ${PROJECT_NAME} ] Reconfigurando live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main" \
  --binary-images iso-hybrid \
  --bootloaders "syslinux,grub-efi" \
  --debian-installer none \
  --iso-volume "CONDTUX${VERSION_COMPACT}" \
  --iso-application "Condtux ${VERSION} Live" \
  --iso-preparer "Condtux Project" \
  --mirror-bootstrap https://deb.debian.org/debian \
  --mirror-chroot https://deb.debian.org/debian \
  --mirror-binary https://deb.debian.org/debian \
  --security true \
  --mirror-chroot-security https://security.debian.org/debian-security \
  --mirror-binary-security https://security.debian.org/debian-security \
  --debootstrap-options "--include=ca-certificates" \
  --apt-recommends false \
  --bootappend-live "boot=live components live-config.username=condtux live-config.user-fullname=Condtux hostname=condtux locales=en_US.UTF-8 keyboard-layouts=us timezone=America/Santiago"

echo "[ ${PROJECT_NAME} ] Deshabilitando Debian Installer y limpiando residuos..."

if [ -f config/binary ]; then
  sed -i 's#^LB_DEBIAN_INSTALLER=.*#LB_DEBIAN_INSTALLER="none"#' config/binary
  sed -i 's#^LB_DEBIAN_INSTALLER_PRESEEDFILE=.*#LB_DEBIAN_INSTALLER_PRESEEDFILE=""#' config/binary
  sed -i 's#^LB_BOOTAPPEND_INSTALL=.*#LB_BOOTAPPEND_INSTALL=""#' config/binary
  sed -i 's#^LB_UEFI_SECURE_BOOT=.*#LB_UEFI_SECURE_BOOT="false"#' config/binary
  sed -i 's#preseed/file=/preseed.cfg file=/cdrom/install/config/includes.installer/condtux.seed#preseed/file=/preseed.cfg#g' config/binary
  sed -i 's# file=/cdrom/install/config/includes.installer/condtux.seed##g' config/binary
fi

echo "[ ${PROJECT_NAME} ] Configuracion final del instalador Debian:"
grep "LB_DEBIAN_INSTALLER" config/binary || true

echo "[ ${PROJECT_NAME} ] Construyendo ISO..."
sudo lb build

mkdir -p output
ISO_FOUND="$(find . -maxdepth 1 -type f \( -name 'live-image-amd64.hybrid.iso' -o -name 'binary.hybrid.iso' -o -name '*.iso' \) | head -n 1)"

if [ -z "$ISO_FOUND" ]; then
    echo "[ ${PROJECT_NAME} ] ERROR: no se encontro la ISO generada." >&2
    exit 1
fi

cp -v "$ISO_FOUND" "$ISO_OUTPUT"

echo
echo "[ ${PROJECT_NAME} ] ISO lista:"
ls -lh output/
sha256sum "$ISO_OUTPUT" | tee "${ISO_OUTPUT}.sha256"
