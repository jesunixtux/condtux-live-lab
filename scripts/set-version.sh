#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NEW_VERSION="${1:-}"

case "$NEW_VERSION" in
    ''|*[!0-9.]*|.*|*.)
        echo "Uso: sh scripts/set-version.sh 0.11" >&2
        exit 1
        ;;
esac

printf '%s\n' "$NEW_VERSION" > "$ROOT/VERSION"
sh "$ROOT/scripts/apply-version.sh"

echo
echo "Version preparada: Condtux $NEW_VERSION"
echo "Revisa los cambios y ejecuta:"
echo "  git add VERSION README.md config scripts packages"
echo "  git commit -m 'Preparar Condtux $NEW_VERSION'"
echo "  git push"
