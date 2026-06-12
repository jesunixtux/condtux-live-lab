# Condtux Live Lab

Laboratorio reproducible para construir una ISO Live instalable de Condtux sobre
Debian 13 trixie amd64 con `live-build`.

La ISO arranca en modo Live y el instalador propio se ejecuta con:

```bash
sudo condtux-install
```

Condtux no depende de Debian Installer en este flujo. El instalador actual esta
pensado para UEFI, amd64 y disco completo.

## Condtux 0.8

La linea 0.8 prepara tres cambios principales:

- repositorios solo por HTTPS, tanto Debian como Condtux
- asistente de red en el instalador si no hay internet disponible
- escritorio XFCE de Condtux en Live e instalacion usando `condtux-xfce-desktop`

El paquete `condtux-xfce-desktop` debe estar publicado en:

```text
https://repo-condtux.jeval.cl/apt
```

Ese paquete debe compilarse desde las fuentes oficiales de Xfce, no desde los
metapaquetes `xfce4` o `task-xfce-desktop` de Debian. El helper inicial esta en:

```bash
packages/condtux-xfce-desktop/build-from-source.sh
```

Mientras `condtux-xfce-desktop` no exista en el repo Condtux, la build 0.8
fallara de forma intencional para evitar una Live grafica a medias.

## Estructura

```text
condtux-live-lab/
|-- config/
|   |-- hooks/
|   |-- includes.binary/
|   |-- includes.chroot/
|   |-- includes.installer/
|   `-- package-lists/
|-- image/wallpapers/
|-- packages/
|-- scripts/
|   |-- build-live-iso.sh
|   `-- sync-wallpapers.sh
|-- .gitignore
`-- README.md
```

Rutas importantes:

- `config/package-lists/`: paquetes base del Live.
- `config/includes.chroot/`: archivos incluidos dentro del filesystem Live.
- `config/hooks/`: hooks de `live-build`.
- `image/wallpapers/`: wallpapers fuente del proyecto.
- `scripts/build-live-iso.sh`: punto de entrada principal de build.
- `output/`: ISOs generadas, ignoradas por Git.

El wallpaper por defecto es:

```text
image/wallpapers/defaultwallpaper.png
```

Antes de construir, el script de build sincroniza `image/wallpapers/` hacia:

```text
config/includes.chroot/usr/share/backgrounds/condtux/
```

## Requisitos del builder

Usa un builder Debian amd64 con espacio suficiente para los artefactos de
`live-build`.

```bash
sudo apt update
sudo apt install -y \
  live-build \
  xorriso \
  isolinux \
  syslinux-common \
  squashfs-tools \
  rsync \
  git \
  curl \
  wget \
  ca-certificates
```

## Build de la ISO

Desde la raiz del repositorio:

```bash
scripts/build-live-iso.sh
```

La ISO queda en:

```text
output/condtux-0.8-amd64.iso
```

## Validaciones rapidas

```bash
bash -n config/includes.chroot/usr/local/sbin/condtux-install
bash -n config/includes.chroot/usr/local/sbin/condtux-first-config
bash -n packages/condtux-xfce-desktop/build-from-source.sh
test -s output/condtux-0.8-amd64.iso
test -s binary/EFI/BOOT/BOOTX64.EFI
grep -q '^debootstrap[[:space:]]' binary/live/filesystem.packages
grep -q '^grub-efi-amd64[[:space:]]' binary/live/filesystem.packages
grep -q '^gdisk[[:space:]]' binary/live/filesystem.packages
grep -q '^condtux-xfce-desktop[[:space:]]' binary/live/filesystem.packages
```

Si Debian Installer no esta incluido, GRUB no debe exponer entradas hacia rutas
faltantes:

```bash
! grep -RIn '/install/vmlinuz\|/install/initrd.gz' binary/boot/grub binary/isolinux
```

## Higiene de Git

Guarda en Git las recetas, hooks, scripts, assets y documentacion. No guardes:

- directorios generados por build como `.build/`, `binary/`, `cache/` y `chroot/`
- ISOs y discos virtuales
- logs, descargas temporales y respaldos locales
- estado local de editores o herramientas

Si un archivo generado ya estaba trackeado, sacalo del indice antes de confiar en
`.gitignore`:

```bash
git rm --cached path/to/generated-file
```

## Notas

Este repositorio es el laboratorio de construccion. Los artefactos publicables
deben distribuirse aparte con checksum y changelog.
