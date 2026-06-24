# Condtux Live Lab

Laboratorio reproducible para construir una ISO Live instalable de Condtux sobre
Debian 13 trixie amd64 con `live-build`.

La ISO arranca en modo Live y el instalador propio se ejecuta con:

```bash
sudo condtux-install
```

Condtux no depende de Debian Installer en este flujo. El instalador actual esta
pensado para UEFI y amd64.

## Condtux 0.9

La linea 0.9 mantiene lo que ya funcionaba en 0.8 y suma:

- branding Condtux en GRUB, fondos del Live y textos del sistema
- imagen principal en `image/condtux_imagen_system/system_wallpaper_condtux.png`
- instalador con modo facil y modo experto
- modo facil: disco completo, GPT, EFI FAT32 y root ext4
- modo experto: seleccion manual de particion EFI y particion root
- passwords en terminal con mascara visual de asteriscos
- soporte opcional para firmware libre, Bluetooth, impresion y agentes de VM
- XFCE instalado en el Live, pero desactivado por defecto

Para activar XFCE durante una sesion Live:

```bash
sudo condtux-live-xfce
```

El paquete `condtux-xfce-desktop` debe estar publicado en:

```text
https://repo-condtux.jeval.cl/apt
```

Ese paquete debe compilarse desde las fuentes oficiales de Xfce, no desde los
metapaquetes `xfce4` o `task-xfce-desktop` de Debian. El helper inicial esta en:

```bash
packages/condtux-xfce-desktop/build-from-source.sh
```

Mientras `condtux-xfce-desktop` no exista en el repo Condtux, la build fallara
de forma intencional para evitar una Live grafica a medias.

## Builder actual

Builder de laboratorio:

```text
builder@192.168.1.96
```

Desde tu maquina:

```bash
ssh builder@192.168.1.96
cd /home/builder/condtux-live-lab
printf '%s\n' '2952404' | sudo -S bash scripts/build-live-iso.sh
```

## Estructura

```text
condtux-live-lab/
|-- config/
|   |-- hooks/
|   |-- includes.binary/
|   |-- includes.chroot/
|   |-- includes.installer/
|   `-- package-lists/
|-- image/
|   |-- condtux_imagen_system/
|   `-- wallpapers/
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
- `config/includes.binary/`: archivos incluidos en el arbol ISO.
- `config/hooks/`: hooks de `live-build`.
- `image/condtux_imagen_system/`: imagen principal del sistema y GRUB.
- `image/wallpapers/`: wallpapers fuente del proyecto.
- `scripts/build-live-iso.sh`: punto de entrada principal de build.
- `output/`: ISOs generadas, ignoradas por Git.

El wallpaper principal de sistema y GRUB es:

```text
image/condtux_imagen_system/system_wallpaper_condtux.png
```

Antes de construir, el script de build sincroniza wallpapers y copia la imagen
principal hacia:

```text
config/includes.binary/boot/grub/themes/condtux/background.png
config/includes.chroot/usr/share/backgrounds/condtux/defaultwallpaper.png
config/includes.chroot/usr/share/backgrounds/condtux/system_wallpaper_condtux.png
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
output/condtux-0.9-amd64.iso
```

## Validaciones rapidas

```bash
bash -n scripts/build-live-iso.sh
bash -n config/includes.chroot/usr/local/sbin/condtux-install
bash -n config/includes.chroot/usr/local/sbin/condtux-first-config
bash -n config/includes.chroot/usr/local/sbin/condtux-live-xfce
bash -n packages/condtux-xfce-desktop/build-from-source.sh
test -s image/condtux_imagen_system/system_wallpaper_condtux.png
test -s output/condtux-0.9-amd64.iso
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
