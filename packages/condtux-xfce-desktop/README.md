# condtux-xfce-desktop

Paquete esperado por Condtux 0.9 para habilitar el perfil grafico XFCE sin
depender de `xfce4` ni `task-xfce-desktop` de Debian.

La fuente base es el release estable oficial Xfce 4.20:

- https://www.xfce.org/download
- https://archive.xfce.org/xfce/4.20/fat_tarballs/xfce-4.20.tar.bz2

El instalador y la Live buscan este paquete en:

```text
https://repo-condtux.jeval.cl/apt
```

Mientras `condtux-xfce-desktop` no este publicado en el repo Condtux, la build
0.9 fallara de forma intencional para evitar usar paquetes XFCE de Debian por
accidente.

## Build del paquete

Instala dependencias de compilacion en un builder Debian amd64 y ejecuta:

```bash
packages/condtux-xfce-desktop/build-from-source.sh
```

El `.deb` resultante queda en:

```text
packages/condtux-xfce-desktop/dist/
```

Publica ese `.deb` en el repo APT de Condtux antes de construir la ISO 0.9.
