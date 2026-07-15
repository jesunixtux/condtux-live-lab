# Condtux Live Lab

Laboratorio reproducible para construir una ISO Live instalable de Condtux sobre Debian 13 trixie amd64 con `live-build`.

Condtux usa un instalador propio desde el Live:

```bash
sudo condtux-install
```

En XFCE también aparece el acceso **Instalar Condtux / Install Condtux** en el escritorio y en el menú de aplicaciones.

## Condtux 0.10

La versión 0.10 añade:

- selección obligatoria de idioma al iniciar el Live: español o inglés
- selección de teclado: latinoamericano, español de España o inglés de Estados Unidos
- el sistema instalado hereda el idioma y teclado elegidos en el Live
- comando `sudo condtux-language` para cambiar idioma y teclado después
- lanzador gráfico del instalador cuando XFCE está activo
- eliminación de la entrada GRUB duplicada `Instalar Condtux desde Live`
- `defaultwallpaper.png` como fondo del escritorio
- `system_wallpaper_condtux.png` reservado para GRUB
- versión centralizada en el archivo `VERSION`
- Secure Boot desactivado explícitamente por ahora

## Activar XFCE en el Live

```bash
sudo condtux-live-xfce
```

Después de iniciar XFCE, usa el icono **Instalar Condtux** del escritorio.

El paquete `condtux-xfce-desktop` debe estar publicado en:

```text
https://repo-condtux.jeval.cl/apt
```

Mientras ese paquete no exista en el repositorio, la construcción fallará de forma intencional para evitar una ISO gráfica incompleta.

## Actualizar el repositorio local

Para obtener la rama de desarrollo 0.10:

```bash
git fetch origin
git switch condtux-0.10
git pull --ff-only origin condtux-0.10
```

## Preparar una versión futura

Para cambiar todo el proyecto a Condtux 0.11:

```bash
scripts/set-version.sh 0.11
git add VERSION README.md config scripts packages
git commit -m "Preparar Condtux 0.11"
git push
```

El script actualiza los nombres de ISO, textos del sistema, GRUB, instalador y versión del paquete XFCE.

## Builder

En el builder Debian amd64:

```bash
cd /home/builder/condtux-live-lab
sudo bash scripts/build-live-iso.sh
```

Nunca guardes contraseñas en comandos, scripts o documentación del repositorio.

## Estructura principal

```text
condtux-live-lab/
|-- VERSION
|-- config/
|   |-- hooks/
|   |-- includes.binary/
|   |-- includes.chroot/
|   `-- package-lists/
|-- image/
|   |-- condtux_imagen_system/
|   `-- wallpapers/
|-- packages/
|-- scripts/
|   |-- apply-version.sh
|   |-- build-live-iso.sh
|   |-- set-version.sh
|   `-- sync-wallpapers.sh
|-- output/
`-- README.md
```

Fondos:

```text
image/wallpapers/defaultwallpaper.png
    Fondo predeterminado del escritorio.

image/condtux_imagen_system/system_wallpaper_condtux.png
    Fondo reservado para GRUB.
```

## Requisitos del builder

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

## Construir la ISO

```bash
scripts/build-live-iso.sh
```

Resultado:

```text
output/condtux-0.10-amd64.iso
output/condtux-0.10-amd64.iso.sha256
```

## Validaciones rápidas

```bash
bash -n scripts/build-live-iso.sh
bash -n scripts/apply-version.sh
bash -n scripts/set-version.sh
bash -n config/includes.chroot/usr/local/sbin/condtux-install
bash -n config/includes.chroot/usr/local/sbin/condtux-language
bash -n config/includes.chroot/usr/local/sbin/condtux-live-setup
bash -n config/includes.chroot/usr/local/sbin/condtux-copy-live-language-target
bash -n config/includes.chroot/usr/local/bin/condtux-install-gui
bash -n config/includes.chroot/usr/local/sbin/condtux-live-xfce

test -s image/wallpapers/defaultwallpaper.png
test -s image/condtux_imagen_system/system_wallpaper_condtux.png
test -s output/condtux-0.10-amd64.iso
test -s binary/EFI/BOOT/BOOTX64.EFI

! grep -RIn 'Instalar Condtux desde Live' binary/boot/grub binary/EFI 2>/dev/null
grep -q '^condtux-xfce-desktop[[:space:]]' binary/live/filesystem.packages
```

## Higiene de Git

No guardes en Git:

- ISOs, discos virtuales o imágenes generadas
- directorios `binary/`, `cache/`, `chroot/` u `output/`
- logs y descargas temporales
- contraseñas, tokens o llaves privadas

Los artefactos publicables deben distribuirse por separado con checksum y changelog.
