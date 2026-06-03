# Condtux Live Lab

Mesa de trabajo para construir la primera ISO Live de **Condtux 0.1**, basada en **Debian 13 trixie amd64** usando **live-build**.

> Estado actual: la ISO ya compiló correctamente y arrancó en Proxmox.  
> Pendiente conocido: corregir el autologin del usuario live para una futura versión 0.2.

---

## 1. ¿Qué es esto?

Este repositorio contiene las recetas, configuraciones y scripts necesarios para reconstruir una ISO Live mínima de Condtux.

La idea es simple:

- Construir una ISO Live booteable.
- Mantener una base reproducible.
- Guardar solo archivos importantes en Git.
- Evitar subir ISOs, caches, `chroot`, logs pesados o archivos generados.
- Probar rápido en Proxmox usando UEFI/OVMF.
- Usar esta base como punto de partida para Condtux 0.2.

---

## 2. Estado del proyecto

| Item | Valor |
|---|---|
| Proyecto | Condtux 0.1 Live |
| Base | Debian 13 trixie amd64 |
| Tipo de ISO | Live ISO híbrida booteable |
| Builder usado | VM Debian 13 en Proxmox |
| Herramienta principal | live-build |
| ISO esperada | `output/condtux-0.1-live-amd64.iso` |
| Tamaño aproximado | 651 MB |
| Repo esperado | `git@github.com:jechugit/condtux-live-lab.git` |

---

## 3. Requisitos recomendados

### VM builder

| Recurso | Recomendado |
|---|---|
| Sistema | Debian 13 trixie amd64 |
| BIOS | OVMF UEFI |
| Machine | q35 |
| CPU | 2 a 4 cores |
| RAM | 4 GB mínimo, 8 GB recomendado |
| Disco | 40 GB mínimo, 80 GB recomendado |
| Red | VirtIO |
| Secure Boot | Desactivado |

---

## 4. Crear VM builder en Proxmox

Comandos opcionales desde el nodo Proxmox:

```bash
qm create 130 \
  --name condtux-builder \
  --memory 8192 \
  --cores 4 \
  --cpu host \
  --machine q35 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

qm set 130 --scsihw virtio-scsi-pci
qm set 130 --scsi0 local-lvm:80
qm set 130 --bios ovmf
qm set 130 --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0
qm set 130 --ide2 local:iso/debian-13-amd64-netinst.iso,media=cdrom
qm set 130 --boot order=ide2\;scsi0\;net0
qm start 130
```

---

## 5. Preparar Debian builder

Entrar como root:

```bash
su -
```

Actualizar e instalar lo básico:

```bash
apt update
apt full-upgrade -y
apt install -y sudo openssh-server nano curl wget git
systemctl enable --now ssh
```

Crear usuario `builder`:

```bash
adduser builder
usermod -aG sudo builder
groups builder
```

Configurar SSH:

```bash
nano /etc/ssh/sshd_config
```

Configuración básica recomendada:

```text
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
UsePAM yes
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
```

Verificar y reiniciar SSH:

```bash
sshd -t
systemctl restart ssh
```

Conectarse desde otro equipo:

```bash
ssh builder@IP_DE_LA_VM
```

---

## 6. Instalar herramientas de live-build

```bash
sudo apt update
sudo apt full-upgrade -y

sudo apt install -y \
  live-build \
  live-manual \
  live-config \
  live-boot \
  xorriso \
  isolinux \
  syslinux-common \
  squashfs-tools \
  git \
  curl \
  wget \
  nano \
  ca-certificates \
  locales
```

---

## 7. Crear estructura del laboratorio

```bash
cd ~
mkdir -p condtux-live-lab
cd condtux-live-lab
```

Configurar live-build:

```bash
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main" \
  --binary-images iso-hybrid \
  --debian-installer live \
  --debian-installer-gui false \
  --bootappend-live "boot=live components hostname=condtux username=user locales=es_CL.UTF-8 keyboard-layouts=latam timezone=America/Santiago"
```

Estructura esperada:

```text
condtux-live-lab/
├── config/
│   ├── includes.chroot/
│   │   └── etc/
│   │       ├── condtux-release
│   │       ├── hostname
│   │       └── profile.d/
│   │           └── condtux-welcome.sh
│   ├── package-lists/
│   │   └── condtux-base.list.chroot
│   └── hooks/
│       └── normal/
│           └── 0100-condtux-config.hook.chroot
├── scripts/
│   └── build-live-iso.sh
├── output/
├── logs/
└── README.md
```

---

## 8. Lista de paquetes base

Crear el archivo:

```bash
mkdir -p config/package-lists
nano config/package-lists/condtux-base.list.chroot
```

Contenido:

```text
sudo
openssh-server
nano
curl
wget
git
ca-certificates
unattended-upgrades
apt-listchanges
bash-completion
net-tools
iproute2
pciutils
usbutils
util-linux
less
fastfetch
```

---

## 9. Archivo de versión de Condtux

```bash
mkdir -p config/includes.chroot/etc
nano config/includes.chroot/etc/condtux-release
```

Contenido:

```text
Condtux 0.1 Live - Debian 13 trixie amd64
```

---

## 10. Hostname

```bash
nano config/includes.chroot/etc/hostname
```

Contenido:

```text
condtux
```

---

## 11. Mensaje de bienvenida

```bash
mkdir -p config/includes.chroot/etc/profile.d
nano config/includes.chroot/etc/profile.d/condtux-welcome.sh
```

Contenido:

```sh
#!/bin/sh

echo
echo "  ____ ___  _   _ ____ _____ _   ___  __"
echo " / ___/ _ \| \ | |  _ \_   _| | | \ \/ /"
echo "| |  | | | |  \| | | | || | | | | |\  / "
echo "| |__| |_| | |\  | |_| || | | |_| |/  \ "
echo " \____\___/|_| \_|____/ |_|  \___//_/\_\\"
echo
echo " Condtux 0.1 - Debian trixie base"
echo
```

Dar permisos:

```bash
chmod +x config/includes.chroot/etc/profile.d/condtux-welcome.sh
```

---

## 12. Hook de configuración

```bash
mkdir -p config/hooks/normal
nano config/hooks/normal/0100-condtux-config.hook.chroot
```

Contenido:

```sh
#!/bin/sh
set -e

systemctl enable ssh || true
systemctl enable unattended-upgrades || true

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Origins-Pattern {
  "origin=Debian,codename=${distro_codename},label=Debian-Security";
  "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
```

Dar permisos:

```bash
chmod +x config/hooks/normal/0100-condtux-config.hook.chroot
```

---

## 13. Script de compilación

```bash
mkdir -p scripts output logs
nano scripts/build-live-iso.sh
```

Contenido:

```bash
#!/usr/bin/env bash
set -e

cd "$HOME/condtux-live-lab"

echo "[ Condtux Live ] Limpiando build anterior..."
sudo lb clean --purge || true

echo "[ Condtux Live ] Borrando cache vieja..."
sudo rm -rf .build chroot binary cache
rm -f *.iso live-image-* binary.*
rm -f output/*.iso

echo "[ Condtux Live ] Reconfigurando live-build..."
lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main" \
  --binary-images iso-hybrid \
  --debian-installer live \
  --debian-installer-gui false \
  --mirror-bootstrap http://deb.debian.org/debian \
  --mirror-chroot http://deb.debian.org/debian \
  --mirror-binary http://deb.debian.org/debian \
  --security true \
  --mirror-chroot-security http://security.debian.org/debian-security \
  --mirror-binary-security http://security.debian.org/debian-security \
  --apt-recommends false \
  --bootappend-live "boot=live components hostname=condtux username=user locales=es_CL.UTF-8 keyboard-layouts=latam timezone=America/Santiago"

echo "[ Condtux Live ] Construyendo ISO..."
sudo lb build

mkdir -p output

ISO_FOUND="$(find . -maxdepth 1 -type f \( -name 'live-image-amd64.hybrid.iso' -o -name 'binary.hybrid.iso' -o -name '*.iso' \) | head -n 1)"

if [ -z "$ISO_FOUND" ]; then
  echo "No se encontró ISO generada."
  exit 1
fi

cp -v "$ISO_FOUND" output/condtux-0.1-live-amd64.iso

echo
echo "[ Condtux Live ] ISO lista:"
ls -lh output/
```

Dar permisos:

```bash
chmod +x scripts/build-live-iso.sh
```

---

## 14. Compilar la ISO

```bash
cd ~/condtux-live-lab
./scripts/build-live-iso.sh 2>&1 | tee logs/build-$(date +%F-%H%M).log
```

Resultado esperado:

```text
P: Build completed successfully
'./live-image-amd64.hybrid.iso' -> 'output/condtux-0.1-live-amd64.iso'

[ Condtux Live ] ISO lista:
total 652M
-rw-r--r-- 1 builder builder 651M jun 3 16:12 condtux-0.1-live-amd64.iso
```

---

## 15. Probar la ISO en Proxmox

Copiar la ISO desde la VM builder al nodo Proxmox:

```bash
scp builder@192.168.1.172:/home/builder/condtux-live-lab/output/condtux-0.1-live-amd64.iso /var/lib/vz/template/iso/
```

Crear VM de prueba:

```bash
qm create 132 \
  --name condtux-live-test \
  --memory 4096 \
  --cores 2 \
  --cpu host \
  --machine q35 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

qm set 132 --scsihw virtio-scsi-pci
qm set 132 --scsi0 local-lvm:32
qm set 132 --bios ovmf
qm set 132 --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0
qm set 132 --ide2 local:iso/condtux-0.1-live-amd64.iso,media=cdrom
qm set 132 --boot order=ide2\;scsi0
qm start 132
```

---

## 16. Verificar dentro de Condtux

```bash
hostname
cat /etc/condtux-release
fastfetch
```

Si falla el autologin, usar temporalmente:

```text
Usuario: user
Contraseña: live
```

El fallo conocido es que el sistema intentó autologin como `condtux`. Para Condtux 0.2 conviene crear correctamente el usuario `condtux` mediante hook.

---

## 17. `.gitignore` recomendado

```bash
cat > .gitignore <<'EOF'
# live-build outputs
.build/
.cache/
cache/
chroot/
binary/
output/
logs/

# Generated live-build reports
chroot.files
chroot.packages.install
chroot.packages.live
binary.files
binary.packages

# ISO/output files
*.iso
*.img
*.raw
*.qcow2
live-image-*
binary.*

# Logs temporales
wget-log*
*.log

# Editor / sistema
*~
*.swp
*.swo
.DS_Store
EOF
```

---

## 18. Guardar en Git

```bash
git init
git config user.name "Condtux Builder"
git config user.email "builder@condtux.local"

git add .
git commit -m "Crear primera mesa live-build funcional de Condtux"
```

---

## 19. Conectar con GitHub usando SSH

Crear llave SSH:

```bash
ssh-keygen -t ed25519 -C "condtux-builder"
cat ~/.ssh/id_ed25519.pub
```

Pegar la clave pública en GitHub:

```text
GitHub > Settings > SSH and GPG keys > New SSH key
Title: condtux-builder
Key: pegar la línea ssh-ed25519 completa
```

Probar conexión:

```bash
ssh -T git@github.com
```

Resultado esperado:

```text
Hi jechugit! You've successfully authenticated, but GitHub does not provide shell access.
```

Conectar repo:

```bash
git branch -M main
git remote add origin git@github.com:jechugit/condtux-live-lab.git
git push -u origin main
```

Si ya existe `origin`:

```bash
git remote -v
git remote set-url origin git@github.com:jechugit/condtux-live-lab.git
git push -u origin main
```

Si Git dice `fetch first` porque el remoto ya tiene README/licencia:

```bash
git pull origin main --allow-unrelated-histories --no-rebase
git push -u origin main
```

Si el repo remoto no tiene nada importante y quieres reemplazarlo:

```bash
git push -u origin main --force
```

Ojo con `--force`: es motosierra. Sirve, pero no perdona.

---

## 20. Backup comprimido limpio

```bash
cd ~

tar --exclude='condtux-live-lab/.git' \
  --exclude='condtux-live-lab/.build' \
  --exclude='condtux-live-lab/cache' \
  --exclude='condtux-live-lab/chroot' \
  --exclude='condtux-live-lab/binary' \
  --exclude='condtux-live-lab/output' \
  --exclude='condtux-live-lab/logs' \
  --exclude='condtux-live-lab/*.iso' \
  --exclude='condtux-live-lab/wget-log*' \
  -czvf condtux-live-lab-workshop-$(date +%F).tar.gz condtux-live-lab
```

---

## 21. Problemas conocidos y soluciones

### 21.1 Simple-CDD falló con HTTP 404

Se intentó usar Simple-CDD para una ISO instalable con Debian Installer, pero en Debian 13 apareció un fallo HTTP 404 durante el mirror.

Decisión práctica:

```text
Congelar Simple-CDD por ahora y avanzar con live-build.
```

Comandos útiles:

```bash
dpkg -l simple-cdd python3-simple-cdd
apt-cache policy simple-cdd python3-simple-cdd
```

### 21.2 live-build: falta etapa config

Error:

```text
E: the following stage is required to be done first: config
```

Solución: después de `lb clean --purge`, volver a ejecutar `lb config`.

Por eso el script `build-live-iso.sh` hace `lb config` antes de `lb build`.

### 21.3 neofetch no existe en trixie

Se reemplazó `neofetch` por `fastfetch`.

```bash
apt-cache policy fastfetch
```

### 21.4 Error de descarga de libc6

Fue un problema de descarga/cache/mirror.

Solución:

```bash
sudo apt clean
sudo rm -rf /var/cache/apt/archives/partial/*

cd ~/condtux-live-lab
sudo rm -rf .build chroot binary cache
./scripts/build-live-iso.sh
```

---

## 22. Roadmap técnico

### Condtux 0.1

- ISO Live booteable.
- Base Debian 13 trixie amd64.
- Hostname `condtux`.
- Banner básico.
- Paquetes base.
- `fastfetch`.

### Condtux 0.2

- Corregir autologin.
- Crear usuario `condtux` correctamente.
- Agregar wallpaper.
- Pulir branding.

### Condtux 0.3

- Agregar XFCE opcional.
- Separar perfiles internos.

### Condtux 0.4

- Crear metapaquetes:
  - `condtux-minimal`
  - `condtux-xfce`
  - `condtux-developer`

### Condtux futuro

- Repo APT propio con `reprepro`.
- `condtux-keyring`.
- `condtux-apt-sources`.
- Volver a Debian Installer + Simple-CDD cuando convenga.

---

## 23. Reglas del repositorio

No subir:

- ISOs.
- `chroot/`.
- `binary/`.
- `cache/`.
- `.build/`.
- Logs grandes.
- Imágenes `.img`, `.raw`, `.qcow2`.

Sí subir:

- Scripts.
- Hooks.
- Lista de paquetes.
- Archivos de configuración.
- Documentación.
- README.

Regla de oro:

```text
Primero estabilidad y reproducibilidad.
Después branding y escritorio.
```

---

## 24. Licencia

Pendiente de definir.

Recomendación inicial:

- MIT si quieres permitir uso amplio.
- GPL si quieres que derivados mantengan el código abierto.
- Sin licencia todavía si el proyecto sigue privado y experimental.

---

## 25. Nota final

Condtux 0.1 no busca ser perfecta. Busca existir, arrancar y ser reconstruible.

Eso ya es una victoria: primero que prenda, después que se vea bonito. Como buen taller: si huele a café, polvo y logs, vamos bien.
