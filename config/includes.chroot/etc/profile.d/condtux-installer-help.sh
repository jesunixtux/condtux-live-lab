#!/bin/sh

echo
echo "===================================================="
echo " Condtux 0.9 Live Installer"
echo " Para instalar Condtux al disco:"
echo
echo "   sudo condtux-install"
echo
echo " Modo facil: disco completo automatico."
echo " Modo experto: particiones EFI/root manuales."
echo " Permite elegir minimal, XFCE y tecnologias opcionales."
echo " Permite crear usuario propio y elegir modo sudo/root."
if grep -qw 'condtux.install=1' /proc/cmdline 2>/dev/null; then
    echo
    echo " Arrancaste desde la entrada de instalacion."
    echo " Ejecuta el comando anterior para comenzar."
fi
echo
echo "===================================================="
echo
