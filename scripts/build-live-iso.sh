#!/bin/bash
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

BUILD_MODE="${1:---cached}"
case "$BUILD_MODE" in
    --cached|--clean)
        ;;
    -h|--help)
        cat <<'USAGE'
Uso: scripts/build-live-iso.sh [--cached|--clean]

  --cached  Reconstruye chroot e ISO, conservando caches de descargas. Predeterminado.
  --clean   Elimina tambien todas las caches y descarga todo nuevamente.
USAGE
        exit 0
        ;;
    *)
        echo "[ Condtux ] ERROR: modo desconocido: $BUILD_MODE" >&2
        echo "Uso: scripts/build-live-iso.sh [--cached|--clean]" >&2
        exit 2
        ;;
esac

if [ "$#" -gt 1 ]; then
    echo "[ Condtux ] ERROR: demasiados argumentos." >&2
    exit 2
fi

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
    echo "[ ${PROJECT_NAME} ] No ejecute 'lb build' para reanudar este chroot." >&2
    echo "[ ${PROJECT_NAME} ] Corrija el codigo y use: sudo bash scripts/build-live-iso.sh --cached" >&2
    exit "$status"
}
trap show_failure ERR

echo "[ ${PROJECT_NAME} ] Modo de build: $BUILD_MODE"
echo "[ ${PROJECT_NAME} ] Aplicando version central..."
sh scripts/apply-version.sh

chmod +x scripts/*.sh config/hooks/normal/*.hook.chroot config/hooks/normal/*.hook.binary 2>/dev/null || true

echo "[ ${PROJECT_NAME} ] Validando scripts antes de construir..."
while IFS= read -r script; do
    first_line="$(head -n 1 "$script" 2>/dev/null || true)"
    case "$first_line" in
        '#!'*bash*) bash -n "$script" ;;
        '#!'*) sh -n "$script" ;;
    esac
done < <(find scripts config/hooks/normal config/includes.chroot/usr/local \
    -type f -print 2>/dev/null | sort)

# El antiguo XFCE monolitico y paquetes retirados de trixie no pueden volver a
# entrar como dependencias activas.
if grep -REn --include='*.list.chroot' \
    '^[[:space:]]*condtux-xfce-desktop([[:space:]]|$)' \
    config/package-lists 2>/dev/null; then
    echo "[ ${PROJECT_NAME} ] ERROR: una lista activa contiene condtux-xfce-desktop." >&2
    exit 1
fi

if grep -REn --include='*.hook.chroot' \
    '^[[:space:]]*"?condtux-xfce-desktop"?[[:space:]]*\\?$|apt(-get)?[[:space:]].*install.*condtux-xfce-desktop' \
    config/hooks/normal 2>/dev/null; then
    echo "[ ${PROJECT_NAME} ] ERROR: un hook intenta instalar condtux-xfce-desktop." >&2
    exit 1
fi

if grep -REn --include='*.list.chroot' --include='*.hook.chroot' \
    '^[[:space:]]*policykit-1-gnome[[:space:]]*\\?$' \
    config/package-lists config/hooks/normal 2>/dev/null; then
    echo "[ ${PROJECT_NAME} ] ERROR: policykit-1-gnome no existe en Debian 13 trixie." >&2
    exit 1
fi

# El kernel no debe instalarse durante la transaccion masiva de live-build. Su
# hook dedicado verifica el .deb, los modulos, depmod y el initramfs por etapas.
if grep -REn --include='*.list.chroot' \
    '^[[:space:]]*linux-image(-amd64|-[0-9][^[:space:]]*)[[:space:]]*$' \
    config/package-lists 2>/dev/null; then
    echo "[ ${PROJECT_NAME} ] ERROR: una lista activa instala el kernel fuera del hook controlado." >&2
    exit 1
fi

for required in \
    scripts/validate-built-iso.sh \
    config/package-lists/condtux-base.list.chroot \
    config/package-lists/condtux-installer.list.chroot \
    config/hooks/normal/0070-condtux-kernel-install.hook.chroot \
    config/hooks/normal/0080-condtux-apt-sources.hook.chroot \
    config/hooks/normal/0081-condtux-repo-test.hook.chroot \
    config/hooks/normal/0082-condtux-xfce-live.hook.chroot \
    config/hooks/normal/0083-condtux-kernel-integrity.hook.chroot \
    config/hooks/normal/0090-condtux-live-user.hook.chroot \
    config/hooks/normal/0098-condtux-xfce-account-fix.hook.chroot \
    config/hooks/normal/0099-condtux-final-validation.hook.chroot \
    config/includes.chroot/etc/condtux-version \
    config/includes.chroot/usr/share/keyrings/condtux-archive-keyring.gpg \
    config/includes.chroot/usr/local/sbin/condtux-install \
    config/includes.chroot/usr/local/sbin/condtux-language \
    config/includes.chroot/usr/local/sbin/condtux-live-setup \
    config/includes.chroot/usr/local/sbin/condtux-copy-live-language-target \
    config/includes.chroot/usr/local/bin/condtux-install-gui; do
    if [ ! -s "$required" ]; then
        echo "[ ${PROJECT_NAME} ] ERROR: falta archivo requerido: $required" >&2
        exit 1
    fi
done

# xorriso se mantiene instalado en el builder para poder auditar el catalogo El
# Torito despues de que live-build termine. Si ya estaba instalado, esta etapa no
# realiza cambios.
if ! command -v xorriso >/dev/null 2>&1; then
    echo "[ ${PROJECT_NAME} ] Instalando xorriso en el builder para la validacion UEFI..."
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends xorriso
fi

echo "[ ${PROJECT_NAME} ] Eliminando siempre chroot, binarios y marcadores anteriores..."
sudo lb clean --all || true
sudo rm -rf chroot binary .build

if [ "$BUILD_MODE" = "--clean" ]; then
    echo "[ ${PROJECT_NAME} ] Eliminando tambien todas las caches..."
    sudo rm -rf \
        cache/bootstrap \
        cache/packages.bootstrap \
        cache/packages.chroot \
        cache/packages.binary
else
    echo "[ ${PROJECT_NAME} ] Conservando caches de bootstrap y paquetes descargados."
    # Los archivos parciales nunca deben sobrevivir entre builds.
    if [ -d cache ]; then
        sudo find cache -type f \( -name '*.partial' -o -name '*.FAILED' \) -delete 2>/dev/null || true
    fi
fi

echo "[ ${PROJECT_NAME} ] Borrando binarios ISO viejos..."
rm -f ./*.iso live-image-* binary.* chroot.files chroot.packages.install chroot.packages.live
rm -f output/*.iso output/*.sha256 output/*.uefi-report.txt

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
  --debootstrap-options "--include=ca-certificates,zstd" \
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

# No publicar una imagen si cualquier etapa informa corrupcion de memoria,
# modulos o initramfs, incluso cuando una herramienta devuelve codigo cero.
if grep -Eqi 'depmod: ERROR|File is corrupt|File format not recognized|Unexpected end of input|double free|corruption \(out\)' "$LOG_FILE"; then
    echo "[ ${PROJECT_NAME} ] ERROR: el log contiene errores de integridad del kernel o memoria." >&2
    exit 1
fi

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

if [ -z "$MANIFEST" ]; then
    echo "[ ${PROJECT_NAME} ] ERROR: no se encontro el manifiesto final." >&2
    exit 1
fi

for package in linux-image-amd64 xfce4 xfce4-session xfconf xfce4-settings xfdesktop4 xfwm4 lightdm mate-polkit zstd; do
    if ! grep -q "^${package}[[:space:]]" "$MANIFEST"; then
        echo "[ ${PROJECT_NAME} ] ERROR: falta $package en el manifiesto final." >&2
        exit 1
    fi
done

for forbidden in condtux-xfce-desktop policykit-1-gnome openssh-server apt-listchanges; do
    if grep -q "^${forbidden}[[:space:]]" "$MANIFEST"; then
        echo "[ ${PROJECT_NAME} ] ERROR: paquete prohibido en la ISO final: $forbidden" >&2
        exit 1
    fi
done

echo "[ ${PROJECT_NAME} ] Validando ESP embebida, fallback UEFI y catalogo El Torito..."
bash scripts/validate-built-iso.sh "$ISO_OUTPUT" binary

trap - ERR

echo
echo "[ ${PROJECT_NAME} ] ISO lista y validada:"
ls -lh "$ISO_OUTPUT" "${ISO_OUTPUT}.sha256" "${ISO_OUTPUT}.uefi-report.txt"
echo "[ ${PROJECT_NAME} ] Log: $LOG_FILE"
