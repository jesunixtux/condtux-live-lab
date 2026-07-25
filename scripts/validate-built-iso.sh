#!/bin/bash
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -s VERSION ]; then
    echo "[ Condtux ] ERROR: falta VERSION." >&2
    exit 1
fi

VERSION="$(tr -d '[:space:]' < VERSION)"
ISO_PATH="${1:-output/condtux-${VERSION}-amd64.iso}"
BINARY_DIR="${2:-binary}"
REPORT_PATH="${ISO_PATH}.uefi-report.txt"
TMP_ROOT="$(mktemp -d /tmp/condtux-uefi-check.XXXXXX)"
EFI_MOUNT="$TMP_ROOT/esp"
EFI_IMAGE=""
MOUNTED=0

cleanup() {
    set +e
    if [ "$MOUNTED" -eq 1 ]; then
        sudo umount "$EFI_MOUNT" >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

if [ ! -s "$ISO_PATH" ]; then
    echo "[ Condtux ] ERROR: ISO ausente o vacia: $ISO_PATH" >&2
    exit 1
fi

# live-build guarda el entorno EFI como una imagen FAT. Se prefiere el archivo
# original del arbol binary porque evita tener que extraerlo otra vez de la ISO.
for candidate in \
    "$BINARY_DIR/boot/grub/efi.img" \
    "$BINARY_DIR/EFI/boot/efi.img"; do
    if [ -s "$candidate" ]; then
        EFI_IMAGE="$candidate"
        break
    fi
done

if [ -z "$EFI_IMAGE" ]; then
    EFI_IMAGE="$TMP_ROOT/efi.img"

    if command -v xorriso >/dev/null 2>&1; then
        xorriso -osirrox on -indev "$ISO_PATH" \
            -extract /boot/grub/efi.img "$EFI_IMAGE" >/dev/null 2>&1 || true
    elif command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xOf "$ISO_PATH" boot/grub/efi.img > "$EFI_IMAGE" 2>/dev/null || true
    fi
fi

if [ ! -s "$EFI_IMAGE" ]; then
    echo "[ Condtux ] ERROR: no se encontro la imagen FAT EFI boot/grub/efi.img." >&2
    echo "[ Condtux ] La ISO no puede aprobarse como UEFI hasta encontrar su ESP embebida." >&2
    exit 1
fi

mkdir -p "$EFI_MOUNT"
if ! sudo mount -o loop,ro "$EFI_IMAGE" "$EFI_MOUNT"; then
    echo "[ Condtux ] ERROR: no se pudo montar la imagen EFI: $EFI_IMAGE" >&2
    exit 1
fi
MOUNTED=1

BOOTX64="$(find "$EFI_MOUNT/EFI/BOOT" -maxdepth 1 -type f -iname 'BOOTX64.EFI' -print -quit 2>/dev/null || true)"
GRUBX64="$(find "$EFI_MOUNT/EFI/BOOT" -maxdepth 1 -type f -iname 'GRUBX64.EFI' -print -quit 2>/dev/null || true)"

if [ -z "$BOOTX64" ] || [ ! -s "$BOOTX64" ]; then
    echo "[ Condtux ] ERROR: la ESP embebida no contiene EFI/BOOT/BOOTX64.EFI." >&2
    find "$EFI_MOUNT" -maxdepth 4 -type f -printf '  %P\n' >&2 || true
    exit 1
fi

if [ -z "$GRUBX64" ] || [ ! -s "$GRUBX64" ]; then
    echo "[ Condtux ] ERROR: la ESP embebida no contiene EFI/BOOT/grubx64.efi." >&2
    find "$EFI_MOUNT/EFI/BOOT" -maxdepth 1 -type f -printf '  %f\n' >&2 || true
    exit 1
fi

BOOTX64_SIZE="$(stat -c '%s' "$BOOTX64")"
GRUBX64_SIZE="$(stat -c '%s' "$GRUBX64")"

sudo umount "$EFI_MOUNT"
MOUNTED=0

# Comprueba que la ISO referencia la imagen EFI como entrada de arranque El
# Torito. El informe se guarda junto a la ISO para auditoria.
if command -v xorriso >/dev/null 2>&1; then
    xorriso -indev "$ISO_PATH" \
        -report_el_torito plain \
        -report_system_area plain >"$REPORT_PATH" 2>&1

    if ! grep -Eqi 'El Torito boot img.*(UEFI|EFI)|boot/grub/efi\.img' "$REPORT_PATH"; then
        echo "[ Condtux ] ERROR: xorriso no detecto una entrada de arranque EFI en la ISO." >&2
        cat "$REPORT_PATH" >&2
        exit 1
    fi
else
    printf '%s\n' \
        "xorriso no estaba disponible; se valido la ESP embebida, pero no el catalogo El Torito." \
        > "$REPORT_PATH"
    echo "[ Condtux ] ADVERTENCIA: instale xorriso para auditar tambien El Torito." >&2
fi

printf '%s\n' \
    "ISO=$ISO_PATH" \
    "EFI_IMAGE=$EFI_IMAGE" \
    "FALLBACK=EFI/BOOT/BOOTX64.EFI ($BOOTX64_SIZE bytes)" \
    "GRUB=EFI/BOOT/grubx64.efi ($GRUBX64_SIZE bytes)" \
    "RESULT=OK" >> "$REPORT_PATH"

sha256sum "$ISO_PATH" | tee "${ISO_PATH}.sha256"

echo "[ Condtux ] ISO UEFI validada correctamente."
echo "[ Condtux ] Fallback: EFI/BOOT/BOOTX64.EFI dentro de boot/grub/efi.img"
echo "[ Condtux ] Informe: $REPORT_PATH"
