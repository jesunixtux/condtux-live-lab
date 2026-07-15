#!/bin/sh

[ -n "${PS1:-}" ] || return 0

VERSION="$(cat /etc/condtux-version 2>/dev/null || printf '0.10')"

echo
echo "             .────────────────."
echo "          .-'                  '-."
echo "        .'      .────────.        '."
echo "       /       /   O  O   \\         \\"
echo "      /       |            \\__       \\"
echo "     |        |               \\___    >"
echo "     |        |                   \\__/"
echo "     |        |      .────.        |"
echo "     |        |     /      \\       |"
echo "      \\        \\___/        \\     /"
echo "       '.                    __.'"
echo "         '-.______________.-'"
echo
echo "              CONDTUX"
echo "           Based on Debian"
echo
echo " Condtux ${VERSION} Live"

case "${LANG:-en}" in
    es*)
        echo " Usuario Live: condtux"
        echo " Contraseña Live: live"
        echo
        echo " Comandos útiles:"
        echo "   condfetch"
        echo "   cat /etc/condtux-release"
        echo "   sudo condtux-install"
        echo "   sudo condtux-language"
        echo "   sudo condtux-live-xfce"
        echo "   sudo apt update"
        ;;
    *)
        echo " Live user: condtux"
        echo " Live password: live"
        echo
        echo " Useful commands:"
        echo "   condfetch"
        echo "   cat /etc/condtux-release"
        echo "   sudo condtux-install"
        echo "   sudo condtux-language"
        echo "   sudo condtux-live-xfce"
        echo "   sudo apt update"
        ;;
esac

echo
