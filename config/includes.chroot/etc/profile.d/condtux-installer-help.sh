#!/bin/sh

VERSION="$(cat /etc/condtux-version 2>/dev/null || printf '0.10')"

echo
echo "===================================================="

case "${LANG:-en}" in
    es*)
        echo " Instalador Live de Condtux ${VERSION}"
        echo " Para instalar Condtux al disco:"
        echo
        echo "   sudo condtux-install"
        echo
        echo " Con XFCE también puedes usar el icono Instalar Condtux."
        echo " Modo fácil: disco completo automático."
        echo " Modo experto: particiones EFI/root manuales."
        ;;
    *)
        echo " Condtux ${VERSION} Live Installer"
        echo " To install Condtux on disk:"
        echo
        echo "   sudo condtux-install"
        echo
        echo " With XFCE you can also use the Install Condtux icon."
        echo " Easy mode: automatic full-disk installation."
        echo " Expert mode: manual EFI/root partitions."
        ;;
esac

echo "===================================================="
echo
