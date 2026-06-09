# Condtux Live Lab

Mesa de trabajo para construir imagenes Live de Condtux con Debian live-build.

Este repositorio conserva la receta reproducible de la imagen: configuracion de live-build, listas de paquetes, hooks, assets de marca y scripts de apoyo. Los arboles generados por la build, caches, logs, discos virtuales e ISOs quedan fuera de Git.

## Alcance

Este laboratorio apunta a una ISO Live basada en Debian para sistemas amd64/UEFI. El Live incluye un instalador local de Condtux que se ejecuta desde la sesion Live:

```bash
sudo condtux-install
```

El instalador no depende de Debian Installer. Esta pensado para instalaciones UEFI en disco completo y debe tratarse como destructivo hasta completar sus confirmaciones.

En Condtux 0.6 el instalador pregunta el perfil antes de tocar el disco:

- `Minimal sin escritorio`: sistema base para terminal, servidor o VM liviana.
- `Escritorio XFCE`: instala XFCE, LightDM, NetworkManager grafico y herramientas basicas de escritorio.

El Live tambien incluye el repositorio APT firmado de Condtux en:

```text
https://repo-condtux.jeval.cl/apt
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
|-- disabled-hooks/
|-- image/
|-- scripts/
|   `-- build-live-iso.sh
|-- .gitignore
`-- README.md
```

Rutas importantes:

- `config/package-lists/`: paquetes que se instalan en el sistema Live.
- `config/includes.chroot/`: archivos que se copian al filesystem del Live.
- `config/hooks/`: hooks de live-build para etapas chroot y binary.
- `scripts/build-live-iso.sh`: punto de entrada principal de build.
- `output/`: ISOs generadas, ignoradas por Git.

## Requisitos del builder

Usa un builder Debian amd64 con espacio suficiente para los artefactos de live-build.

Paquetes recomendados:

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

## Build

Desde la raiz del repositorio:

```bash
scripts/build-live-iso.sh
```

La ISO generada queda en:

```text
output/
```

El script limpia el estado generado por live-build, configura la build, construye la ISO y escribe un checksum SHA256 junto a la imagen.

## Validaciones rapidas

Despues de construir, estas comprobaciones suelen ser utiles:

```bash
bash -n config/includes.chroot/usr/local/sbin/condtux-install
test -s output/*.iso
test -s binary/EFI/BOOT/BOOTX64.EFI
grep -q '^debootstrap[[:space:]]' binary/live/filesystem.packages
grep -q '^grub-efi-amd64[[:space:]]' binary/live/filesystem.packages
grep -q '^gdisk[[:space:]]' binary/live/filesystem.packages
```

Si Debian Installer no esta incluido, GRUB no debe exponer entradas que apunten a rutas faltantes:

```bash
! grep -RIn '/install/vmlinuz\|/install/initrd.gz' binary/boot/grub binary/isolinux
```

## Higiene de Git

Guarda en Git los archivos fuente y las recetas. No guardes:

- directorios de build como `.build/`, `binary/`, `cache/` y `chroot/`
- ISOs generadas
- discos de maquinas virtuales
- logs y descargas temporales
- estado local de editores o herramientas

Si un archivo generado ya estaba trackeado, sacalo del indice antes de confiar en `.gitignore`:

```bash
git rm --cached path/to/generated-file
```

## Notas

Este repositorio es un laboratorio, no un archivo de releases. Los artefactos publicables deben distribuirse aparte, con checksums y un changelog breve.
