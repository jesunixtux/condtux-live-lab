#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"

if [ ! -s "$VERSION_FILE" ]; then
    echo "[ Condtux ] ERROR: falta VERSION." >&2
    exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
VERSION_COMPACT="$(printf '%s' "$VERSION" | tr -d '.')"

case "$VERSION" in
    ''|*[!0-9.]*|.*|*.)
        echo "[ Condtux ] ERROR: version invalida: $VERSION" >&2
        exit 1
        ;;
esac

replace_if_exists() {
    file="$1"
    shift
    [ -f "$file" ] || return 0
    sed -i "$@" "$file"
}

replace_if_exists "$ROOT/config/binary" \
    -e "s#^LB_ISO_APPLICATION=.*#LB_ISO_APPLICATION=\"Condtux ${VERSION} Live\"#" \
    -e "s#^LB_ISO_VOLUME=.*#LB_ISO_VOLUME=\"CONDTUX${VERSION_COMPACT}\"#" \
    -e 's#^LB_UEFI_SECURE_BOOT=.*#LB_UEFI_SECURE_BOOT="enable"#' \
    -e 's#^LB_COMPRESSION=.*#LB_COMPRESSION="xz"#' \
    -e 's#locales=[^ ]* keyboard-layouts=[^ ]*#locales=en_US.UTF-8 keyboard-layouts=us#g'

replace_if_exists "$ROOT/config/includes.chroot/etc/os-release" \
    -e "s#^PRETTY_NAME=.*#PRETTY_NAME=\"Condtux ${VERSION} Live\"#" \
    -e "s#^VERSION_ID=.*#VERSION_ID=\"${VERSION}\"#" \
    -e "s#^VERSION=.*#VERSION=\"${VERSION} Live\"#"

printf 'Condtux %s Live - Debian trixie amd64\n' "$VERSION" > "$ROOT/config/includes.chroot/etc/condtux-release"
printf '%s\n' "Condtux GNU/Linux ${VERSION} \\n \\l" > "$ROOT/config/includes.chroot/etc/issue"
printf 'Condtux GNU/Linux %s\n' "$VERSION" > "$ROOT/config/includes.chroot/etc/issue.net"
printf '%s\n' "$VERSION" > "$ROOT/config/includes.chroot/etc/condtux-version"

replace_if_exists "$ROOT/config/includes.binary/boot/grub/themes/condtux/theme.txt" \
    -e "s#Condtux GNU/Linux 0\.[0-9][0-9]*#Condtux GNU/Linux ${VERSION}#g"

for installer in \
    "$ROOT/config/includes.chroot/usr/local/sbin/condtux-install" \
    "$ROOT/config/includes.chroot/usr/local/sbin/condtux-install-en"; do
    replace_if_exists "$installer" \
        -e "s#Condtux Installer 0\.[0-9][0-9]*#Condtux Installer ${VERSION}#g" \
        -e "s#Condtux 0\.[0-9][0-9]*#Condtux ${VERSION}#g"
done

replace_if_exists "$ROOT/config/includes.chroot/usr/local/bin/condtux-install-gui" \
    -e "s#Instalar Condtux 0\.[0-9][0-9]*#Instalar Condtux ${VERSION}#g" \
    -e "s#Install Condtux 0\.[0-9][0-9]*#Install Condtux ${VERSION}#g"

replace_if_exists "$ROOT/config/includes.chroot/usr/local/libexec/condtux-account-wizard" \
    -e "s#Cuenta de Condtux 0\.[0-9][0-9]*#Cuenta de Condtux ${VERSION}#g" \
    -e "s#Condtux 0\.[0-9][0-9]* account#Condtux ${VERSION} account#g"

replace_if_exists "$ROOT/config/hooks/normal/9000-condtux-grub-branding.hook.binary" \
    -e "s#Condtux GNU/Linux 0\.[0-9][0-9]*#Condtux GNU/Linux ${VERSION}#g" \
    -e "s#Condtux 0\.[0-9][0-9]*#Condtux ${VERSION}#g"

replace_if_exists "$ROOT/config/hooks/normal/0090-condtux-live-user.hook.chroot" \
    -e "s#Live 0\.[0-9][0-9]*#Live ${VERSION}#g"

replace_if_exists "$ROOT/packages/condtux-xfce-desktop/build-from-source.sh" \
    -e "s#PKG_VERSION=\"\${PKG_VERSION:-0\.[0-9][0-9]*\.0}\"#PKG_VERSION=\"\${PKG_VERSION:-${VERSION}.0}\"#"

replace_if_exists "$ROOT/README.md" \
    -e "s#Condtux 0\.[0-9][0-9]*#Condtux ${VERSION}#g" \
    -e "s#condtux-0\.[0-9][0-9]*-amd64.iso#condtux-${VERSION}-amd64.iso#g"

echo "[ Condtux ] Version aplicada: $VERSION"
