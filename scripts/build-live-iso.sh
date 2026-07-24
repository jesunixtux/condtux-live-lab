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
BOOT_PARAMETERS="boot=live components live-config.username=condtux live-config.user-fullname=Condtux hostname=condtux locales=en_US.UTF-8 keyboard-layouts=us timezone=America/Santiago quiet loglevel=3 systemd.show_status=false rd.systemd.show_status=false vt.global_cursor_default=0"
BUILD_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="logs/condtux-${VERSION}-${BUILD_STAMP}.log"

case "$VERSION" in
    ''|*[!0-9.]*|.*|*.)
        echo "[ Condtux ] ERROR: VERSION no es valida: $VERSION" >&2
        exit 1
        ;;
esac

mkdir -p output logs

show_failure() {
    status=$?
    echo >&2
    echo "[ ${PROJECT_NAME} ] ERROR: la build fallo con codigo $status." >&2
    echo "[ ${PROJECT_NAME} ] Log completo: $LOG_FILE" >&2
    if [ -s "$LOG_FILE" ]; then
        echo "[ ${PROJECT_NAME} ] Ultimas 80 lineas:" >&2
        tail -n 80 "$LOG_FILE" >&2 || true
    fi
    exit "$status"
}
trap show_failure ERR

echo "[ ${PROJECT_NAME} ] Aplicando version central..."
sh scripts/apply-version.sh

chmod +x config/hooks/normal/*.hook.chroot config/hooks/normal/*.hook.binary 2>/dev/null || true

# Fallar antes de iniciar live-build si un hook tiene sintaxis invalida o si el
# antiguo paquete XFCE monolitico reaparece en la receta activa.
echo "[ ${PROJECT_NAME} ] Validando scripts antes de construir..."
for script in scripts/*.sh config/hooks/normal/*.hook.chroot config/hooks/normal/*.hook.binary; do
    [ -f "$script" ] || continue
    case "$(head -n 1 "$script" 2>/dev/null || true)" in
        *bash*) bash -n "$script" ;;
        *) sh -n "$script" ;;
    esac
done

if grep -RIn --include='*.hook.chroot' \
    'apt-get.*condtux-xfce-desktop\|^[[:space:]]*"\?condtux-xfce-desktop[[:space:]]*\\' \
    config/hooks/normal 2>/dev/null; then
    echo "[ ${PROJECT_NAME} ] ERROR: un hook activo intenta instalar el paquete XFCE monolitico antiguo." >&2
    exit 1
fi

echo "[ ${PROJECT_NAME} ] Limpiando build anterior..."
sudo lb clean --all || true
sudo rm -rf \
    cache/bootstrap \
    cache/packages.bootstrap \
    cache/packages.chroot \
    cache/packages.binary \
    chroot \
    binary \
    .build

echo "[ ${PROJECT_NAME} ] Borrando binarios ISO viejos..."
rm -f ./*.iso live-image-* binary.* chroot.files chroot.packages.install chroot.packages.live
rm -f output/*.iso output/*.sha256

echo "[ ${PROJECT_NAME} ] Sincronizando wallpapers..."
scripts/sync-wallpapers.sh

install -D -m 0644 image/condtux_imagen_system/system_wallpaper_condtux.png \
  config/includes.binary/boot/grub/themes/condtux/background.png

echo "[ ${PROJECT_NAME} ] Reconfigurando live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main non-free-firmware" \
  --binary-images iso-hybrid \
  --bootloaders "syslinux,grub-efi" \
  --debian-installer none \
  --uefi-secure-boot enable \
  --compression xz \
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
  --bootappend-live "$BOOT_PARAMETERS"

echo "[ ${PROJECT_NAME} ] Ajustando configuracion final..."
if [ -f config/bootstrap ]; then
  sed -i 's#^LB_ARCHIVE_AREAS=.*#LB_ARCHIVE_AREAS="main non-free-firmware"#' config/bootstrap
  sed -i 's#^LB_PARENT_ARCHIVE_AREAS=.*#LB_PARENT_ARCHIVE_AREAS="main non-free-firmware"#' config/bootstrap
fi

if [ -f config/binary ]; then
  sed -i 's#^LB_DEBIAN_INSTALLER=.*#LB_DEBIAN_INSTALLER="none"#' config/binary
  sed -i 's#^LB_DEBIAN_INSTALLER_PRESEEDFILE=.*#LB_DEBIAN_INSTALLER_PRESEEDFILE=""#' config/binary
  sed -i 's#^LB_BOOTAPPEND_INSTALL=.*#LB_BOOTAPPEND_INSTALL=""#' config/binary
  sed -i 's#^LB_UEFI_SECURE_BOOT=.*#LB_UEFI_SECURE_BOOT="enable"#' config/binary
  sed -i 's#^LB_COMPRESSION=.*#LB_COMPRESSION="xz"#' config/binary
  sed -i "s#^LB_BOOTAPPEND_LIVE=.*#LB_BOOTAPPEND_LIVE=\"${BOOT_PARAMETERS}\"#" config/binary
fi

echo "[ ${PROJECT_NAME} ] Areas APT activas:"
grep -E '^LB_(PARENT_)?ARCHIVE_AREAS=' config/bootstrap || true

echo "[ ${PROJECT_NAME} ] Construyendo ISO..."
sudo lb build 2>&1 | tee "$LOG_FILE"

ISO_FOUND="$(find . -maxdepth 1 -type f \( -name 'live-image-amd64.hybrid.iso' -o -name 'binary.hybrid.iso' -o -name '*.iso' \) | head -n 1)"

if [ -z "$ISO_FOUND" ] || [ ! -s "$ISO_FOUND" ]; then
    echo "[ ${PROJECT_NAME} ] ERROR: no se encontro una ISO valida." >&2
    exit 1
fi

cp -v "$ISO_FOUND" "$ISO_OUTPUT"

MANIFEST=""
for candidate in chroot.packages.live binary/live/filesystem.packages; do
    if [ -s "$candidate" ]; then
        MANIFEST="$candidate"
        break
    fi
done

if [ -n "$MANIFEST" ]; then
    for package in xfce4 xfce4-session xfconf xfce4-settings xfdesktop4 xfwm4 lightdm; do
        if ! grep -q "^${package}[[:space:]]" "$MANIFEST"; then
            echo "[ ${PROJECT_NAME} ] ERROR: falta $package en el manifiesto final." >&2
            exit 1
        fi
    done

    if grep -q '^condtux-xfce-desktop[[:space:]]' "$MANIFEST"; then
        echo "[ ${PROJECT_NAME} ] ERROR: la ISO final todavia contiene el paquete XFCE monolitico antiguo." >&2
        exit 1
    fi
fi

if command -v xorriso >/dev/null 2>&1; then
    if ! xorriso -indev "$ISO_OUTPUT" -find /EFI/BOOT/BOOTX64.EFI -print 2>/dev/null | \
         grep -q '/EFI/BOOT/BOOTX64.EFI'; then
        echo "[ ${PROJECT_NAME} ] ERROR: falta la ruta UEFI fallback EFI/BOOT/BOOTX64.EFI." >&2
        exit 1
    fi
fi

sha256sum "$ISO_OUTPUT" | tee "${ISO_OUTPUT}.sha256"
trap - ERR

echo
echo "[ ${PROJECT_NAME} ] ISO lista y validada:"
ls -lh "$ISO_OUTPUT" "${ISO_OUTPUT}.sha256"
echo "[ ${PROJECT_NAME} ] Log: $LOG_FILE"